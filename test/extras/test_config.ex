defmodule TestConfig do
  alias ExRabbitMQ.Connection.Config, as: ConnectionConfig
  alias ExRabbitMQ.Consumer.QueueConfig

  # configuration for a default local RabbitMQ installation
  def connection_config do
    %ConnectionConfig{
      username: "guest",
      password: "guest",
      host: "127.0.0.1",
      reconnect_after: 500
    }
  end

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
