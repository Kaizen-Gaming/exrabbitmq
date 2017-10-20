defmodule ExRabbitMQ.Connection.Config do
  @moduledoc """
  A stucture holding the necessary information about a connection to a RabbitMQ node.

  ```elixir
  defstruct [:username, :password, :host, :port, :vhost, :heartbeat, :reconnect_after, :qos_opts]
  ```

  #### Connection configuration example:

  ```elixir
  # :connection is this connection's configuration name
  config :exrabbitmq, :my_connection_config,

    # username for connecting to rabbitmq (distinct per connection configuration block)
    username: "username",

    # password for connecting to rabbitmq(distinct per connection configuration block)
    password: "password",

    # host where RabbitMQ is running
    host: "rabbitmq.host.my",

    # port where RabbitMQ is listening (optional, default: 5672)
    port: 5672,

    # the virtual host to connect to (optional, default: /)
    vhost: "/",

    # the connection's heartbeat RabbitMQ in milliseconds (optional, default: 1000)
    heartbeat: 1000,

    # the delay after which a connection wil be re-attempted after having been dropped (optional, default: 2000)
    reconnect_after: 2000,

    # the options to use for specifying QoS properties on a channel (optional, default: nil)
    qos_opts: nil
  ```
  """

  defstruct [:username, :password, :host, :port, :vhost, :heartbeat, :reconnect_after, :qos_opts]
end
