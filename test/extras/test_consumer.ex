defmodule TestConsumer do
  @module __MODULE__

  use GenServer, restart: :transient
  use ExRabbitMQ.Consumer, GenServer

  def start_link(state) do
    GenServer.start_link(@module, state)
  end

  def stop(consumer_pid) do
    GenServer.call(consumer_pid, :stop)
  end

  def init(state) do
    %{
      connection_config: connection_config,
      session_config: session_config
    } = state

    {:ok, state, ExRabbitMQ.continue_tuple_try_init(connection_config, session_config, true)}
  end

  def handle_call(:stop, _from, state) do
    {:reply, :ok, state, {:continue, :stop}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_continue(:stop, state) do
    xrmq_channel_close(state)

    {:stop, :normal, state}
  end

  # optional override where the process is notified of a new connection attempt
  def xrmq_on_try_init(state), do: state

  def xrmq_on_try_init_success(state) do
    %{tester_pid: tester_pid} = state

    message = {:connection_open, XRMQState.get_connection_pid()}

    send(tester_pid, message)

    send(tester_pid, {:consumer_state, state})

    state
  end

  def xrmq_on_try_init_error(reason, state) do
    %{tester_pid: tester_pid} = state

    message = {:error, reason}

    send(tester_pid, message)

    send(tester_pid, {:consumer_state, state})

    state
  end

  # required override
  def xrmq_basic_deliver(payload, _meta, %{tester_pid: tester_pid} = state) do
    send(tester_pid, {:consume, payload})
    {:noreply, state}
  end

  # optional override when there is a need to do setup the channel right after the connection has been established.
  def xrmq_channel_setup(channel, state) do
    {:ok, state} = super(channel, state)
    {:ok, Map.put(state, :consumer_channel_setup_ok, true)}
  end

  # optional override when there is a need to setup the queue and/or exchange just before the consume.
  def xrmq_session_setup(channel, session_config, state) do
    {:ok, state} = super(channel, session_config, state)
    {:ok, Map.put(state, :consumer_queue_setup_ok, {:ok, session_config.queue})}
  end

  # optional override for when a connection fails
  def xrmq_on_connection_closed(state), do: state

  # optional override for when a failed connection is re-established
  def xrmq_on_connection_reopened(%AMQP.Connection{}, state), do: state

  # optional override for when accounting has been activated:
  # `config :exrabbitmq, :accounting_enabled, true`
  # and the configured theshold:
  # `config :exrabbitmq, :kb_of_messages_seen_so_far_threshold, <NUMBER OF KBs TO USE AS THE THRESHOLD>`
  # has been reached
  # (ie, the configured amount of message KBs has been seen by the process)
  def xrmq_on_hibernation_threshold_reached(callback_result), do: callback_result

  # optional override for when a published message has been buffered after the underlying connection has failed
  # to enable message buffering: `config :exrabbitmq, :message_buffering_enabled, true`
  def xrmq_on_message_buffered(
        _buffered_messages_count,
        _payload,
        _exchange,
        _routing_key,
        _opts
      ) do
  end

  # optional override for when the buffered messages can be flushed after a new connection has been established
  # to enable message buffering: `config :exrabbitmq, :message_buffering_enabled, true`
  def xrmq_flush_buffered_messages(_buffered_messages_count, _buffered_messages, state), do: state
end
