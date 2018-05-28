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

  alias ExRabbitMQ.Connection.{Config, PubSub, Group, Supervisor}

  use GenServer, restart: :transient

  require Logger

  defstruct [:connection, :connection_pid, :ets_consumers, config: %Config{}, stale?: false]

  @doc """
  Starts a new `ExRabbitMQ.Connection` process and links it with the calling one.
  """
  @spec start_link(connection_config :: Config.t()) :: GenServer.on_start()
  def start_link(%Config{} = connection_config) do
    GenServer.start_link(@name, connection_config)
  end

  @doc """
  Checks whether this process holds a usable connection to RabbitMQ.

  The `connection_pid` is the `GenServer` pid implementing the called `ExRabbitMQ.Connection`.
  """
  @spec get(connection_pid :: pid) :: {:ok, %AMQP.Connection{} | nil} | {:error, term}
  def get(nil) do
    {:error, :nil_connection_pid}
  end

  def get(connection_pid) do
    GenServer.call(connection_pid, :get)
  catch
    :exit, reason -> {:error, reason}
  end

  @doc """
  Tries to subscribe the calling process, via `self/0` to the `ExRabbitMQ.Connection.PubSub` of the `connection_pid`
  process.

  If the `connection_config` configuration does not match the one of the `connection_pid`'s' process, then the
  subscription is not allowed.

  If the `ExRabbitMQ.Connection.PubSub` of the connection process already contains the maximum subscribed processes,
  then the subscription is not allowed so that a new connection process can be created.

  The argument `connection_pid` is the GenServer pid implementing the called `ExRabbitMQ.Connection`.

  The argument `connection_config` is the `ExRabbitMQ.Connection.Config` that the `ExRabbitMQ.Connection` has to be using in order
  to allow the subscription.
  """
  @spec subscribe(connection_pid :: pid, connection_config :: Config.t()) :: boolean
  def subscribe(connection_pid, connection_config) do
    GenServer.call(connection_pid, {:subscribe, self(), connection_config})
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

  The `connection_config` is the `ExRabbitMQ.Connection.Config` that the `ExRabbitMQ.Connection` has to be using in order to allow
  the subscription.
  """
  @spec get_subscribe(connection_config :: Config.t()) :: pid
  def get_subscribe(connection_config) do
    Group.get_members()
    |> Enum.find(&subscribe(&1, connection_config))
    |> case do
      nil ->
        {:ok, pid} = Supervisor.start_child(connection_config)
        subscribe(pid, connection_config)
        pid

      pid ->
        pid
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
  def init(config) do
    Process.flag(:trap_exit, true)

    :ok = Group.join()
    ets_consumers = PubSub.new()

    Process.send(self(), :connect, [])
    schedule_cleanup()

    {:ok, %@name{config: config, ets_consumers: ets_consumers}}
  end

  @doc false
  def handle_call(:get, _from, state) do
    %{connection: connection} = state
    reply = if connection === nil, do: {:error, :nil_connection_pid}, else: {:ok, connection}

    {:reply, reply, state}
  end

  @doc false
  def handle_call(
        {:subscribe, consumer_pid, connection_config},
        _from,
        %{config: config, ets_consumers: ets_consumers} = state
      )
      when config === connection_config do
    result =
      with true <- PubSub.subscribe(ets_consumers, connection_config, consumer_pid) do
        Process.monitor(consumer_pid)
        true
      end

    new_state = %{state | stale?: false}

    {:reply, result, new_state}
  end

  @doc false
  def handle_call({:subscribe, _consumer_pid, _connection_config}, _from, state) do
    new_state = %{state | stale?: false}
    {:reply, false, new_state}
  end

  @doc false
  def handle_cast(:close, state) do
    %{ets_consumers: ets_consumers, connection: connection, connection_pid: connection_pid} =
      state

    if connection === nil do
      {:stop, :normal, state}
    else
      Group.leave(connection_pid)
      Process.unlink(connection_pid)
      AMQP.Connection.close(connection)
      PubSub.publish(ets_consumers, {:xrmq_connection, {:closed, nil}})
      new_state = %{state | connection: nil, connection_pid: nil}

      {:stop, :normal, new_state}
    end
  end

  @doc false
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

  @doc false
  def handle_info({:EXIT, pid, _reason}, %{connection_pid: connection_pid} = state)
      when pid === connection_pid do
    Logger.error("Disconnected from RabbitMQ")

    %{config: config, ets_consumers: ets_consumers} = state

    PubSub.publish(ets_consumers, {:xrmq_connection, {:closed, nil}})
    Process.send_after(self(), :connect, config.reconnect_after)
    new_state = %{state | connection: nil, connection_pid: nil}

    {:noreply, new_state}
  end

  @doc false
  def handle_info({:DOWN, _ref, :process, consumer_pid, _reason}, state) do
    %{ets_consumers: ets_consumers} = state

    PubSub.unsubscribe(ets_consumers, consumer_pid)

    {:noreply, state}
  end

  @doc false
  def handle_info(:cleanup, state) do
    %{ets_consumers: ets_consumers, stale?: stale?} = state

    if stale? do
      {:stop, :normal, state}
    else
      new_state =
        case PubSub.size(ets_consumers) do
          0 -> %{state | stale?: true}
          _ -> state
        end

      schedule_cleanup()

      {:noreply, new_state}
    end
  end

  @doc false
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 5000)
  end
end
