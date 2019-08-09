defmodule ExRabbitMQ.AST.Common do
  @moduledoc """
  Common function and types for `ExRabbitMQ.Consumer` and `ExRabbitMQ.Producer` modules.
  """

  @type connection :: atom | ExRabbitMQ.Config.Connection.t()

  @type queue :: atom | ExRabbitMQ.Config.Session.t()

  @type result :: {:ok, term} | {:error, term, term}

  @type basic_publish_result :: {:ok | {:error, :blocked | :closing | :no_channel}, boolean}

  @doc """
  Produces the common part of the AST for both the consumer and producer behaviours.
  Specifically, it holds getters and setters, using the process dictionary, to hold important information such as the channel
  pid and monitor reference.
  It also holds the AST necessary to open a channel when an AMQP connection is ready.
  """
  def ast do
    # credo:disable-for-previous-line
    quote location: :keep do
      alias ExRabbitMQ.ChannelRipper, as: XRMQChannelRipper
      alias ExRabbitMQ.Config.Bind, as: XRMQBindConfig
      alias ExRabbitMQ.Config.Environment, as: XRMQEnvironmentConfig
      alias ExRabbitMQ.Config.Exchange, as: XRMQExchangeConfig
      alias ExRabbitMQ.Config.Queue, as: XRMQQueueConfig
      alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig
      alias ExRabbitMQ.Connection, as: XRMQConnection
      alias ExRabbitMQ.Constants, as: XRMQConstants
      alias ExRabbitMQ.State, as: XRMQState

      def xrmq_on_try_init(state), do: state

      def xrmq_on_try_init_success(state), do: {:cont, state}

      def xrmq_on_try_init_error_retry(_reason, state), do: {:cont, state}

      def xrmq_on_try_init_error(reason, state), do: {:halt, reason, state}

      def xrmq_channel_setup(_channel, state) do
        {:ok, state}
      end

      def xrmq_channel_open(_channel, state) do
        {:ok, state}
      end

      def xrmq_basic_cancel(cancellation_info, state) do
        XRMQLogger.error("received basic_cancel message", cancellation_info: cancellation_info)

        {:stop, :basic_cancel, state}
      end

      def xrmq_basic_publish(payload, exchange, routing_key, opts \\ [])

      def xrmq_basic_publish(payload, exchange, routing_key, opts) when is_binary(payload) do
        xrmq_basic_publish(
          XRMQState.get_connection_status(),
          payload,
          exchange,
          routing_key,
          opts
        )
      end

      def xrmq_basic_publish(payload, _exchange, _routing_key, _opts) do
        {:error, {:payload_not_binary, payload}}
      end

      def xrmq_extract_state({:ok, state}), do: state
      def xrmq_extract_state({:error, _, state}), do: state

      def xrmq_channel_close(state) do
        with {:channel, {channel, _}} when channel !== nil <-
               {:channel, XRMQState.get_channel_info()},
             :ok <- AMQP.Channel.close(channel) do
          {:ok, state}
        else
          {:channel, {nil, _}} -> {:error, :nil_channel, state}
          {:error, reason} -> {:error, reason, state}
        end
      end

      def xrmq_session_setup(nil, _session_config, _state), do: {:error, :nil_channel}
      def xrmq_session_setup(_channel, nil, _state), do: {:error, :nil_session_config}

      def xrmq_session_setup(channel, session_config, state) do
        session_config.declarations
        |> Enum.reduce_while({:ok, state}, fn declaration, acc ->
          case xrmq_declare(channel, declaration) do
            {:ok, _} -> {:cont, acc}
            error -> {:halt, error}
          end
        end)
      end

      def xrmq_on_connection_opened(%AMQP.Connection{} = _connection, state), do: state

      def xrmq_on_connection_closed(state), do: state

      def xrmq_on_connection_reopened(%AMQP.Connection{} = _connection, state), do: state

      def xrmq_flush_buffered_messages(_buffered_messages_count, _buffered_messages, state) do
        state
      end

      def xrmq_on_message_buffered(
            _buffered_messages_count,
            _payload,
            _exchange,
            _routing_key,
            _opts
          ) do
      end

      defp xrmq_try_init_inner(xrmq_init_result, opts) do
        state = xrmq_init_result |> xrmq_extract_state() |> xrmq_on_try_init()

        case xrmq_init_result do
          {:ok, state} ->
            case xrmq_on_try_init_success(state) do
              {:cont, state} -> {:noreply, state}
              {:halt, reason, state} -> {:stop, reason, state}
            end

          {:error, reason, state}
          when reason in [:nil_connection_pid, :no_available_connection] ->
            case xrmq_on_try_init_error_retry(reason, state) do
              {:cont, state} ->
                Process.send_after(
                  self(),
                  {:xrmq_try_init, opts},
                  XRMQEnvironmentConfig.try_init_interval()
                )

                {:noreply, state}

              {:halt, reason, state} ->
                {:stop, reason, state}
            end

          {:error, reason, state} ->
            case xrmq_on_try_init_error(reason, state) do
              {:cont, state} -> {:noreply, state}
              {:halt, reason, state} -> {:stop, reason, state}
            end
        end
      end

      defp xrmq_connection_setup(connection_config) do
        with {:ok, conn_pid} <- XRMQConnection.get_subscribe(connection_config),
             true <- Process.link(conn_pid) do
          {:ok, channel_ripper_pid} = XRMQChannelRipper.start()
          XRMQState.set_connection_pid(conn_pid)
          XRMQState.set_connection_config(connection_config)
          XRMQState.set_channel_ripper_pid(channel_ripper_pid)
          :ok
        else
          nil -> {:error, :nil_connection_pid}
          {:error, _} = error -> error
          error -> {:error, error}
        end
      end

      defp xrmq_open_channel(state) do
        case XRMQConnection.get(XRMQState.get_connection_pid()) do
          {:ok, connection} ->
            XRMQState.set_connection_status(:connected)

            case AMQP.Channel.open(connection) do
              {:ok, %AMQP.Channel{pid: pid} = channel} ->
                XRMQChannelRipper.set_channel(XRMQState.get_channel_ripper_pid(), channel)
                channel_monitor = Process.monitor(pid)
                XRMQState.set_channel_info(channel, channel_monitor)

                XRMQLogger.debug("opened a new channel")

                with {:ok, state} <- xrmq_channel_setup(channel, state) do
                  xrmq_channel_open(channel, state)
                end

              error ->
                XRMQLogger.error("could not open a new channel: #{inspect(error)}")
                XRMQState.set_channel_info(nil, nil)
                Process.exit(self(), {:xrmq_channel_open_error, error})

                {:error, error, state}
            end

          {:error, reason} ->
            {:error, reason, state}
        end
      end

      defp xrmq_declare(channel, {:exchange, exchange_config}) do
        with :ok <- xrmq_exchange_declare(channel, exchange_config),
             :ok <- xrmq_exchange_bindings(channel, exchange_config) do
          {:ok, nil}
        end
      end

      defp xrmq_declare(channel, {:queue, queue_config}) do
        with {:ok, %{queue: queue} = queue_info} <- xrmq_queue_declare(channel, queue_config),
             :ok <- xrmq_queue_bindings(queue, channel, queue_config) do
          {:ok, queue_info}
        end
      end

      defp xrmq_declare(
             channel,
             {:bind, %XRMQBindConfig{type: :exchange, name: name} = bind_config}
           ) do
        with :ok <- xrmq_exchange_bind(channel, name, bind_config) do
          {:ok, nil}
        end
      end

      defp xrmq_declare(channel, {:bind, %XRMQBindConfig{type: :queue, name: name} = bind_config}) do
        with :ok <- xrmq_queue_bind(channel, name, bind_config) do
          {:ok, nil}
        end
      end

      defp xrmq_exchange_declare(channel, %XRMQExchangeConfig{name: name, type: type, opts: opts})
           when is_binary(name) do
        AMQP.Exchange.declare(channel, name, type, opts)
      end

      defp xrmq_exchange_bindings(channel, %XRMQExchangeConfig{
             name: destination,
             bindings: bindings
           }) do
        bindings
        |> Enum.reduce_while(:ok, fn binding, acc ->
          case xrmq_exchange_bind(channel, destination, binding) do
            :ok -> {:cont, acc}
            error -> {:halt, error}
          end
        end)
      end

      defp xrmq_exchange_bind(channel, destination, %XRMQBindConfig{exchange: source, opts: opts}) do
        AMQP.Exchange.bind(channel, destination, source, opts)
      end

      defp xrmq_queue_declare(channel, %XRMQQueueConfig{opts: opts} = config) do
        session_config = XRMQState.get_session_config()
        name = XRMQQueueConfig.get_queue_name(config)

        with queue = {:ok, %{queue: new_name}} <- AMQP.Queue.declare(channel, name, opts) do
          XRMQState.set_session_config(%XRMQSessionConfig{session_config | queue: new_name})
          queue
        end
      end

      defp xrmq_queue_bindings(queue, channel, %XRMQQueueConfig{bindings: bindings}) do
        Enum.reduce_while(bindings, :ok, fn binding, acc ->
          case xrmq_queue_bind(channel, queue, binding) do
            :ok -> {:cont, acc}
            error -> {:halt, error}
          end
        end)
      end

      defp xrmq_queue_bind(channel, queue, %XRMQBindConfig{exchange: exchange, opts: opts}) do
        AMQP.Queue.bind(channel, queue, exchange, opts)
      end

      defp xrmq_basic_publish(:connected, payload, exchange, routing_key, opts) do
        if XRMQEnvironmentConfig.accounting_enabled() do
          payload
          |> byte_size()
          |> Kernel./(1_024)
          |> Float.round()
          |> trunc()
          |> XRMQState.add_kb_of_messages_seen_so_far()
        end

        result =
          with {channel, _} when channel !== nil <- XRMQState.get_channel_info(),
               :ok <- AMQP.Basic.publish(channel, exchange, routing_key, payload, opts) do
            :ok
          else
            {nil, _} -> {:error, XRMQConstants.no_channel_error()}
            error -> {:error, error}
          end

        hibernate? = XRMQEnvironmentConfig.accounting_enabled() and XRMQState.hibernate?()

        {result, hibernate?}
      catch
        :exit, reason ->
          case reason do
            {:error, _} = error -> {error, false}
            error -> {{:error, error}, false}
          end
      end

      defp xrmq_basic_publish(:disconnected, payload, exchange, routing_key, opts) do
        if XRMQEnvironmentConfig.message_buffering_enabled() do
          XRMQState.add_buffered_message({payload, exchange, routing_key, opts})

          xrmq_on_message_buffered(
            XRMQState.get_buffered_messages_count(),
            payload,
            exchange,
            routing_key,
            opts
          )
        end

        {:ok, false}
      end

      defp xrmq_flush_buffered_messages(state) do
        case XRMQState.get_clear_buffered_messages() do
          {0, []} ->
            state

          {buffered_messages_count, buffered_messages} ->
            xrmq_flush_buffered_messages(buffered_messages_count, buffered_messages, state)
        end
      end

      defoverridable xrmq_on_try_init: 1,
                     xrmq_on_try_init_success: 1,
                     xrmq_on_try_init_error_retry: 2,
                     xrmq_on_try_init_error: 2,
                     xrmq_session_setup: 3,
                     xrmq_channel_setup: 2,
                     xrmq_channel_open: 2,
                     xrmq_channel_close: 1,
                     xrmq_on_connection_opened: 2,
                     xrmq_on_connection_closed: 1,
                     xrmq_on_connection_reopened: 2,
                     xrmq_on_message_buffered: 5,
                     xrmq_flush_buffered_messages: 3
    end
  end
end
