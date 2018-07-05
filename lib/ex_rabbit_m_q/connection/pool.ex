defmodule ExRabbitMQ.Connection.Pool do
  alias ExRabbitMQ.Connection.Config
  alias ExRabbitMQ.Connection.Pool.Registry, as: RegistryPool

  def start(hash_key, %Config{pool: pool} = connection_config) do
    RegistryPool.start_link()

    poolboy_config = [
      name: RegistryPool.via_tuple(hash_key),
      worker_module: ExRabbitMQ.Connection,
      size: pool.size,
      strategy: pool.strategy,
      max_overflow: pool.max_overflow
    ]

    :poolboy.start_link(poolboy_config, connection_config)
  end
end
