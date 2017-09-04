defmodule ExRabbitMQ.Consumer.QueueConfig do
  @moduledoc """
  A stucture holding the necessary information about a queue that is to be consumed.

  ```elixir
  defstruct [:queue, :queue_opts, :consume_opts, :bind_opts]
  ```

  #### Queue configuration example:

  ```elixir
  # :queue is this queue's configuration name
  config :exrabbitmq, :my_queue_config,

    # name of the queue from which we wish to consume (optional, default: "")
    queue: "my_queue",

    # properties set on the queue when it is declared (optional, default: [])
    queue_opts: [durable: true],

    # properties set on the call to consume from the queue (optional, default: [])
    consume_opts: [no_ack: false],

    # the options to use when one wants to do a non default binding to an exchange (optional, default: nil)
    bind_opts: [

      # the exchange to bind to (required when bind_opts has been provided)
      exchange: "my_exchange",

      # extra options to pass to the RabbitMQ call (optional, default: [])
      extra_opts: [
        "routing_key": "my_routing_key"
      ]
    ]
  ```
  """

  defstruct [:queue, :queue_opts, :consume_opts, :bind_opts]
end
