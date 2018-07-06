defmodule ExRabbitMQTest do
  use ExUnit.Case, async: false

  alias ExRabbitMQ.Connection.Pool.Supervisor, as: PoolSupervisor

  @defaults %{
    connection_config: :test_a,
    session_config: :test_basic_session,
    test_message: "ExRabbitMQ test",
    tester_pid: nil,
    error_flag: false
  }

  setup_all do
    # first we start the connection supervisor
    # it holds the template for the GenServer wrapping connections to RabbitMQ
    connection_sup =
      case PoolSupervisor.start_link([]) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    on_exit(fn -> Process.exit(connection_sup, :kill) end)
  end

  @tag :one
  test "producers publish messages and producers consume them, using different connections" do
    connection_config = :test_different_connections

    consumers = create(10, :consumer, %{connection_config: connection_config})
    producers = create(10, :producer, %{connection_config: connection_config})

    consumers |> Map.get(:connection_pids)
    producers |> Map.get(:connection_pids)

    number_of_different_connections = get_unique_connection_size(consumers, producers)

    # all the producer and the consumers  must have used different connections
    assert(number_of_different_connections == 20)

    # we stop everything
    consumers |> Map.get(:pids) |> Enum.each(&TestConsumer.stop(&1))
    producers |> Map.get(:pids) |> Enum.each(&TestProducer.stop(&1))

    # we make sure that everything has stopped as required before we exit
    consumers |> Map.get(:monitors) |> Enum.each(&TestHelper.assert_stop(&1))
    producers |> Map.get(:monitors) |> Enum.each(&TestHelper.assert_stop(&1))

    PoolSupervisor.stop_pools()
  end

  @tag :two
  test "max channels per connection" do
    connection_config = :test_max_channels

    consumers_1 = create(2, :consumer, %{connection_config: connection_config})
    number_of_different_connections = get_unique_connection_size(consumers_1, %{})

    assert(number_of_different_connections == 2)

    producer_1 = create(1, :producer, %{connection_config: connection_config})
    number_of_different_connections = get_unique_connection_size(consumers_1, producer_1)
    assert(number_of_different_connections == 3)

    # no available connection
    consumer_2 = create(1, :consumer, %{connection_config: connection_config, error_flag: true})
    assert(consumer_2 |> Map.get(:connection_pids) == [nil])

    # we stop everything
    consumers_1 |> Map.get(:pids) |> Enum.each(&TestConsumer.stop(&1))
    producer_1 |> Map.get(:pids) |> Enum.each(&TestProducer.stop(&1))
    consumer_2 |> Map.get(:pids) |> Enum.each(&TestConsumer.stop(&1))

    # # we make sure that everything has stopped as required before we exit
    consumers_1 |> Map.get(:monitors) |> Enum.each(&TestHelper.assert_stop(&1))
    producer_1 |> Map.get(:monitors) |> Enum.each(&TestHelper.assert_stop(&1))
    consumer_2 |> Map.get(:monitors) |> Enum.each(&TestHelper.assert_stop(&1))

    PoolSupervisor.stop_pools()
  end

  defp create(number, producer_or_consumer, opts \\ @defaults) do
    opts =
      @defaults
      |> Map.merge(opts)
      |> Map.put(:tester_pid, self())

    1..number
    |> Enum.reduce(%{monitors: [], pids: [], connection_pids: [], connection_monitors: []}, fn _,
                                                                                               acc ->
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

  defp get_unique_connection_size(map1, map2) do
    map1
    |> Map.get(:connection_pids)
    |> Enum.concat(map2 |> Map.get(:connection_pids, []))
    |> Enum.uniq()
    |> length()
  end
end
