defmodule ExRabbitMQ.Connection.Pool.Supervisor do
  @moduledoc """
  A supervisor implementing the `DynamicSupervisor` with `:one_for_one` strategy to serve as a template for spawning
  new RabbitMQ connection (module `ExRabbitMQ.Connection`) processes.
  """

  @module __MODULE__

  alias ExRabbitMQ.Connection.{Config, Pool}
  alias ExRabbitMQ.Connection.Pool.Registry, as: RegistryPool
  use DynamicSupervisor

  @doc """
  Starts a new process for supervising `ExRabbitMQ.Connection` processes.
  """
  @spec start_link(args :: term) :: Supervisor.on_start()
  def start_link(args) do
    DynamicSupervisor.start_link(@module, args, name: @module)
  end

  @doc """
  Starts a new `ExRabbitMQ.Connection` process with the specified configuration and supervises it.
  """
  @spec start_child(app :: atom(), connection_config :: Config.t() | atom()) ::
          Supervisor.on_start_child()
  def start_child(app \\ :exrabbitmq, connection_key) do
    {hash_key, connection_config} =
      app
      |> Config.get(connection_key)
      |> Config.to_hash_key()

    child_spec = %{
      id: hash_key,
      start: {Pool, :start, [hash_key, connection_config]}
    }

    DynamicSupervisor.start_child(@module, child_spec)
  end

  @doc false
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def stop_pools() do
    RegistryPool.unlink_stop()

    @module
    |> Process.whereis()
    |> DynamicSupervisor.which_children()
    |> Enum.reduce([], fn x, acc -> [elem(x, 1) | acc] end)
    |> Enum.each(fn x ->
      Process.unlink(x)
      :poolboy.stop(x)
    end)
  end
end
