defmodule ExRabbitMQ.Connection.Config do
  @moduledoc """
  A structure holding the necessary information about a connection to a RabbitMQ node.

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

    # the connection's heartbeat RabbitMQ in seconds (optional, default: 20)
    heartbeat: 20,

    # the delay after which a connection wil be re-attempted after having been
    # dropped (optional, default: 2000)
    reconnect_after: 2000,

    # the maximum channels per connection (optional, default: 65535)
    max_channels: 65535,
  ```
  """
  require Logger

  @name __MODULE__

  @type t :: %__MODULE__{
          username: String.t(),
          password: String.t(),
          host: String.t(),
          port: pos_integer,
          vhost: String.t(),
          heartbeat: pos_integer,
          reconnect_after: pos_integer,
          max_channels: pos_integer
        }

  defstruct [
    :username,
    :password,
    :host,
    :port,
    :vhost,
    :heartbeat,
    :reconnect_after,
    :max_channels
  ]

  @doc """
  Returns a part of the `app` configuration section, specified with the
  `key` argument as a `ExRabbitMQ.Connection.Config` struct.
  If the `app` argument is omitted, it defaults to `:exrabbitmq`.
  """
  @spec from_env(app :: atom, key :: atom | module) :: t()
  def from_env(app \\ :exrabbitmq, key) do
    config = Application.get_env(app, key, [])

    %@name{
      username: config[:username],
      password: config[:password],
      host: config[:host],
      port: config[:port],
      vhost: config[:vhost],
      heartbeat: config[:heartbeat],
      reconnect_after: config[:reconnect_after],
      max_channels: config[:max_channels]
    }
  end

  @doc """
  Merges an existing `ExRabbitMQ.Connection.Config` struct the default values when these are `nil`.
  """
  @spec merge_defaults(config :: t()) :: t()
  def merge_defaults(%@name{} = config) do
    %@name{
      username: config.username,
      password: config.password,
      host: config.host,
      port: config.port || 5672,
      vhost: config.vhost || "/",
      heartbeat: config.heartbeat || 20,
      reconnect_after: config.reconnect_after || 2000,
      max_channels: config.max_channels || 65535
    }
  end

  def validate_connection_config(%@name{} = config) do
    {:ok, max_channels_validation(config)}
  end

  defp max_channels_validation(%@name{max_channels: max_channels} = config)
       when max_channels >= 1 and max_channels <= 65_535 do
    config
  end

  defp max_channels_validation(%@name{} = config) do
    Logger.warn("The maximum number of connections per channel is out of range 1 to 65535.")
    %@name{config | max_channels: 65_535}
  end
end
