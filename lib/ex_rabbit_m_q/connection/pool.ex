defmodule ExRabbitMQ.Connection.Pool do
  @moduledoc false

  alias ExRabbitMQ.Config.Connection, as: ConnectionConfig
  alias ExRabbitMQ.Connection.Pool.Registry, as: RegistryPool

  @spec start({atom, ConnectionConfig.t()}, ConnectionConfig.t()) :: no_return
  def start(hash_key, %ConnectionConfig{pool: pool} = connection_config) do
    RegistryPool.start_link()

    [
      {:name, RegistryPool.via_tuple(hash_key)},
      {:worker_module, ExRabbitMQ.Connection},
      {:size, pool.size},
      {:strategy, pool.strategy},
      {:max_overflow, pool.max_overflow}
    ]
    |> :poolboy.start_link(connection_config)
  end
end
