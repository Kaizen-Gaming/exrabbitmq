defmodule ExRabbitMQ.Consumer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It abstracts the handling of message delivery and acknowlegement.

  It also provides hooks to allow the programmer to wrap the consumption of a message without having to directly
  access the AMPQ interfaces.

  For a connection configuration example see `ExRabbitMQ.Config.Connection`.

  For a queue configuration example see `ExRabbitMQ.Config.Session`.

  #### Example usage for a consumer implementing a `GenServer`

  ```elixir
  defmodule MyExRabbitMQConsumer do
    @module __MODULE__

    use GenServer
    use ExRabbitMQ.Consumer, GenServer

    def start_link do
      GenServer.start_link(@module, :ok)
    end

    def init(state) do
      new_state =
        xrmq_init(:my_connection_config, :my_session_config, state)
        |> xrmq_extract_state()

      {:ok, new_state}
    end

    # required override
    def xrmq_basic_deliver(payload, meta, state) do
      # your message delivery logic goes here...

      {:noreply, state}
    end

    # optional override when there is a need to do setup the channel right after the connection has been established.
    def xrmq_channel_setup(channel, state) do
      # any channel setup goes here...

      {:ok, state}
    end

    # optional override when there is a need to setup the queue and/or exchange just before the consume.
    def xrmq_queue_setup(channel, queue, state) do
      # The default queue setup uses the exchange, exchange_opts, bind_opts and qos_opts from
      # the queue's configuration to setup the QoS, declare the exchange and bind it with the queue.
      # Your can override this function, but you can also keep this functionality of the automatic queue setup by
      # calling super, eg:
      {:ok, state} = super(channel, queue, state)

      # any other queue setup goes here...
    end
  end
  ```
  """

  alias ExRabbitMQ.AST.Common, as: CommonAST
  alias ExRabbitMQ.Config.Session, as: SessionConfig
  alias ExRabbitMQ.State, as: XRMQState

  require ExRabbitMQ.AST.Common
  require ExRabbitMQ.AST.Consumer.GenServer

  @type callback_result ::
          {:noreply, term}
          | {:noreply, term, timeout | :hibernate}
          | {:noreply, [term], term}
          | {:noreply, [term], term, :hibernate}
          | {:stop, term, term}

  @doc """
  Setup the process for consuming a RabbitMQ queue.

  Initiates a connection or reuses an existing one.
  When a connection is established then a new channel is opened.
  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.
  If `start_consuming` is `true` then the process will start consume messages from RabbitMQ.

  The function accepts the following arguments:
  * `connection` - The configuration information for the RabbitMQ connection.
    It can either be a `ExRabbitMQ.Config.Connection` struct or an atom that will be used as the `key` for reading the
    the `:exrabbitmq` configuration part from the enviroment.
    For more information on how to configure the connection, check `ExRabbitMQ.Config.Connection`.
  * `queue` - The configuration information for the RabbitMQ queue to consume.
    It can either be a `ExRabbitMQ.Config.Session` struct or an atom that will be used as the `key` for reading the
    the `:exrabbitmq` configuration part from the enviroment.
    For more information on how to configure the consuming queue, check `ExRabbitMQ.Config.Connection`.
  * `start_consuming` - When `true` then `c:xrmq_consume/1` is called automatically after the connection and channel has
    been established successfully. *Optional: Defaults to `true`.*
  * `state` - The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_init(CommonAST.connection(), CommonAST.queue(), boolean, term) ::
              CommonAST.result()

  @doc """
  This helper function tries to use `c:xrmq_init/4` to set up a connection to RabbitMQ.

  In case that fails, it tries again after a configured interval.

  The interval can be configured by writing:

  ```elixir
  config :exrabbitmq, :try_init_interval, <THE INTERVAL BETWEEN CONNECTION RETRIES IN MILLISECONDS>
  ```

  The simplest way to use this is to add the following as part of the `GenServer.init/1` callback result:

  ```elixir
  ExRabbitMQ.continue_tuple_try_init(connection_config, session_config, true)
  ```

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_try_init(CommonAST.connection(), CommonAST.queue(), boolean, term) ::
              CommonAST.result()

  @doc """
  This overridable callback is called by `c:xrmq_try_init/4` just before a new connection attempt is made.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_on_try_init(term) :: term

  @doc """
  This overridable callback is called by `c:xrmq_try_init/4` when a new connection has been established.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_on_try_init_success(term) :: term

  @doc """
  This overridable callback is called by `c:xrmq_try_init/4` when a new connection could not be established.

  The error the occurred as well as the wrapper process's state is passed in to allow the callback to mutate
  it if overriden.
  """
  @callback xrmq_on_try_init_error(term, term) :: term

  @doc false
  @callback xrmq_open_channel_setup_consume(term, boolean) :: {:ok, term} | {:error, term, term}

  @doc false
  @callback xrmq_session_setup(AMQP.Channel.t(), atom | SessionConfig.t(), term) ::
              CommonAST.result()

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
  This hook is called automatically, if `start_consuming` was `true` when `c:xrmq_init/4`.

  If not, then the user has to call it to start consuming.

  It is invoked when a connection has been established and a new channel has been opened.

  Its flow is to:
  1. Declare the queue
  2. Run `c:xrmq_queue_setup/3`
  3. Start consuming from the queue

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_consume(term) :: CommonAST.result()

  @doc """
  This hook is called automatically as part of the flow in `c:xrmq_consume/1`.

  It allows the user to run extra queue setup steps when the queue has been declared.
  The default queue setup uses the exchange, exchange_opts, bind_opts and qos_opts from
  the queue's configuration to setup the QoS, declare the exchange and bind it with the queue.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.

  This callback is the only required callback (i.e., without any default implementation) and
  is called as a response to a `:basic_consume` message.

  It is passed the `payload` of the request as well as the `meta` object or the message.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_deliver(term, term, term) :: callback_result

  @doc """
  This overridable hook is  called as a response to a `:basic_cancel` message.

  It is passed the `cancellation_info` of the request and by default it logs an error and
  returns `{:stop, :basic_cancel, state}`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_cancel(term, term) :: callback_result

  @doc """
  This overridable function can be called whenever `no_ack` is set to `false` and the user
  wants to *ack* a message.

  It is passed the `delivery_tag` of the request and by default it simply *acks* the message
  as per the RabbitMQ API.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_ack(String.t(), term) :: CommonAST.result()

  @doc """
  This overridable function can be called whenever `no_ack` is set to `false` and the user wants
  to reject a message.

  It is passed the `delivery_tag` of the request and by default it simply rejects the message
  as per the RabbitMQ API.

  If the `opts` argument is omitted, the default value is `[]`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_reject(String.t(), term, term) :: CommonAST.result()

  @doc """
  This overridable function publishes the `payload` to the `exchange` using the provided `routing_key`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_publish(term, String.t(), String.t(), [term]) ::
              CommonAST.basic_publish_result()

  @doc """
  Helper function that extracts the `state` argument from the passed in tuple.
  """
  @callback xrmq_extract_state({:ok, term} | {:error, term, term}) :: term

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
  This overridable hook is called when receiving a message and having enabled message size accounting,
  it is decided that the process should hibernate.

  Message size accounting (disabled by default) can be enabled by writing:

  ```elixir
  config :exrabbitmq, :accounting_enabled, true
  ```

  The configuration option to set the threshold for the message bytes seen so far, in KBs, is set by writing:

  ```elixir
  config :exrabbitmq, :kb_of_messages_seen_so_far_threshold, <NUMBER OF KBs TO USE AS THE THRESHOLD>
  ```

  The result of this callback will be returned as the result of the callback where the message has been delivered
  and `c:xrmq_basic_deliver/3` has been called.

  The result of `c:xrmq_basic_deliver/3` is the one used as the argument to this callback and by default it is left
  untouched.
  """
  @callback xrmq_on_hibernation_threshold_reached(tuple) :: tuple

  @doc """
  This overridable hook is called when a message is buffered while waiting for a connection to be (re-)established.

  Message buffering (disabled by default) can be enabled by writing:

  ```elixir
  config :exrabbitmq, :message_buffering_enabled, true
  ```

  The arguments passed are the current count of the buffered messages so far as well as the message payload,
  exchange, routing key and the options passed to the call to `xrmq_basic_publish/4`.
  """
  @callback xrmq_on_message_buffered(non_neg_integer, binary, binary, binary, keyword) :: term

  @doc """
  This overridable hook is called when a connection is (re-)established and there are buffered messages to send.

  Message buffering (disabled by default) can be enabled by writing:

  ```elixir
  config :exrabbitmq, :message_buffering_enabled, true
  ```

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_flush_buffered_messages([XRMQState.buffered_message()], term) :: term

  # credo:disable-for-next-line
  defmacro __using__(_) do
    inner_ast = ExRabbitMQ.AST.Consumer.GenServer.ast()
    common_ast = ExRabbitMQ.AST.Common.ast()

    # credo:disable-for-next-line
    quote location: :keep do
      alias ExRabbitMQ.Config.Connection, as: XRMQConnectionConfig
      alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig
      alias ExRabbitMQ.Constants, as: XRMQConstants
      alias ExRabbitMQ.State, as: XRMQState

      require Logger

      unquote(inner_ast)

      def xrmq_init(connection_config, session_config, start_consuming \\ true, state) do
        connection_config = XRMQConnectionConfig.get(connection_config)
        session_config = XRMQSessionConfig.get(session_config)

        case xrmq_connection_setup(connection_config) do
          :ok ->
            XRMQState.set_session_config(session_config)

            case xrmq_open_channel_setup_consume(start_consuming, state) do
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

      def xrmq_try_init(connection_config, session_config, start_consuming \\ true, state) do
        xrmq_try_init_consumer({connection_config, session_config, start_consuming}, state)
      end

      def xrmq_open_channel_setup_consume(start_consuming \\ true, state)

      def xrmq_open_channel_setup_consume(start_consuming, state) do
        with {:ok, state} <- xrmq_open_channel(state),
             {channel, _} <- XRMQState.get_channel_info(),
             session_config <- XRMQState.get_session_config(),
             {:ok, state} <- xrmq_session_setup(channel, session_config, state),
             # get the session_config again because it may have changed (eg, by using an anonymous queue)
             session_config <- XRMQState.get_session_config(),
             {:ok, state} <- xrmq_qos_setup(channel, session_config.qos_opts, state) do
          if start_consuming,
            do: xrmq_consume(channel, session_config.queue, session_config.consume_opts, state),
            else: {:ok, state}
        else
          {:error, _reason, _state} = error -> error
          {:error, reason} -> {:error, reason, state}
          error -> {:error, error, state}
        end
      end

      def xrmq_consume(state) do
        {channel, _} = XRMQState.get_channel_info()
        session_config = XRMQState.get_session_config()

        xrmq_consume(channel, session_config.queue, session_config.consume_opts, state)
      end

      def xrmq_consume(channel, queue, consume_opts, state) do
        case AMQP.Basic.consume(channel, queue, nil, consume_opts) do
          {:ok, _} -> {:ok, state}
          {:error, reason} -> {:error, reason, state}
        end
      end

      defp xrmq_qos_setup(_channel, [], state), do: {:ok, state}

      defp xrmq_qos_setup(channel, opts, state) do
        with :ok <- AMQP.Basic.qos(channel, opts) do
          {:ok, state}
        end
      end

      def xrmq_basic_ack(delivery_tag, state) do
        case XRMQState.get_channel_info() do
          {nil, _} ->
            {:error, XRMQConstants.no_channel_error(), state}

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

      def xrmq_basic_reject(delivery_tag, opts \\ [], state) do
        case XRMQState.get_channel_info() do
          {nil, _} ->
            {:error, XRMQConstants.no_channel_error(), state}

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

      unquote(common_ast)

      defp xrmq_try_init_consumer(
             {connection_config_spec, session_config_spec, auto_consume} = opts,
             state
           ) do
        connection_config_spec
        |> xrmq_init(session_config_spec, auto_consume, state)
        |> xrmq_try_init_inner(opts)
      end

      defp xrmq_try_init_consumer({connection_config_spec, session_config_spec} = opts, state) do
        connection_config_spec
        |> xrmq_init(session_config_spec, true, state)
        |> xrmq_try_init_inner(opts)
      end

      defoverridable xrmq_basic_cancel: 2,
                     xrmq_basic_ack: 2,
                     xrmq_basic_reject: 2,
                     xrmq_basic_reject: 3
    end
  end
end
