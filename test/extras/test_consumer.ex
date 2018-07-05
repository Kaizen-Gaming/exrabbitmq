defmodule TestConsumer do
  @module __MODULE__

  use GenServer
  use ExRabbitMQ.Consumer, GenServer

  def start_link(state) do
    GenServer.start_link(@module, state)
  end

  def init(state) do
    GenServer.cast(self(), :init)

    {:ok, state}
  end

  def stop(consumer_pid) do
    GenServer.cast(consumer_pid, :stop)
  end

  def handle_cast(
        :init,
        %{
          tester_pid: tester_pid,
          connection_config: connection_config,
          queue_config: queue_config
        } = state
      ) do
    new_state =
      connection_config
      |> xrmq_init(queue_config, state)
      |> xrmq_extract_state()

    send(tester_pid, {:connection_open, XRMQState.get_connection_pid()})

    send(tester_pid, {:consumer_state, new_state})

    {:noreply, new_state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
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
  def xrmq_queue_setup(channel, queue, state) do
    {:ok, state} = super(channel, queue, state)
    {:ok, Map.put(state, :consumer_queue_setup_ok, {:ok, queue})}
  end
end
