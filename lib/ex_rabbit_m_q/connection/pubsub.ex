defmodule ExRabbitMQ.Connection.PubSub do
  @moduledoc """
  Wrapper module around an [ETS](http://erlang.org/doc/man/ets.html) table for managing
  subscriptions and publishing messages regarding the connection status to the subscribed
  (consumer & producer) processes.

  Note: Because the maximum number of channels per connection is configurable (default: 65535),
  the subscription will be declined when that limit is reached.
  """

  alias ExRabbitMQ.Config.Connection, as: ConnectionConfig

  @type tid :: :ets.tid() | atom

  @doc """
  Creates a new private [ETS](http://erlang.org/doc/man/ets.html) table for keeping
  the processes' subscriptions.
  """
  @spec new(atom) :: tid
  def new(name \\ __MODULE__) do
    :ets.new(name, [:private])
  end

  @doc """
  Insert the process `pid` in the table `tid`, so that it receives messages send
  using the `ExRabbitMQ.Connection.PubSub.publish/2`.
  """
  @spec subscribe(tid, ConnectionConfig.t(), pid) :: boolean
  def subscribe(tid, _connection_config, pid) do
    :ets.insert_new(tid, {pid})
  end

  @doc """
  Remove the process `pid` from the table `tid`, thus it stop receiving any messages.
  """
  @spec unsubscribe(tid, pid) :: true
  def unsubscribe(tid, pid) do
    :ets.delete(tid, pid)
  end

  @doc """
  Send the `message` to all processes that have subscribed previously with `ExRabbitMQ.Connection.PubSub.subscribe/2`
  in the table `tid`. If the process is not alive, it will be automatically get unsubscribed.
  """
  @spec publish(tid, term) :: :ok
  def publish(tid, message) do
    tid
    |> :ets.select([{:_, [], [:"$_"]}])
    |> Enum.split_with(fn {pid} ->
      if Process.alive?(pid) do
        send(pid, message)
      else
        unsubscribe(tid, pid)
      end
    end)

    :ok
  end

  @doc """
  Returns the current size of subscribed processes in the table `tid`.
  """
  @spec size(tid) :: non_neg_integer
  def size(tid) do
    :ets.info(tid)[:size]
  end
end
