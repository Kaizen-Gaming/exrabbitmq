defmodule ExRabbitMQ.Consumer.QueueConfig do
  @moduledoc """
  A stucture holding the necessary information about a queue that is to be consumed.

  ```elixir
  defstruct [:queue, :queue_opts, :consume_opts, :bind_opts]
  ```
  """

  defstruct [:queue, :queue_opts, :consume_opts, :bind_opts]
end
