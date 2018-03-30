defmodule ExRabbitMQ.AST.Common do
  @moduledoc """
  Common function and types for `ExRabbitMQ.Consumer` and `ExRabbitMQ.Producer` modules.
  """

  @type connection ::
          atom
          | ExRabbitMQ.Connection.Config.t()

  @type queue ::
          atom
          | ExRabbitMQ.Consumer.QueueConfig.t()

  @type result ::
          {:ok, state :: term}
          | {:error, reason :: term, state :: term}

  @type basic_publish_result ::
          :ok
          | {:error, reason :: :blocked | :closing | :no_channel}

  @doc """
  Produces the common part of the AST for both the consumer and producer behaviours.

  Specifically, it holds getters and setters, using the process dictionary, to hold important information such as the channel
  pid and monitor reference.

  It also holds the AST necessary to open a channel when an AMQP connection is ready.
  """
  def ast do
    # credo:disable-for-previous-line
    quote location: :keep do
      alias ExRabbitMQ.{ChannelRipper, Connection, Constants, State}
      alias ExRabbitMQ.Connection.Config, as: ConnectionConfig

      def xrmq_channel_setup(_channel, state) do
        {:ok, state}
      end

      def xrmq_channel_open(_channel, state) do
        {:ok, state}
      end

      def xrmq_basic_cancel(cancellation_info, state) do
        Logger.error("received basic_cancel message", cancellation_info: cancellation_info)

        {:stop, :basic_cancel, state}
      end

      def xrmq_basic_publish(payload, exchange, routing_key, opts \\ []) do
        with {channel, _} when channel !== nil <- State.get_channel_info(),
             :ok <- AMQP.Basic.publish(channel, exchange, routing_key, payload, opts) do
          :ok
        else
          {nil, _} -> {:error, Constants.no_channel_error()}
          error -> {:error, error}
        end
      end

      def xrmq_extract_state({:ok, state}), do: state
      def xrmq_extract_state({:error, _, state}), do: state

      @deprecated "Use ExRabbitMQ.Connection.Config.from_env/2 or ExRabbitMQ.Consumer.QueueConfig.from_env/2 instead"
      def xrmq_get_env_config(key) do
        Application.get_env(:exrabbitmq, key)
      end

      @deprecated "Use ExRabbitMQ.State.get_connection_config/0 instead"
      def xrmq_get_connection_config do
        State.get_connection_config()
      end

      defp xrmq_connection_setup(connection_config) do
        with conn_pid when is_pid(conn_pid) <- Connection.get_subscribe(connection_config),
             true <- Process.link(conn_pid),
             {:ok, channel_ripper_pid} = ChannelRipper.start() do
          State.set_connection_pid(conn_pid)
          State.set_connection_config(connection_config)
          State.set_channel_ripper_pid(channel_ripper_pid)
          :ok
        else
          nil -> {:error, :nil_connection_pid}
          {:error, _} = error -> error
          error -> {:error, error}
        end
      end

      defp xrmq_open_channel(state) do
        case Connection.get(State.get_connection_pid()) do
          {:ok, connection} ->
            case AMQP.Channel.open(connection) do
              {:ok, %AMQP.Channel{pid: pid} = channel} ->
                ChannelRipper.set_channel(State.get_channel_ripper_pid(), channel)
                channel_monitor = Process.monitor(pid)
                State.set_channel_info(channel, channel_monitor)

                Logger.debug("opened a new channel")

                with {:ok, state} <- xrmq_channel_setup(channel, state) do
                  xrmq_channel_open(channel, state)
                end

              :closing ->
                State.set_channel_info(nil, nil)

                {:error, :closing, state}

              error ->
                Logger.error("could not open a new channel: #{inspect(error)}")
                State.set_channel_info(nil, nil)
                Process.exit(self(), {:xrmq_channel_open_error, error})

                {:error, error, state}
            end

          {:error, reason} ->
            {:error, reason, state}
        end
      end

      defoverridable xrmq_channel_setup: 2, xrmq_channel_open: 2
    end
  end
end
