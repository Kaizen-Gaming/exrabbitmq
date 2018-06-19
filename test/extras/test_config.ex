defmodule TestConfig do
  alias ExRabbitMQ.Consumer.QueueConfig

  def queue_config(test_queue \\ "xrmq_test", test_exchange \\ "xrmq_test_exchange") do
    # configuration for a test queue where we will publish to/consumer from
    %QueueConfig{
      queue: test_queue,
      queue_opts: [durable: false, auto_delete: true],
      exchange: test_exchange,
      exchange_opts: [type: :direct, durable: false, auto_delete: true],
      bind_opts: [],
      qos_opts: [prefetch_count: 1],
      consume_opts: [no_ack: true]
    }
  end
end
