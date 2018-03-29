defmodule ExRabbitMQ.Producer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It also provides hooks to allow the programmer to publish a message without having to directly
  access the AMPQ interfaces.

  For a connection configuration example see `ExRabbitMQ.Connection.Config`.

  #### Example usage for a producer implementing a `GenServer`

  ```elixir
  defmodule MyExRabbitMQProducer do
    @module __MODULE__

    use GenServer
    use ExRabbitMQ.Producer

    def start_link() do
      GenServer.start_link(@module, :ok)
    end

    def init(state) do
      new_state =
        xrmq_init(:my_connection_config, state)
        |> xrmq_extract_state()

      {:ok, new_state}
    end

    def handle_cast({:publish, something}, state) do
      xrmq_basic_publish(something, "", "my_queue")

      {:noreply, state}
    end

    # optional override when there is a need to do setup the channel right after the connection has been established.
    def xrmq_channel_setup(channel, state) do
      # any other channel setup goes here...

      {:ok, state}
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
              {:ok, new_state :: term}
              | {:error, reason :: term, new_state :: term}

  @doc """
  Initiates a connection or reuses an existing one.

  When a connection is established then a new channel is opened.

  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  This variant accepts a `ExRabbitMQ.Connection` struct as the argument for the `connection_config` parameter.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  For the configuration format see the top section of `ExRabbitMQ.Producer`.
  """
  @callback xrmq_init(connection_config :: struct, state :: term) ::
              {:ok, new_state :: term}
              | {:error, reason :: term, new_state :: term}

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
              {:ok, new_state :: term}
              | {:error, reason :: term, new_state :: term}

  @doc """
  This hook is called when a connection has been established and a new channel has been opened,
  right after `c:xrmq_channel_setup/2`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_channel_open(channel :: term, state :: term) ::
              {:ok, new_state :: term}
              | {:error, reason :: term, new_state :: term}

  @doc """
  This overridable function publishes the `payload` to the `exchange` using the provided `routing_key`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_publish(payload :: term, exchange :: String.t(), routing_key :: String.t(), opts :: [term]) ::
              :ok
              | {:error, reason :: :blocked | :closing | :no_channel}

  @doc """
  Helper function that extracts the `state` argument from the passed in tuple.
  """
  @callback xrmq_extract_state({:ok, state :: term} | {:error, reason :: term, state :: term}) ::
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
      alias ExRabbitMQ.Connection.Config, as: ConnectionConfig
      alias ExRabbitMQ.ChannelRipper

      unquote(inner_ast)

      def xrmq_init(connection_key, state)
          when is_atom(connection_key) do
        connection_config = ConnectionConfig.from_env(connection_key)

        xrmq_init(connection_config, state)
      end

      def xrmq_init(%ConnectionConfig{} = connection_config, state) do
        connection_config = ConnectionConfig.merge_defaults(connection_config)

        with :ok <- xrmq_connection_setup(connection_config) do
          xrmq_open_channel(state)
        end
      end

      unquote(common_ast)
    end
  end
end
