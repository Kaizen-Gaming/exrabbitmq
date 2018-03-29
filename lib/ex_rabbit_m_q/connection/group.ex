defmodule ExRabbitMQ.Connection.Group do
  @moduledoc """
  Wrapper module around [:pg2](http://erlang.org/doc/man/pg2.html) for keeping the RabbitMQ connections.
  """

  @name __MODULE__

  @spec join(process :: pid | nil) :: :ok | any
  def join(process \\ nil) do
    with :ok <- :pg2.create(@name),
         :ok <- :pg2.join(@name, process || self()) do
      :ok
    end
  end

  @spec get_members() :: [pid]
  def get_members() do
    name = @name

    case :pg2.get_local_members(name) do
      [] -> []
      [_pid | _rest_pids] = pids -> pids
      {:error, {:no_such_group, ^name}} -> []
    end
  end
end
