defmodule TestProducer do
  @module __MODULE__

  use GenServer
  use ExRabbitMQ.Producer

  def publish(producer_pid, test_message) do
    GenServer.cast(producer_pid, {:publish, test_message})
  end

  def start_link(state) do
    GenServer.start_link(@module, state)
  end

  def init(state) do
    GenServer.cast(self(), :init)

    {:ok, state}
  end

  def stop(producer_pid) do
    GenServer.cast(producer_pid, :stop)
  end

  def handle_cast(
        :init,
        %{
          tester_pid: tester_pid,
          connection_config: connection_config,
          test_message: test_message
        } = state
      ) do
    {message, new_state} =
      connection_config
      |> xrmq_init(state)
      |> case do
        {:ok, _} = result ->
          GenServer.cast(self(), {:publish, test_message})
          {{:connection_open, XRMQState.get_connection_pid()}, xrmq_extract_state(result)}

        {:error, reason, _} ->
          {{:error, reason}, state}
      end

    send(tester_pid, message)

    send(tester_pid, {:producer_state, new_state})

    {:noreply, new_state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_cast(
        {:publish, test_message},
        %{tester_pid: tester_pid, queue_config: queue_config} = state
      ) do
    publish_result = xrmq_basic_publish(test_message, "", queue_config.queue)
    send(tester_pid, {:publish, publish_result})

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  # optional override when there is a need to do setup the channel right after the connection has been established.
  def xrmq_channel_setup(channel, state) do
    {:ok, state} = super(channel, state)
    {:ok, Map.put(state, :producer_channel_setup_ok, true)}
  end
end
