defmodule ExRabbitMQ do
  @moduledoc """
  A project providing the following abstractions:

  1. Connection lifecycle handling
  2. Channel lifecycle handling
  3. A consumer behaviour for consuming from a RabbitMQ queue
  4. A producer behaviour for publishing messages to a RabbitMQ queue

  The goal of the project is make it unnecessary for the programmer to directly handle connections and channels.

  As such, hooks are provided to enable the programmer to handle message delivery, cancellation, acknowlegement, rejection
  as well as publishing.
  """
end
