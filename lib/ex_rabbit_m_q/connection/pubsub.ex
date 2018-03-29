defmodule ExRabbitMQ.Connection.PubSub do
  @moduledoc false

  def new do
    :ets.new(__MODULE__, [:private])
  end

  def subscribe(pubsub, pid) do
    if size(pubsub) >= 65_535 do
      false
    else
      :ets.insert_new(pubsub, {pid})
      true
    end
  end

  def unsubscribe(pubsub, pid) do
    :ets.delete(pubsub, pid)
  end

  def publish(pubsub, message) do
    pubsub
    |> :ets.select([{:_, [], [:"$_"]}])
    |> Enum.split_with(fn {pid} ->
      if Process.alive?(pid) do
        send(pid, message)
      else
        unsubscribe(pubsub, pid)
      end
    end)
  end

  def size(pubsub) do
    :ets.info(pubsub)[:size]
  end
end
