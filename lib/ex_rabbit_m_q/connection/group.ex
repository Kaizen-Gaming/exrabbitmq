defmodule ExRabbitMQ.Connection.Group do
  @moduledoc """
  Wrapper module around [:pg2](http://erlang.org/doc/man/pg2.html) for holding a process group of RabbitMQ connections.
  """

  @name __MODULE__

  @doc """
  Creates a new process group if not exists and joins the process `pid` to that group.
  """
  @spec join(pid :: pid | nil) :: :ok | {:error, {:no_such_group, any}}
  def join(pid \\ nil) do
    with :ok <- :pg2.create(@name),
         :ok <- :pg2.join(@name, pid || self()) do
      :ok
    end
  end

  @doc """
  Returns all connection processes running on the local node in the group.
  """
  @spec get_members() :: [pid]
  def get_members() do
    name = @name

    case :pg2.get_local_members(name) do
      {:error, {:no_such_group, ^name}} -> []
      pids -> pids
    end
  end
end
