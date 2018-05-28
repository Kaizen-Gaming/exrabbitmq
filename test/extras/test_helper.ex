ExUnit.start()

defmodule TestHelper do
  use ExUnit.Case
  alias ExRabbitMQ.Connection

  def start(:producer, opts) do
    {:ok, pid} = TestProducer.start_link(opts)
    producer(pid, opts)
  end

  def start(:consumer, opts) do
    {:ok, pid} = TestConsumer.start_link(opts)
    consumer(pid, opts)
  end

  def assert_stop(ref) do
    assert_receive({:DOWN, ^ref, :process, _pid, _reason}, 500)
  end

  defp connection(pid, consumer_or_producer) do
    # we monitor the producer/consumer so that we can wait for it to exit
    monitor = Process.monitor(pid)

    # the producer/consumer tells us that the connection has been opened
    assert_receive(
      {:connection_open, connection_pid},
      500,
      "failed to open a connection for the #{consumer_or_producer}"
    )

    # we monitor the producer's/consumer's connection GenServer wrapper so that we can wait for it to exit
    connection_monitor = Process.monitor(connection_pid)

    # is the producer's/consumer's connection truly ready?
    assert({:ok, _connection} = Connection.get(connection_pid))

    [
      pid: pid,
      connection_pid: connection_pid,
      monitor: monitor,
      connection_monitor: connection_monitor
    ]
  end

  defp producer(pid, %{test_message: test_message} = _opts) do
    setup_info = connection(pid, :producer)

    # is the producers's channel properly set up?
    assert_receive(
      {:producer_state, %{producer_channel_setup_ok: true}},
      500,
      "failed to properly setup the producer's channel"
    )

    # the producer tells us that the message has been published
    assert_receive({:publish, :ok}, 500, "failed to publish test message #{test_message}")

    # the consumer tells us that the message that we published is the same we have consumed
    assert_receive(
      {:consume, ^test_message},
      500,
      "failed to receive test message #{test_message}"
    )

    setup_info
  end

  defp consumer(pid, %{queue_config: %{queue: queue}} = _opts) do
    setup_info = connection(pid, :consumer)

    # are the consumer's channel and queue properly set up?
    assert_receive(
      {:consumer_state,
       %{consumer_channel_setup_ok: true, consumer_queue_setup_ok: {:ok, ^queue}}},
      500,
      "failed to properly setup the consumer's channel and/or queue"
    )

    setup_info
  end
end
