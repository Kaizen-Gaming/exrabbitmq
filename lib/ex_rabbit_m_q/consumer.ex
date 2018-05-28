defmodule ExRabbitMQ.Consumer do
  @moduledoc """
  A behaviour module that abstracts away the handling of RabbitMQ connections and channels.

  It abstracts the handling of message delivery and acknowlegement.

  It also provides hooks to allow the programmer to wrap the consumption of a message without having to directly
  access the AMPQ interfaces.

  For a connection configuration example see `ExRabbitMQ.Connection.Config`.

  For a queue configuration example see `ExRabbitMQ.Consumer.QueueConfig`.

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
        xrmq_init(:my_connection_config, :my_queue_config, state)
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

  alias ExRabbitMQ.AST.Common, as: C

  require ExRabbitMQ.AST.Common
  require ExRabbitMQ.AST.Consumer.GenServer
  require ExRabbitMQ.AST.Consumer.GenStage

  @type callback_result ::
          {:noreply, state :: term}
          | {:noreply, state :: term, timeout | :hibernate}
          | {:noreply, [event :: term], state :: term}
          | {:noreply, [event :: term], state :: term, :hibernate}
          | {:stop, reason :: term, state :: term}

  @doc """
  Setup the process for consuming a RabbitMQ queue.

  Initiates a connection or reuses an existing one.
  When a connection is established then a new channel is opened.
  Next, `c:xrmq_channel_setup/2` is called to do any extra work on the opened channel.
  If `start_consuming` is `true` then the process will start consume messages from RabbitMQ.

  The function accepts the following arguments:
  * `connection` - The configuration information for the RabbitMQ connection.
    It can either be a `ExRabbitMQ.Connection.Config` struct or an atom that will be used as the `key` for reading the
    the `:exrabbitmq` configuration part from the enviroment.
    For more information on how to configure the connection, check `ExRabbitMQ.Connection.Config`.
  * `queue` - The configuration information for the RabbitMQ queue to consume.
    It can either be a `ExRabbitMQ.Consumer.QueueConfig` struct or an atom that will be used as the `key` for reading the
    the `:exrabbitmq` configuration part from the enviroment.
    For more information on how to configure the consuming queue, check `ExRabbitMQ.Connection.Config`.
  * `start_consuming` - When `true` then `c:xrmq_consume/1` is called automatically after the connection and channel has
    been established successfully. *Optional: Defaults to `true`.*
  * `state` - The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_init(
              connection :: C.connection(),
              queue :: C.queue(),
              start_consuming :: boolean,
              state :: term
            ) :: C.result()

  @doc """
  Returns a part of the `:exrabbitmq` configuration section, specified with the `key` argument.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.

  **Deprecated:** Use `ExRabbitMQ.Connection.Config.from_env/2` or `ExRabbitMQ.Consumer.QueueConfig.from_env/2` instead.
  """
  @callback xrmq_get_env_config(key :: atom) :: keyword

  @doc """
  Returns the connection configuration as it was passed to `c:xrmq_init/4`.

  This configuration is set in the wrapper process's dictionary.
  For the configuration format see the top section of `ExRabbitMQ.Consumer`.

  **Deprecated:** Use `ExRabbitMQ.State.get_connection_config/0` instead.
  """
  @callback xrmq_get_connection_config() :: term

  @doc """
  Returns the queue configuration as it was passed to `c:xrmq_init/4`.

  This configuration is set in the wrapper process's dictionary.
  For the configuration format see the top section of `ExRabbitMQ.Consumer`.

  **Deprecated:** Use `ExRabbitMQ.State.get_queue_config/0` instead.
  """
  @callback xrmq_get_queue_config() :: term

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
  This hook is called automatically, if `start_consuming` was `true` when `c:xrmq_init/4`.

  If not, then the user has to call it to start consuming.

  It is invoked when a connection has been established and a new channel has been opened.

  Its flow is to:
  1. Declare the queue
  2. Run `c:xrmq_queue_setup/3`
  3. Start consuming from the queue

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_consume(state :: term) :: C.result()

  @doc """
  This hook is called automatically as part of the flow in `c:xrmq_consume/1`.

  It allows the user to run extra queue setup steps when the queue has been declared.
  The default queue setup uses the exchange, exchange_opts, bind_opts and qos_opts from
  the queue's configuration to setup the QoS, declare the exchange and bind it with the queue.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_queue_setup(channel :: %AMQP.Channel{}, queue :: String.t(), state :: term) ::
              C.result()

  @doc """
  This callback is the only required callback (i.e., without any default implementation) and
  is called as a response to a `:basic_consume` message.

  It is passed the `payload` of the request as well as the `meta` object or the message.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_deliver(payload :: term, meta :: term, state :: term) :: callback_result

  @doc """
  This overridable hook is  called as a response to a `:basic_cancel` message.

  It is passed the `cancellation_info` of the request and by default it logs an error and
  returns `{:stop, :basic_cancel, state}`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_cancel(cancellation_info :: term, state :: term) :: callback_result

  @doc """
  This overridable function can be called whenever `no_ack` is set to `false` and the user
  wants to *ack* a message.

  It is passed the `delivery_tag` of the request and by default it simply *acks* the message
  as per the RabbitMQ API.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_ack(delivery_tag :: String.t(), state :: term) :: C.result()

  @doc """
  This overridable function can be called whenever `no_ack` is set to `false` and the user wants
  to reject a message.

  It is passed the `delivery_tag` of the request and by default it simply rejects the message
  as per the RabbitMQ API.

  If the `opts` argument is omitted, the default value is `[]`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_reject(delivery_tag :: String.t(), opts :: term, state :: term) ::
              C.result()

  @doc """
  This overridable function publishes the `payload` to the `exchange` using the provided `routing_key`.

  The wrapper process's state is passed in to allow the callback to mutate it if overriden.
  """
  @callback xrmq_basic_publish(
              payload :: term,
              exchange :: String.t(),
              routing_key :: String.t(),
              opts :: [term]
            ) :: C.basic_publish_result()

  @doc """
  Helper function that extracts the `state` argument from the passed in tuple.
  """
  @callback xrmq_extract_state({:ok, state :: term} | {:error, reason :: term, state :: term}) ::
              state :: term

  # credo:disable-for-next-line
  defmacro __using__({:__aliases__, _, [kind]})
           when kind in [:GenServer, :GenStage] do
    common_ast = ExRabbitMQ.AST.Common.ast()

    inner_ast =
      if kind === :GenStage do
        ExRabbitMQ.AST.Consumer.GenStage.ast()
      else
        ExRabbitMQ.AST.Consumer.GenServer.ast()
      end

    # credo:disable-for-next-line
    quote location: :keep do
      require Logger

      @behaviour ExRabbitMQ.Consumer

      alias ExRabbitMQ.Constants, as: XRMQConstants
      alias ExRabbitMQ.State, as: XRMQState
      alias ExRabbitMQ.Connection.Config, as: XRMQConnectionConfig
      alias ExRabbitMQ.Consumer.QueueConfig, as: XRMQQueueConfig

      unquote(inner_ast)

      def xrmq_init(connection_config_spec, queue_config_spec, start_consuming \\ true, state)

      def xrmq_init(connection_key, queue_key, start_consuming, state)
          when is_atom(connection_key) and is_atom(queue_key) do
        connection_config = XRMQConnectionConfig.from_env(connection_key)
        queue_config = XRMQQueueConfig.from_env(queue_key)

        xrmq_init(connection_config, queue_config, start_consuming, state)
      end

      def xrmq_init(connection_key, %XRMQQueueConfig{} = queue_config, start_consuming, state)
          when is_atom(connection_key) do
        connection_config = XRMQConnectionConfig.from_env(connection_key)

        xrmq_init(connection_config, queue_config, start_consuming, state)
      end

      def xrmq_init(
            %XRMQConnectionConfig{} = connection_config,
            queue_key,
            start_consuming,
            state
          )
          when is_atom(queue_key) do
        queue_config = XRMQQueueConfig.from_env(queue_key)

        xrmq_init(connection_config, queue_config, start_consuming, state)
      end

      def xrmq_init(
            %XRMQConnectionConfig{} = connection_config,
            %XRMQQueueConfig{} = queue_config,
            start_consuming,
            state
          ) do
        queue_config = XRMQQueueConfig.merge_defaults(queue_config)

        connection_config_result =
          connection_config
          |> XRMQConnectionConfig.merge_defaults()
          |> XRMQConnectionConfig.validate_connection_config()

        with {:ok, new_connection_config} <- connection_config_result,
              :ok <- xrmq_connection_setup(new_connection_config) do
          XRMQState.set_queue_config(queue_config)
          xrmq_open_channel_consume(state, start_consuming)
        end
      end

      defp xrmq_open_channel_consume(state) do
        xrmq_open_channel_consume(state, true)
      end

      defp xrmq_open_channel_consume(state, true) do
        with {:ok, state} <- xrmq_open_channel(state) do
          xrmq_consume(state)
        end
      end

      defp xrmq_open_channel_consume(state, _) do
        xrmq_open_channel(state)
      end

      def xrmq_consume(state) do
        {channel, _} = XRMQState.get_channel_info()
        config = XRMQState.get_queue_config()

        if channel === nil or config === nil do
          nil
        else
          with {:ok, queue} <- xrmq_queue_declare(channel, config),
               {:ok, state} <- xrmq_queue_setup(channel, queue, state),
               {:ok, _} <- AMQP.Basic.consume(channel, queue, nil, config.consume_opts) do
            {:ok, state}
          else
            {:error, _reason, _state} = error -> error
            {:error, reason} -> {:error, reason, state}
            error -> {:error, error, state}
          end
        end
      end

      def xrmq_queue_setup(channel, queue, state) do
        config = XRMQState.get_queue_config()

        with :ok <- xrmq_qos_setup(channel, config),
             :ok <- xrmq_exchange_declare(channel, config),
             :ok <- xrmq_queue_bind(channel, queue, config) do
          {:ok, state}
        else
          {:error, reason} -> {:error, reason, state}
        end
      end

      defp xrmq_qos_setup(_channel, %{qos_opts: []}) do
        :ok
      end

      defp xrmq_qos_setup(channel, %{qos_opts: opts}) do
        AMQP.Basic.qos(channel, opts)
      end

      defp xrmq_queue_declare(channel, %{queue: queue, queue_opts: opts}) do
        with {:ok, %{queue: queue}} <- AMQP.Queue.declare(channel, queue, opts) do
          {:ok, queue}
        end
      end

      defp xrmq_exchange_declare(_channel, %{exchange: nil}) do
        :ok
      end

      defp xrmq_exchange_declare(channel, %{exchange: exchange, exchange_opts: opts}) do
        AMQP.Exchange.declare(channel, exchange, opts[:type] || :direct, opts)
      end

      defp xrmq_queue_bind(_channel, _queue, %{exchange: nil}) do
        :ok
      end

      defp xrmq_queue_bind(channel, queue, %{exchange: exchange, bind_opts: opts}) do
        AMQP.Queue.bind(channel, queue, exchange, opts)
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

      @deprecated "Use ExRabbitMQ.State.get_queue_config/0 instead"
      def xrmq_get_queue_config do
        XRMQState.get_queue_config()
      end

      unquote(common_ast)

      defoverridable xrmq_queue_setup: 3,
                     xrmq_basic_cancel: 2,
                     xrmq_basic_ack: 2,
                     xrmq_basic_reject: 2,
                     xrmq_basic_reject: 3
    end
  end
end
