defmodule ExRabbitMQ.Connection.Supervisor do
  @moduledoc """
  A supervisor implementing the `DynamicSupervisor` with `:one_for_one` strategy
  to serve as a template for spawning new RabbitMQ connection
  (module `ExRabbitMQ.Connection`) processes.
  """

  @module __MODULE__

  use DynamicSupervisor

  @doc """
  Starts a new Supervisor for managing the RabbitMQ connections.
  """
  def start_link(args) do
    DynamicSupervisor.start_link(@module, args, name: @module)
  end

  @doc """
  Starts a new RabbitMQ connection process with the specified configuration
  and supervises it.
  """
  def start_child(connection_config) do
    child_spec = {ExRabbitMQ.Connection, connection_config}

    DynamicSupervisor.start_child(@module, child_spec)
  end

  @doc false
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
