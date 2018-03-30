defmodule ExRabbitMQ.Connection.Supervisor do
  @moduledoc """
  A supervisor implementing the `DynamicSupervisor` with `:one_for_one` strategy to serve as a template for spawning
  new RabbitMQ connection (module `ExRabbitMQ.Connection`) processes.
  """

  @module __MODULE__

  alias ExRabbitMQ.Connection
  alias ExRabbitMQ.Connection.Config

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
  @spec start_child(connection_config :: Config.t()) :: Supervisor.on_start_child()
  def start_child(connection_config) do
    child_spec = {Connection, connection_config}

    DynamicSupervisor.start_child(@module, child_spec)
  end

  @doc false
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
