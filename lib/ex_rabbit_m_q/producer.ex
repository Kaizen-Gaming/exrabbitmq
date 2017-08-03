defmodule ExRabbitMQ.Producer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It also provides hooks to allow the programmer to publish a message without having to directly
  access the AMPQ interfaces.
  """

  @callback xrmq_init(connection_key :: atom, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_init(connection_config :: struct, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_get_connection_config() :: term
  @callback xrmq_channel_setup(state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}
  @callback xrmq_basic_publish(payload :: term, exchange :: String.t, routing_key :: String.t, opts :: [term]) ::
    :ok |
    {:error, reason :: :blocked | :closing | :no_channel}

  require ExRabbitMQ.AST.Common
  require ExRabbitMQ.AST.Producer.GenServer

  defmacro __using__(_) do
    common_ast = ExRabbitMQ.AST.Common.ast()
    inner_ast = ExRabbitMQ.AST.Producer.GenServer.ast()

    quote location: :keep do
      require Logger

      alias ExRabbitMQ.Constants
      alias ExRabbitMQ.Connection
      alias ExRabbitMQ.ConnectionConfig

      unquote(inner_ast)

      def xrmq_init(connection_key, state)
      when is_atom(connection_key) do
        xrmq_init(xrmq_get_connection_config(connection_key), state)
      end

      def xrmq_init(%ConnectionConfig{} = connection_config, state) do
        connection_config = xrmq_set_connection_config_defaults(connection_config)

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

        xrmq_open_channel(state)
      end

      def xrmq_basic_publish(payload, exchange, routing_key, opts \\ []) do
        with\
          {channel, _} when channel !== nil <- xrmq_get_channel_info(),
          :ok <- AMQP.Basic.publish(channel, exchange, routing_key, payload, opts) do
          :ok
        else
          {nil, _} -> {:error, Constants.no_channel_error()}
          error -> {:error, error}
        end
      end

      unquote(common_ast)
    end
  end
end
