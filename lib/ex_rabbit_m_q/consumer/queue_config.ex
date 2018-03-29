defmodule ExRabbitMQ.Consumer.QueueConfig do
  @moduledoc """
  A stucture holding the necessary information about a queue that is to be consumed.

  ```elixir
  defstruct [:queue, :queue_opts, :consume_opts, :exchange, :exchange_opts, :bind_opts]
  ```

  #### Queue configuration example:

  ```elixir
  # :queue is this queue's configuration name
  config :exrabbitmq, :my_queue_config,

    # name of the queue from which we wish to consume (optional, default: "")
    queue: "my_queue",

    # properties set on the queue when it is declared (optional, default: [])
    queue_opts: [
      durable: true
    ],

    # the exchange name to declare and bind (optional, default: nil)
    exchange: "my_exchange",

    # the options to use when one wants to declare the exchange (optional, default: [])
    exchange_opts: [

      # the exchange type to declare (optional, default: :direct)
      # this is an atom that can have one of the following values:
      # :direct, :fanout, :topic or :headers
      type: :fanout,

      # other exchange declare options as documented in the Options paragraph of
      # https://hexdocs.pm/amqp/AMQP.Exchange.html#declare/4, eg.:
      durable: true,
      auto_delete: true,
      passive: false,
      internal: false
    ]

    # the options to use when binding the queue to the exchange (optional, default: [])
    bind_opts: [
      routing_key: "my_routing_key",
      nowait: false,
      arguments: []
    ],

    # the options to use for specifying QoS properties on a channel (optional, default: [])
    qos_opts: [
      prefect_size: 1,
      prefetch_count: 1,
      global: true
    ],

    # properties set on the call to consume from the queue (optional, default: [])
    consume_opts: [
      no_ack: false
    ]
  ```
  """

  @name __MODULE__

  @type t :: %__MODULE__{}

  defstruct [:queue, :queue_opts, :exchange, :exchange_opts, :bind_opts, :qos_opts, :consume_opts]

  @spec from_env(key :: atom | module) :: t()
  def from_env(key) do
    from_env(:ex_rabbitmq, key)
  end

  @spec from_env(app :: atom, key :: atom | module) :: t()
  def from_env(app, key) do
    config = Application.get_env(app, key, [])

    %@name{
      queue: config[:queue],
      queue_opts: config[:queue_opts],
      consume_opts: config[:consume_opts],
      exchange: config[:exchange],
      exchange_opts: config[:exchange_opts],
      bind_opts: config[:bind_opts],
      qos_opts: config[:qos_opts]
    }
  end

  @spec from_env(config :: t()) :: t()
  def merge_defaults(%@name{} = config) do
    %@name{
      queue: config.queue || "",
      queue_opts: config.queue_opts || [],
      consume_opts: config.consume_opts || [],
      exchange: config.exchange || nil,
      exchange_opts: config.exchange_opts || [],
      bind_opts: config.bind_opts || [],
      qos_opts: config.qos_opts || []
    }
  end
end
