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
    GenServer.cast(self(), :init)

    {:ok, state}
  end

  def handle_call(:stop, _from, state) do
    {:reply, :ok, state, {:continue, :stop}}
  end

  def handle_cast(:init, state) do
    %{
      tester_pid: tester_pid,
      connection_config: connection_config,
      session_config: session_config
    } = state

    {message, new_state} =
      connection_config
      |> xrmq_init(session_config, state)
      |> case do
        {:ok, _} = result ->
          {{:connection_open, XRMQState.get_connection_pid()}, xrmq_extract_state(result)}

        {:error, reason, state} ->
          {{:error, reason}, state}
      end

    send(tester_pid, message)

    send(tester_pid, {:consumer_state, new_state})

    {:noreply, new_state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_continue(:stop, state) do
    xrmq_channel_close(state)

    {:stop, :normal, state}
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

  # # optional override when there is a need to setup the queue and/or exchange just before the consume.
  def xrmq_session_setup(channel, session_config, state) do
    {:ok, state} = super(channel, session_config, state)
    {:ok, Map.put(state, :consumer_queue_setup_ok, {:ok, session_config.queue})}
  end
end
