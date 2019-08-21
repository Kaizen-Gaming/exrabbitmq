defmodule ExRabbitMQ.Impl.ConsumerGenServer do
  @moduledoc false

  require Logger

  use GenServer
  use ExRabbitMQ.Consumer

  @impl true
  def init(_), do: {:ok, nil}

  def xrmq_basic_deliver(payload, _metadata, state) do
    Logger.debug("xrmq_basic_deliver received: " <> payload)

    {:noreply, state}
  end
end

defmodule ExRabbitMQ.Impl.ProducerGenServer do
  @moduledoc false

  use GenServer
  use ExRabbitMQ.Producer

  @impl true
  def init(_), do: {:ok, nil}
end
