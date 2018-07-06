defmodule ExRabbitMQ.Producer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It also provides hooks to allow the programmer to publish a message without having to directly
  access the AMPQ interfaces.

  For a connection configuration example see `ExRabbitMQ.Config.Connection`.

  #### Example usage for a producer implementing a `GenServer`

  ```elixir
  defmodule MyExRabbitMQProducer do
    @module __MODULE__

    use GenServer
    use ExRabbitMQ.Producer

    def start_link do
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

  alias ExRabbitMQ.AST.Common, as: C

  require ExRabbitMQ.AST.Common
  require ExRabbitMQ.AST.Producer.GenServer

  @doc """
  Setup the process for producing messages on RabbitMQ.

  Initiates a connection or reuses an existing one.
  When a connection is established then a new channel is opened.
  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.

  The function accepts the following arguments:
  * `connection` - The configuration information for the RabbitMQ connection.
    It can either be a `ExRabbitMQ.Config.Connection` struct or an atom that will be used as the `key` for reading the
    the `:exrabbitmq` configuration part from the enviroment.
    For more information on how to configure the connection, check `ExRabbitMQ.Config.Connection`.
  * `state` - The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_init(connection :: C.connection(), state :: term) :: C.result()

  @doc """
  Returns a part of the `:exrabbitmq` configuration section, specified with the
  `key` argument.

  For the configuration format see the top section of `ExRabbitMQ.Producer`.

  **Deprecated:** Use `ExRabbitMQ.Config.Connection.from_env/2` instead.
  """
  @callback xrmq_get_env_config(key :: atom) :: keyword

  @doc """
  Returns the connection configuration as it was passed to `c:xrmq_init/2`.

  This configuration is set in the wrapper process's dictionary.
  For the configuration format see the top section of `ExRabbitMQ.Producer`.

  **Deprecated:** Use `ExRabbitMQ.State.get_connection_config/0` instead.
  """
  @callback xrmq_get_connection_config() :: term

  @doc """
  This hook is called when a connection has been established and a new channel has been opened.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_channel_setup(channel :: %AMQP.Channel{}, state :: term) :: C.result()

  @doc """
  This hook is called when a connection has been established and a new channel has been opened,
  right after `c:xrmq_channel_setup/2`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_channel_open(channel :: %AMQP.Channel{}, state :: term) :: C.result()

  @doc """
  This overridable function publishes the **binary** `payload` to the `exchange` using the provided `routing_key`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_publish(
              payload :: String.t(),
              exchange :: String.t(),
              routing_key :: String.t(),
              opts :: [term]
            ) :: C.basic_publish_result()

  @doc """
  Helper function that extracts the `state` argument from the passed in tuple.
  """
  @callback xrmq_extract_state({:ok, state :: term} | {:error, reason :: term, state :: term}) ::
              state :: term

  defmacro __using__(_) do
    common_ast = ExRabbitMQ.AST.Common.ast()
    inner_ast = ExRabbitMQ.AST.Producer.GenServer.ast()

    quote location: :keep do
      require Logger

      alias ExRabbitMQ.Config.Connection, as: XRMQConnectionConfig
      alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig

      unquote(inner_ast)

      def xrmq_init(connection_config, session_config \\ nil, state) do
        connection_config = XRMQConnectionConfig.get(connection_config)
        session_config = XRMQSessionConfig.get(session_config)

        with :ok <- xrmq_connection_setup(connection_config) do
          XRMQState.set_session_config(session_config)
          xrmq_open_channel_setup(state)
        else
          {:error, reason} -> {:error, reason, state}
        end
      end

      def xrmq_open_channel_setup(state) do
        with {:ok, state} <- xrmq_open_channel(state) do
          {channel, _} = XRMQState.get_channel_info()
          session_config = XRMQState.get_session_config()

          xrmq_session_setup(channel, session_config, state)
        else
          {:error, _reason, _state} = error -> error
          {:error, reason} -> {:error, reason, state}
          error -> {:error, error, state}
        end
      end

      unquote(common_ast)
    end
  end
end
