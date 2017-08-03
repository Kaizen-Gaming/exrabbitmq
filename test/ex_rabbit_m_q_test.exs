defmodule ExRabbitMQTest do
  use ExUnit.Case

  alias ExRabbitMQ.Connection
  alias ExRabbitMQ.ConnectionConfig
  alias ExRabbitMQ.Consumer.QueueConfig

  test "publishing a message and then consuming it" do
    # first we start the connection supervisor
    # it holds the template for the GenServer wrapping connections to RabbitMQ
    ExRabbitMQ.ConnectionSupervisor.start_link()

    # configuration for a default local RabbitMQ installation
    connection_config = %ConnectionConfig{username: "guest", password: "guest", host: "127.0.0.1", reconnect_after: 500}
    test_queue = "xrmq_test"

    # configuration for a test queue where we will publish to/consumer from
    queue_config = %QueueConfig{queue: test_queue, queue_opts: [durable: false, auto_delete: true], consume_opts: [no_ack: true]}

    # the test message to be published and then consumed
    test_message = "ExRabbitMQ test"

    # we start the consumer so that the queue will be declared
    {:ok, consumer} = ExRabbitMQConsumerTest.start_link(self(), connection_config, queue_config)

    # we monitor the consumer so that we can wait for it to exit
    consumer_monitor = Process.monitor(consumer)

    # the consumer tells us that the connection has been opened
    assert_receive({:consumer_connection_open, consumer_connection_pid},
      500, "failed to open a connection for the consumer")

    # we monitor the consumer's connection GenServer wrapper so that we can wait for it to exit
    consumer_connection_monitor = Process.monitor(consumer_connection_pid)

    # is the consumer's connection truly ready?
    assert({:ok, _consumer_connection} = Connection.get(consumer_connection_pid))

    # are the consumer's channel and queue properly set up?
    assert_receive({:consumer_state, %{consumer_channel_setup_ok: true, consumer_queue_setup_ok: {:ok, ^test_queue}}},
      500, "failed to properly setup the consumer's channel and/or queue")

    # we start the producer to publish our test message
    {:ok, producer} = ExRabbitMQProducerTest.start_link(self(), connection_config, test_queue, test_message)

    # we monitor the producer so that we can wait for it to exit
    producer_monitor = Process.monitor(producer)

    # the producer tells us that the connection has been opened
    assert_receive({:producer_connection_open, producer_connection_pid},
      500, "failed to open a connection for the producer")

    # we monitor the producer's connection GenServer wrapper so that we can wait for it to exit
    producer_connection_monitor = Process.monitor(producer_connection_pid)

    # is the producer's connection truly ready?
    assert({:ok, _producer_connection} = Connection.get(consumer_connection_pid))

    # is the producers's channel properly set up?
    assert_receive({:producer_state, %{producer_channel_setup_ok: true}},
      500, "failed to properly setup the producer's channel")

    # the producer must have reused the same connection as the consumer
    # when this connection is used for the maximum of 65535 channels,
    # a new connection will be used for the next consumer/producer that needs one
    assert consumer_connection_pid === producer_connection_pid

    # the producer tells us that the message has been published
    assert_receive({:publish, :ok}, 500, "failed to publish test message #{test_message}")



    # the consumer tells us that the message that we published is the same we have consumed
    assert_receive({:consume, ^test_message}, 500, "failed to receive test message #{test_message}")

    # we stop everything
    ExRabbitMQConsumerTest.stop(consumer)
    ExRabbitMQProducerTest.stop(producer)
    Connection.close(consumer_connection_pid)
    Connection.close(producer_connection_pid)

    # we make sure that everything has stopped as required before we exit
    assert_receive({:DOWN, ^consumer_monitor, :process, _pid, _reason}, 500)
    assert_receive({:DOWN, ^producer_monitor, :process, _pid, _reason}, 500)
    assert_receive({:DOWN, ^consumer_connection_monitor, :process, _pid, _reason}, 500)
    assert_receive({:DOWN, ^producer_connection_monitor, :process, _pid, _reason}, 500)
  end
end

defmodule ExRabbitMQProducerTest do
  @moduledoc false

  use GenServer
  use ExRabbitMQ.Producer

  def start_link(tester_pid, connection_config, test_queue, test_message) do
    GenServer.start_link(__MODULE__, %{
      tester_pid: tester_pid,
      connection_config: connection_config,
      test_queue: test_queue,
      test_message: test_message})
  end

  def init(state) do
    GenServer.cast(self(), :init)

    {:ok, state}
  end

  def stop(producer_pid) do
    GenServer.cast(producer_pid, :stop)
  end

  def handle_cast(:init, %{
    tester_pid: tester_pid,
    connection_config: connection_config,
    test_queue: test_queue,
    test_message: test_message} = state) do
    new_state =
      xrmq_init(connection_config, state)
      |> xrmq_extract_new_state()

    send(tester_pid, {:producer_connection_open, xrmq_get_connection_pid()})

    send(tester_pid, {:producer_state, new_state})

    publish_result = xrmq_basic_publish(test_message, "", test_queue)

    send(tester_pid, {:publish, publish_result})

    {:noreply, new_state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def xrmq_channel_setup(state) do
    {:ok, Map.put(state, :producer_channel_setup_ok, true)}
  end
end

defmodule ExRabbitMQConsumerTest do
  @moduledoc false

  use GenServer
  use ExRabbitMQ.Consumer, GenServer

  def start_link(tester_pid, connection_config, queue_config) do
    GenServer.start_link(__MODULE__, %{tester_pid: tester_pid, connection_config: connection_config, queue_config: queue_config})
  end

  def init(state) do
    GenServer.cast(self(), :init)

    {:ok, state}
  end

  def stop(consumer_pid) do
    GenServer.cast(consumer_pid, :stop)
  end

  def handle_cast(:init, %{tester_pid: tester_pid, connection_config: connection_config, queue_config: queue_config} = state) do
    new_state =
      xrmq_init(connection_config, queue_config, state)
      |> xrmq_extract_new_state()

    send(tester_pid, {:consumer_connection_open, xrmq_get_connection_pid()})

    send(tester_pid, {:consumer_state, new_state})

    {:noreply, new_state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def xrmq_basic_deliver(payload, _meta, %{tester_pid: tester_pid} = state) do
    send(tester_pid, {:consume, payload})

    {:noreply, state}
  end

  def xrmq_channel_setup(state) do
    {:ok, Map.put(state, :consumer_channel_setup_ok, true)}
  end

  def xrmq_queue_setup(queue, state) do
    {:ok, Map.put(state, :consumer_queue_setup_ok, {:ok, queue})}
  end
end
