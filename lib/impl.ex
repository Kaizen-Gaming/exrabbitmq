defmodule ExRabbitMQ.Impl.ConsumerGenServer do
  @moduledoc false

  use ExRabbitMQ.Consumer, GenServer

  def init(args), do: {:ok, args}

  def xrmq_basic_deliver(_payload, _metadata, state), do: {:noreply, state}
end

defmodule ExRabbitMQ.Impl.ConsumerGenStage do
  @moduledoc false

  use ExRabbitMQ.Consumer, GenStage

  def xrmq_basic_deliver(_payload, _metadata, state), do: {:noreply, state}
end

defmodule ExRabbitMQ.Impl.ProducerGenServer do
  @moduledoc false

  use ExRabbitMQ.Producer, GenServer

  def init(args), do: {:ok, args}
end
