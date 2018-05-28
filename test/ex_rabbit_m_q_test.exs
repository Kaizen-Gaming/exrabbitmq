defmodule ExRabbitMQTest do
  use ExUnit.Case, async: false

  alias ExRabbitMQ.Connection.Config, as: ConnectionConfig
  alias ExRabbitMQ.Connection
  alias ExRabbitMQ.Connection.Group

  @defaults %{
    connection_config: TestConfig.connection_config(),
    queue_config: TestConfig.queue_config(),
    test_message: "ExRabbitMQ test",
    tester_pid: nil
  }

  setup_all do

    # first we start the connection supervisor
    # it holds the template for the GenServer wrapping connections to RabbitMQ
    connection_sup =
      case ExRabbitMQ.Connection.Supervisor.start_link([]) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    on_exit(fn -> Process.exit(connection_sup, :kill) end)
  end

  test "publishing a message and then consuming it with a re-usable connection" do
    consumers = create(10, :consumer)
    producers = create(10, :producer)

    [consumers_connection_pid] = consumers |> Map.get(:connection_pids) |> Enum.uniq()
    [producers_connection_pid] = producers |> Map.get(:connection_pids) |> Enum.uniq()

    # all the producer and the consumers  must have reused the same connection
    # when this connection is used for the maximum of channels,
    # a new connection will be used for the next consumer/producer that needs one
    assert consumers_connection_pid === producers_connection_pid

    # we stop everything
    consumers |> Map.get(:pids) |> Enum.each(&TestConsumer.stop(&1))
    producers |> Map.get(:pids) |> Enum.each(&TestProducer.stop(&1))
    Group.get_members() |> Enum.each(&Connection.close(&1))

    # we make sure that everything has stopped as required before we exit
    consumers |> Map.get(:monitors) |> Enum.each(&TestHelper.assert_stop(&1))
    consumers |> Map.get(:connection_monitors) |> Enum.each(&TestHelper.assert_stop(&1))
    producers |> Map.get(:monitors) |> Enum.each(&TestHelper.assert_stop(&1))
    producers |> Map.get(:connection_monitors) |> Enum.each(&TestHelper.assert_stop(&1))
  end

  test "max channels per connection" do
    connection_config = %ConnectionConfig{TestConfig.connection_config() | max_channels: 1}

    %{
      monitors: [consumer_monitor],
      pids: [consumer],
      connection_pids: [consumer_connection_pid],
      connection_monitors: [consumer_connection_monitor]
    } = create(1, :consumer, %{connection_config: connection_config})

    %{
      monitors: [producer_monitor],
      pids: [producer],
      connection_pids: [producer_connection_pid],
      connection_monitors: [producer_connection_monitor]
    } = create(1, :producer, %{connection_config: connection_config})

    assert(consumer_connection_pid !== producer_connection_pid)

    # we stop everything
    TestConsumer.stop(consumer)
    TestProducer.stop(producer)
    Connection.close(consumer_connection_pid)
    Connection.close(producer_connection_pid)

    # we make sure that everything has stopped as required before we exit
    TestHelper.assert_stop(consumer_monitor)
    TestHelper.assert_stop(consumer_connection_monitor)
    TestHelper.assert_stop(producer_monitor)
    TestHelper.assert_stop(producer_connection_monitor)
  end

  defp create(number, producer_or_consumer, opts \\ @defaults) do

    opts =
      @defaults
      |> Map.merge(opts)
      |> Map.put(:tester_pid, self())

    1..number
    |> Enum.reduce(%{monitors: [], pids: [], connection_pids: [], connection_monitors: []}, fn _, acc ->
      [
        pid: pid,
        connection_pid: connection_pid,
        monitor: monitor,
        connection_monitor: connection_monitor
      ] = TestHelper.start(producer_or_consumer, opts)

      acc
      |> Map.update!(:pids, &[pid | &1])
      |> Map.update!(:connection_pids, &[connection_pid | &1])
      |> Map.update!(:monitors, &[monitor | &1])
      |> Map.update!(:connection_monitors, &[connection_monitor | &1])
    end)
  end
end
