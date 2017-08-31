defmodule ExRabbitMQ.Producer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It also provides hooks to allow the programmer to publish a message without having to directly
  access the AMPQ interfaces.

  For a connection configuration example see `ExRabbitMQ.ConnectionConfig`.

  #### Example usage for a producer implementing a `GenServer`

  ```elixir
  defmodule MyExRabbitMQProducer do
    @module __MODULE__

    use GenServer
    use ExRabbitMQ.Producer

    def start_link() do
      GenServer.start_link(@module, :ok)
    end

    def init(:ok) do
      new_state =
        xrmq_init(:connection, state)
        |> xrmq_extract_state()

      {:ok, new_state}
    end

    def handle_cast({:publish, something}, state) do
      xrmq_basic_publish(something, "", "my_queue")

      {:noreply, state}
    end

    # optional override
    def xrmq_channel_setup(channel, state) do
      # the default channel setup uses the optinal qos_opts from
      # the connection's configuration so we can use it
      # automatically by calling super,
      # unless we want to override everything
      {:ok, new_state} = super(channel, state)

      # any other channel setup goes here...

      {:ok, new_state}
    end
  end
  ```
  """

  @doc """
  Initiates a connection or reuses an existing one.

  When a connection is established then a new channel is opened.

  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  This variant accepts an atom as the argument for the `connection_key` parameters and
  uses this atom to read the connection's configuration.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  For the configuration format see the top section of `ExRabbitMQ.Producer`.
  """
  @callback xrmq_init(connection_key :: atom, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  Initiates a connection or reuses an existing one.

  When a connection is established then a new channel is opened.

  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  This variant accepts a `ExRabbitMQ.Connection` struct as the argument for the `connection_config` parameter.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  For the configuration format see the top section of `ExRabbitMQ.Producer`.
  """
  @callback xrmq_init(connection_config :: struct, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  Returns a part of the `:exrabbitmq` configuration section, specified with the
  `key` argument.

  For the configuration format see the top section of `ExRabbitMQ.Producer`.
  """
  @callback xrmq_get_env_config(key :: atom) :: keyword

  @doc """
  Returns the connection configuration as it was passed to `c:xrmq_init/2`.

  This configuration is set in the wrapper process's dictionary.

  For the configuration format see the top section of `ExRabbitMQ.Producer`.
  """
  @callback xrmq_get_connection_config() :: term

  @doc """
  This hook is called when a connection has been established and a new channel has been opened.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_channel_setup(channel :: term, state :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term, new_state :: term}

  @doc """
  This overridable function publishes the `payload` to the `exchange` using the provided `routing_key`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_publish(payload :: term, exchange :: String.t, routing_key :: String.t, opts :: [term]) ::
    :ok |
    {:error, reason :: :blocked | :closing | :no_channel}

  @doc """
  Helper function that extracts the `state` argument from the passed in tuple.
  """
  @callback xrmq_extract_state({:ok, state :: term}|{:error, reason :: term, state :: term}) ::
  state :: term

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
          case Enum.find(connection_pids, fn c -> Connection.subscribe(c, connection_config) end) do
            nil ->
              {:ok, pid} = ExRabbitMQ.ConnectionSupervisor.start_child(connection_config)
              Connection.subscribe(pid, connection_config)
              pid
            pid ->
              pid
          end

        Process.link(connection_pid)

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
