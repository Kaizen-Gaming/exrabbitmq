defmodule ExRabbitMQ.Connection.Pool.Registry do
  @moduledoc false

  @name ExRabbitMQ.RegistryPool

  def start_link do
    Registry.start_link(keys: :unique, name: @name)
  end

  def via_tuple(connection_key) do
    {:via, Registry, {@name, connection_key}}
  end

  def lookup(connection_key) do
    case Registry.lookup(@name, connection_key) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, connection_key}
    end
  end

  def unregister(connection_key) do
    Registry.unregister(@name, connection_key)
  end

  def unlink_stop() do
    @name
    |> Process.whereis()
    |> case do
      pid when is_pid(pid) ->
        Process.unlink(pid)
        Process.exit(pid, :normal)

      _ ->
        nil
    end
  end
end
