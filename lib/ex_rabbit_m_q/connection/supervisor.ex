defmodule ExRabbitMQ.Connection.Supervisor do
  @moduledoc """
  A supervisor using the `:simple_one_for_one` strategy to serve as a template
  for spawning new RabbitMQ connection (module `ExRabbitMQ.Connection`) processes.
  """
  @module __MODULE__

  use Supervisor, start: {@module, :start_link, []}

  @doc """
  Starts a new Supervisor for managing the RabbitMQ connections.
  """
  def start_link() do
    Supervisor.start_link(@module, :ok, name: @module)
  end

  def init(:ok) do
    children = [
      Supervisor.child_spec(
        ExRabbitMQ.Connection,
        start: {ExRabbitMQ.Connection, :start_link, []},
        restart: :transient)
    ]
    options = [strategy: :simple_one_for_one]
    Supervisor.init(children, options)
  end

  @doc """
  Starts a new RabbitMQ connection process with the specified configuration, 
  and supervises it.
  """
  def start_child(connection_config \\ nil) do
    args =
      if connection_config === nil do
        []
      else
        [connection_config]
      end

    Supervisor.start_child(@module, args)
  end
end
