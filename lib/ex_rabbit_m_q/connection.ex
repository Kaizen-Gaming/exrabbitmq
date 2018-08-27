defmodule ExRabbitMQ.Connection do
  @moduledoc """
  A `GenServer` implementing a long running connection to a RabbitMQ server.

  Consumers and producers share connections and when a connection reaches the default limit of **65535** channels
  or the maximum channels per connection that has been set in the configuration, a new connection is established.

  **Warning:** To correctly monitor the open channels, users must not open channels manually (e.g., in the provided hooks).

  Internally, a connection `GenServer` uses [`:pg2`](http://erlang.org/doc/man/pg2.html) and
  [`:ets`](http://erlang.org/doc/man/ets.html) to handle local subscriptions of consumers and producers.
  Check `ExRabbitMQ.Connection.Group` and `ExRabbitMQ.Connection.PubSub` for more information.
  """

  @name __MODULE__

  alias ExRabbitMQ.Config.Connection, as: ConnectionConfig
  alias ExRabbitMQ.Connection.Pool.Registry, as: RegistryPool
  alias ExRabbitMQ.Connection.Pool.Supervisor, as: PoolSupervisor
  alias ExRabbitMQ.Connection.PubSub

  use GenServer, restart: :transient

  require Logger

  defstruct [
    :connection,
    :connection_pid,
    :ets_consumers,
    config: %ConnectionConfig{},
    stale?: false
  ]

  @doc """
  Starts a new `ExRabbitMQ.Connection` process and links it with the calling one.
  """
  @spec start_link(connection_config :: ConnectionConfig.t()) :: GenServer.on_start()
  def start_link(%ConnectionConfig{} = connection_config) do
    GenServer.start_link(@name, connection_config)
  end

  @doc """
  Checks whether this process holds a usable connection to RabbitMQ.

  The `connection_pid` is the `GenServer` pid implementing the called `ExRabbitMQ.Connection`.
  """
  @spec get(connection_pid :: pid) :: {:ok, AMQP.Connection.t() | nil} | {:error, term}
  def get(nil) do
    {:error, :nil_connection_pid}
  end

  def get(connection_pid) do
    GenServer.call(connection_pid, :get)
  catch
    :exit, reason -> {:error, reason}
  end

  @doc """
  Finds a `ExRabbitMQ.Connection` process in the `ExRabbitMQ.Connection.Group` that has the exact same `connection_config`
  configuration.

  If found, it subscribes the calling process via `self/0` to its `ExRabbitMQ.Connection.PubSub` for events regarding
  the connection status and then returns its process ID.

  If the `ExRabbitMQ.Connection.PubSub` of the connection process already contains the maximum subscribed processes,
  then the subscription is not allowed so that a new connection process can be created.
  In this case, a new`ExRabbitMQ.Connection` will be started and returned.

  If not found then a new `ExRabbitMQ.Connection` will be started and returned.

  The `connection_config` is the `ExRabbitMQ.Config.Connection` that the `ExRabbitMQ.Connection` has to be using in order to allow
  the subscription.
  """
  @spec get_subscribe(connection_config :: ConnectionConfig.t()) :: {:ok, pid} | {:error, atom}
  def get_subscribe(connection_config) do
    case PoolSupervisor.start_child(connection_config) do
      {:error, {:already_started, pool_pid}} -> subscribe(pool_pid, connection_config)
      {:ok, pool_pid} -> subscribe(pool_pid, connection_config)
    end
  end

  @doc """
  Gracefully closes the RabbitMQ connection and terminates its GenServer handler identified by `connection_pid`.
  """
  @spec close(connection_pid :: pid) :: :ok
  def close(connection_pid) do
    GenServer.cast(connection_pid, :close)
  end

  @doc false
  @spec get_weight(connection_pid :: pid) :: non_neg_integer | :full
  def get_weight(connection_pid) do
    GenServer.call(connection_pid, :get_weight)
  end

  @impl true
  def init(%{cleanup_after: cleanup_after} = config) do
    Process.flag(:trap_exit, true)
    ets_consumers = PubSub.new()

    Process.send(self(), :connect, [])
    schedule_cleanup(cleanup_after)

    {:ok, %@name{config: config, ets_consumers: ets_consumers}}
  end

  @impl true
  def handle_call(:get, _from, state) do
    %{connection: connection} = state

    reply = if connection === nil, do: {:error, :nil_connection_pid}, else: {:ok, connection}

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:subscribe, consumer_pid, connection_config}, _from, state) do
    %{ets_consumers: ets_consumers} = state

    PubSub.subscribe(ets_consumers, connection_config, consumer_pid)
    Process.monitor(consumer_pid)

    {:reply, true, %{state | stale?: false}}
  end

  @impl true
  def handle_call(:get_weight, _from, state) do
    %{ets_consumers: ets_consumers, config: %{max_channels: max_channels}} = state

    reply =
      case PubSub.size(ets_consumers) do
        connection_channels when connection_channels < max_channels -> connection_channels
        _ -> :full
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_cast(:close, state) do
    %{ets_consumers: ets_consumers, connection: connection, connection_pid: connection_pid} =
      state

    if connection === nil do
      {:stop, :normal, state}
    else
      cleanup_connection(connection_pid, connection)
      PubSub.publish(ets_consumers, {:xrmq_connection, {:closed, nil}})
      new_state = %{state | connection: nil, connection_pid: nil}

      {:stop, :normal, new_state}
    end
  end

  @impl true
  def handle_info(:connect, state) do
    Logger.debug("Connecting to RabbitMQ")

    %{config: config, ets_consumers: ets_consumers} = state

    opts = [
      username: config.username,
      password: config.password,
      host: config.host,
      port: config.port,
      virtual_host: config.vhost,
      heartbeat: config.heartbeat
    ]

    case AMQP.Connection.open(opts) do
      {:ok, %AMQP.Connection{pid: connection_pid} = connection} ->
        Logger.debug("Connected to RabbitMQ")

        Process.link(connection_pid)
        PubSub.publish(ets_consumers, {:xrmq_connection, {:open, connection}})
        new_state = %{state | connection: connection, connection_pid: connection_pid}

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to connect to RabbitMQ: #{inspect(reason)}")

        Process.send_after(self(), :connect, config.reconnect_after)
        new_state = %{state | connection: nil, connection_pid: nil}

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, %{connection_pid: connection_pid} = state)
      when pid === connection_pid do
    Logger.error("Disconnected from RabbitMQ")

    %{config: config, ets_consumers: ets_consumers} = state

    PubSub.publish(ets_consumers, {:xrmq_connection, {:closed, nil}})
    Process.send_after(self(), :connect, config.reconnect_after)
    new_state = %{state | connection: nil, connection_pid: nil}

    {:noreply, new_state}
  end

  def handle_info({:DOWN, _ref, :process, consumer_pid, _reason}, state) do
    %{ets_consumers: ets_consumers} = state

    PubSub.unsubscribe(ets_consumers, consumer_pid)

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, config: state) do
    %{cleanup_after: cleanup_after} = state

    %{
      ets_consumers: ets_consumers,
      connection: connection,
      connection_pid: connection_pid,
      stale?: stale?
    } = state

    if stale? do
      cleanup_connection(connection_pid, connection)
      {:stop, :normal, state}
    else
      new_state =
        case PubSub.size(ets_consumers) do
          0 -> %{state | stale?: true}
          _ -> state
        end

      schedule_cleanup(cleanup_after)

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp subscribe(pool_pid, connection_config) do
    case :poolboy.checkout(pool_pid) do
      status when status in [:full, :overweighted] ->
        {:error, :no_available_connection}

      connection_pid ->
        GenServer.call(connection_pid, {:subscribe, self(), connection_config})
        :poolboy.checkin(pool_pid, connection_pid)
        {:ok, connection_pid}
    end
  end

  defp schedule_cleanup(cleanup_after) do
    Process.send_after(self(), :cleanup, cleanup_after)
  end

  defp cleanup_connection(connection_pid, connection) do
    RegistryPool.unregister(connection_pid)
    Process.unlink(connection_pid)
    AMQP.Connection.close(connection)
  end
end
