defmodule ExRabbitMQ.Connection.Config do
  @moduledoc """
  A stucture holding the necessary information about a connection to a RabbitMQ node.

  ```elixir
  defstruct [:username, :password, :host, :port, :vhost, :heartbeat, :reconnect_after]
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

    # the delay after which a connection wil be re-attempted after having been 
    # dropped (optional, default: 2000)
    reconnect_after: 2000,
  ```
  """

  @name __MODULE__

  @type t :: %__MODULE__{}

  defstruct [:username, :password, :host, :port, :vhost, :heartbeat, :reconnect_after]

  @doc """
  Returns a part of the `:exrabbitmq` configuration section, specified with the
  `key` argument.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @spec from_env(key :: atom | module) :: t()
  def from_env(key) do
    from_env(:ex_rabbitmq, key)
  end

  @doc """
  Returns a part of the `app` configuration section, specified with the
  `key` argument.

  For the configuration format see the top section of `ExRabbitMQ.Consumer`.
  """
  @spec from_env(app :: atom, key :: atom | module) :: t()
  def from_env(app, key) do
    config = Application.get_env(app, key, [])

    %@name{
      username: config[:username],
      password: config[:password],
      host: config[:host],
      port: config[:port],
      vhost: config[:vhost],
      heartbeat: config[:heartbeat],
      reconnect_after: config[:reconnect_after]
    }
  end

  @spec merge_defaults(config :: t()) :: t()
  def merge_defaults(%@name{} = config) do
    %@name{
      username: config.username,
      password: config.password,
      host: config.host,
      port: config.port || 5672,
      vhost: config.vhost || "/",
      heartbeat: config.heartbeat || 1000,
      reconnect_after: config.reconnect_after || 2000
    }
  end
end
