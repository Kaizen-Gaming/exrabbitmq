defmodule ExRabbitMQ.Consumer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It abstracts the handling of message delivery and acknowlegement.

  It also provides hooks to allow the programmer to wrap the consumption of a message without having to directly
  access the AMPQ interfaces.
  """

  @callback xrmq_init(connection_key :: atom, queue_key :: atom, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_init(connection_key :: atom, queue_config :: struct, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_init(connection_config :: struct, queue_key :: atom, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_init(connection_config :: struct, queue_config :: struct, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_get_connection_config() :: term
  @callback xrmq_get_queue_config() :: term
  @callback xrmq_channel_setup(channel :: term, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_queue_setup(channel :: term, queue :: String.t, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_basic_deliver(payload :: term, meta :: term, state :: term) ::
    {:noreply, new_state :: term} |
    {:noreply, new_state :: term, timeout | :hibernate} |
    {:noreply, [event :: term], new_state :: term} |
    {:noreply, [event :: term], new_state :: term, :hibernate} |
    {:stop, reason :: term, new_state :: term}
  @callback xrmq_basic_cancel(cancellation_info :: any, state :: any) ::
    {:noreply, new_state :: term} |
    {:noreply, new_state :: term, timeout | :hibernate} |
    {:noreply, [event :: term], new_state :: term} |
    {:noreply, [event :: term], new_state :: term, :hibernate} |
    {:stop, reason :: term, new_state :: term}
  @callback xrmq_basic_ack(delivery_tag :: String.t, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_basic_reject(delivery_tag :: String.t, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_basic_reject(delivery_tag :: String.t, opts :: term, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  require ExRabbitMQ.AST.Common
  require ExRabbitMQ.AST.Consumer.GenServer
  require ExRabbitMQ.AST.Consumer.GenStage

  defmacro __using__({:__aliases__, _, [kind]})
  when kind in [:GenServer, :GenStage] do
    common_ast = ExRabbitMQ.AST.Common.ast()

    inner_ast =
      if kind === :GenServer do
        ExRabbitMQ.AST.Consumer.GenServer.ast()
      else
        ExRabbitMQ.AST.Consumer.GenStage.ast()
      end

    quote location: :keep do
      require Logger

      @behaviour ExRabbitMQ.Consumer

      alias ExRabbitMQ.Constants
      alias ExRabbitMQ.Connection
      alias ExRabbitMQ.ConnectionConfig
      alias ExRabbitMQ.Consumer.QueueConfig

      unquote(inner_ast)

      def xrmq_init(connection_key, queue_key, state)
      when is_atom(connection_key) and is_atom(queue_key) do
        xrmq_init(xrmq_get_connection_config(connection_key), xrmq_get_queue_config(queue_key), state)
      end

      def xrmq_init(connection_key, %QueueConfig{} = queue_config, state)
      when is_atom(connection_key) do
        xrmq_init(xrmq_get_connection_config(connection_key), queue_config, state)
      end

      def xrmq_init(%ConnectionConfig{} = connection_config, queue_key, state)
      when is_atom(queue_key) do
        xrmq_init(connection_config, xrmq_get_queue_config(queue_key), state)
      end

      def xrmq_init(%ConnectionConfig{} = connection_config, %QueueConfig{} = queue_config, state) do
        connection_config = xrmq_set_connection_config_defaults(connection_config)
        queue_config = xrmq_set_queue_config_defaults(queue_config)

        connection_pids_group_name = Constants.connection_pids_group_name()

        connection_pids =
          case :pg2.get_local_members(connection_pids_group_name) do
            [] -> []
            [_pid | _rest_pids] = pids -> pids
            {:error, {:no_such_group, ^connection_pids_group_name}} -> []
          end

        connection_pid =
          case Enum.find(connection_pids, fn c -> Connection.subscribe(c) end) do
            nil ->
              {:ok, pid} = ExRabbitMQ.ConnectionSupervisor.start_child(connection_config)
              pid
            pid ->
              pid
          end

        Process.link(connection_pid)

        Connection.subscribe(connection_pid)

        xrmq_set_connection_pid(connection_pid)
        xrmq_set_connection_config(connection_config)
        xrmq_set_queue_config(queue_config)

        xrmq_open_channel_consume(state)
      end

      defp xrmq_set_queue_config_defaults(%QueueConfig{} = config) do
        %QueueConfig{
          queue: config.queue || "",
          queue_opts: config.queue_opts || [],
          consume_opts: config.consume_opts || [],
        }
      end

      defp xrmq_consume(state) do
        {{channel, _}, config} = {xrmq_get_channel_info(), xrmq_get_queue_config()}

        if channel === nil or config === nil do
          nil
        else
          {:ok, %{queue: queue}} = AMQP.Queue.declare(channel, config.queue, config.queue_opts)

          case xrmq_queue_setup(channel, queue, state) do
            {:ok, _new_state} = result_ok ->
              {:ok, _} = AMQP.Basic.consume(channel, queue, nil, config.consume_opts)

              result_ok
            error ->
              error
          end
        end
      end

      def xrmq_queue_setup(_channel, _queue, state) do
        {:ok, state}
      end

      def xrmq_basic_ack(delivery_tag, state) do
        case xrmq_get_channel_info() do
          {nil, _} ->
            {:error, Constants.no_channel_error(), state}
          {channel, _} ->
            try do
              case AMQP.Basic.ack(channel, delivery_tag) do
                :ok -> {:ok, state}
                error -> {:error, error, state}
              end
            catch
              :exit, reason ->
                {:error, reason, state}
            end
        end
      end

      def xrmq_basic_reject(delivery_tag, state) do
        xrmq_basic_reject(delivery_tag, [], state)
      end

      def xrmq_basic_reject(delivery_tag, opts, state) do
        case xrmq_get_channel_info() do
          {nil, _} ->
            {:error, Constants.no_channel_error(), state}
          {channel, _} ->
            try do
              case AMQP.Basic.reject(channel, delivery_tag, opts) do
                :ok -> {:ok, state}
                error -> {:error, error, state}
              end
            catch
              :exit, reason ->
                {:error, reason, state}
            end
        end
      end

      def xrmq_get_queue_config() do
        Process.get(Constants.queue_config_key())
      end

      defp xrmq_get_queue_config(key) do
        config = Application.get_env(:exrabbitmq, key)

        %QueueConfig{
          queue: config[:queue],
          queue_opts: config[:queue_opts],
          consume_opts: config[:consume_opts],
        }
      end

      defp xrmq_set_queue_config(config) do
        if config === nil do
          Process.delete(Constants.queue_config_key())
        else
          Process.put(Constants.queue_config_key(), config)
        end
      end

      defp xrmq_open_channel_consume(state) do
        with\
          {:ok, new_state} <- xrmq_open_channel(state),
          {:ok, new_state} = result_ok <- xrmq_consume(new_state) do
          result_ok
        else
          error -> error
        end
      end

      unquote(common_ast)

      defoverridable xrmq_queue_setup: 3, xrmq_basic_cancel: 2, xrmq_basic_ack: 2, xrmq_basic_reject: 2, xrmq_basic_reject: 3
    end
  end
end
