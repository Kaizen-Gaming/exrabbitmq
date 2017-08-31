defmodule ExRabbitMQ.ConnectionConfig do
  @moduledoc """
  A stucture holding the necessary information about a connection to a RabbitMQ node.

  ```elixir
  defstruct [:username, :password, :host, :port, :vhost, :heartbeat, :reconnect_after, :qos_opts]
  ```
  """

  defstruct [:username, :password, :host, :port, :vhost, :heartbeat, :reconnect_after, :qos_opts]
end
