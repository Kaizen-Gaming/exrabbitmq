defmodule ExRabbitMQ.Impl.ConsumerGenServer do
  @moduledoc false

  use GenServer
  use ExRabbitMQ.Consumer

  @impl true
  def init(_), do: {:ok, nil}

  def xrmq_basic_deliver(_payload, _metadata, state), do: {:noreply, state}
end

defmodule ExRabbitMQ.Impl.ProducerGenServer do
  @moduledoc false

  use GenServer
  use ExRabbitMQ.Producer

  @impl true
  def init(_), do: {:ok, nil}
end
