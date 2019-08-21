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

  alias ExRabbitMQ.AST.Common, as: CommonAST
  alias ExRabbitMQ.Config.SessionConfig, as: SessionConfig

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
  @callback xrmq_init(CommonAST.connection(), atom | SessionConfig.t(), term) ::
              CommonAST.result()

  @doc """
  This helper function tries to use `c:xrmq_init/3` to set up a connection to RabbitMQ.

  In case that fails, it tries again after a configured interval.

  The interval can be configured by writing:

  ```elixir
  config :exrabbitmq, :try_init_interval, <THE INTERVAL BETWEEN CONNECTION RETRIES IN MILLISECONDS>
  ```

  The simplest way to use this is to add the following as part of the `GenServer.init/1` callback result:

  ```elixir
  ExRabbitMQ.continue_tuple_try_init(connection_config)

  # or

  ExRabbitMQ.continue_tuple_try_init(connection_config, session_config)
  ```

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_try_init(CommonAST.connection(), CommonAST.queue(), term) :: CommonAST.result()

  @doc """
  This overridable callback is called by `c:xrmq_try_init/3` just before a new connection attempt is made.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_on_try_init(term) :: term

  @doc """
  This overridable callback is called by `c:xrmq_try_init/3` when a new connection has been established.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  The return value of this callback tells the caller how to continue.

  If `{:cont, state}` is returned, the coller will continue with `{:noreply, state}`.

  If `{:halt, reason, state}` is returned, the caller will continue with `{:stop, reason, state}`.

  By default, the return value of this callback is `{:cont, state}`.
  """
  @callback xrmq_on_try_init_success(term) :: {:cont, term} | {:halt, term, term}

  @doc """
  This overridable callback is called by `c:xrmq_try_init/3` when a new connection could not be established
  but a new attempt can be made (ie, waiting for a connection to become available).

  The error the occurred as well as the wrapper process's state is passed in to allow the callback to mutate
  it if overriden.

  The return value of this callback tells the caller how to continue.

  If `{:cont, state}` is returned, the coller will continue with `{:noreply, state}`.

  If `{:halt, reason, state}` is returned, the caller will continue with `{:stop, reason, state}`.

  By default, the return value of this callback is `{:cont, state}`.
  """
  @callback xrmq_on_try_init_error_retry(term, term) :: {:cont, term} | {:halt, term, term}

  @doc """
  This overridable callback is called by `c:xrmq_try_init/3` when a new connection could not be established
  and the error is not normally recoverable (ie, an error not related to a connection being currently unavailable).

  The error that occurred as well as the wrapper process's state is passed in to allow the callback to mutate
  it if overriden.

  The return value of this callback tells the caller how to continue.

  If `{:cont, state}` is returned, the coller will continue with `{:noreply, state}`.

  If `{:halt, reason, state}` is returned, the caller will continue with `{:stop, reason, state}`.

  By default, the return value of this callback is `{:halt, reason, state}`.
  """
  @callback xrmq_on_try_init_error(term, term) :: {:cont, term} | {:halt, term, term}

  @doc false
  @callback xrmq_session_setup(AMQP.Channel.t(), atom | SessionConfig.t(), term) ::
              Common.result()

  @doc """
  This hook is called when a connection has been established and a new channel has been opened.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_channel_setup(AMQP.Channel.t(), term) :: CommonAST.result()

  @doc """
  This hook is called when a connection has been established and a new channel has been opened,
  right after `c:xrmq_channel_setup/2`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_channel_open(AMQP.Channel.t(), term) :: CommonAST.result()

  @doc """
  This overridable function publishes the **binary** `payload` to the `exchange` using the provided `routing_key`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_publish(String.t(), String.t(), String.t(), [term]) ::
              CommonAST.basic_publish_result()

  @doc """
  Helper function that extracts the `state` argument from the passed in tuple.
  """
  @callback xrmq_extract_state({:ok, term} | {:error, term, term}) :: state :: term

  @doc """
  This overridable hook is  called when an already established connection has just been re-established.

  It is passed the connection struct and the wrapper process's state is passed in to allow the callback
  to mutate it if overriden.
  """
  @callback xrmq_on_connection_reopened(AMQP.Connection.t(), term) :: term

  @doc """
  This overridable hook is  called when an already established connection is dropped.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_on_connection_closed(term) :: term

  @doc """
  This overridable hook is called when a connection is (re-)established and there are buffered messages to send.

  Message buffering (disabled by default) can be enabled by writing:

  ```elixir
  # this is a compile time constant
  config :exrabbitmq, :message_buffering_enabled, true
  ```

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_flush_buffered_messages([term], term) :: term

  defmacro __using__(_) do
    inner_ast = ExRabbitMQ.AST.Producer.GenServer.ast()
    common_ast = ExRabbitMQ.AST.Common.ast()

    quote location: :keep do
      require ExRabbitMQ.Logger, as: XRMQLogger

      alias ExRabbitMQ.Config.Connection, as: XRMQConnectionConfig
      alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig

      unquote(inner_ast)

      def xrmq_init(connection_config, session_config \\ nil, state) do
        connection_config = XRMQConnectionConfig.get(connection_config)
        session_config = XRMQSessionConfig.get(session_config)

        case xrmq_connection_setup(connection_config) do
          :ok ->
            XRMQState.set_session_config(session_config)

            case xrmq_open_channel_setup(state) do
              {:ok, state} ->
                state = xrmq_flush_buffered_messages(state)

                {:ok, state}

              error ->
                error
            end

          {:error, reason} ->
            XRMQState.set_connection_status(:disconnected)

            {:error, reason, state}
        end
      end

      def xrmq_try_init(connection_config, session_config \\ nil, state) do
        xrmq_try_init_producer({connection_config, session_config}, state)
      end

      def xrmq_open_channel_setup(state) do
        case xrmq_open_channel(state) do
          {:ok, state} ->
            {channel, _} = XRMQState.get_channel_info()
            session_config = XRMQState.get_session_config()

            xrmq_session_setup(channel, session_config, state)

          {:error, _reason, _state} = error ->
            error

          {:error, reason} ->
            {:error, reason, state}

          error ->
            {:error, error, state}
        end
      end

      unquote(common_ast)

      defp xrmq_try_init_producer({connection_config_spec, session_config_spec} = opts, state) do
        connection_config_spec
        |> xrmq_init(session_config_spec, state)
        |> xrmq_try_init_inner(opts)
      end

      defp xrmq_try_init_producer(connection_config_spec, state) do
        connection_config_spec
        |> xrmq_init(nil, state)
        |> xrmq_try_init_inner(connection_config_spec)
      end
    end
  end
end
