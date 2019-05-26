defmodule ExRabbitMQ.Config.Connection do
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
  alias ExRabbitMQ.Config.Pool, as: PoolConfig

  require Logger

  defstruct [
    :username,
    :password,
    :host,
    :port,
    :vhost,
    :heartbeat,
    :reconnect_after,
    :max_channels,
    :pool,
    :cleanup_after
  ]

  @type t :: %__MODULE__{
          username: String.t(),
          password: String.t(),
          host: String.t(),
          port: pos_integer,
          vhost: String.t(),
          heartbeat: pos_integer,
          reconnect_after: pos_integer,
          max_channels: pos_integer,
          pool: PoolConfig.t(),
          cleanup_after: pos_integer
        }

  @spec get(atom, atom | t()) :: t()
  def get(app \\ :exrabbitmq, connection_config) do
    connection_config
    |> case do
      connection_config when is_atom(connection_config) -> from_app_env(app, connection_config)
      _ -> connection_config
    end
    |> merge_defaults()
    |> validate_connection_config
  end

  @spec to_hash_key(t()) :: {binary, t()}
  def to_hash_key(connection_config) do
    key =
      connection_config
      |> :erlang.term_to_binary()
      |> :erlang.md5()

    {key, connection_config}
  end

  # Returns a part of the `app` configuration section, specified with the
  # `key` argument as a `ExRabbitMQ.Config.Connection` struct.
  # If the `app` argument is omitted, it defaults to `:exrabbitmq`.
  # For every required configuration property, we first try to retrieve its value
  # from an environment variable.
  @spec from_app_env(atom, atom | module) :: t()
  defp from_app_env(app, key) do
    config = Application.get_env(app, key, [])

    %__MODULE__{
      username: from_sys_env(:username) || config[:username],
      password: from_sys_env(:password) || config[:password],
      host: from_sys_env(:host) || config[:host],
      port: from_sys_env(:port, :integer) || config[:port],
      vhost: from_sys_env(:vhost) || config[:vhost],
      heartbeat: config[:heartbeat],
      reconnect_after: config[:reconnect_after],
      max_channels: config[:max_channels],
      pool: PoolConfig.get(config[:pool] || []),
      cleanup_after: config[:cleanup_after]
    }
  end

  # Constructs an environment variable name from the passed atom
  # and tries to get its value.
  @spec from_sys_env(atom) :: String.t() | nil
  defp from_sys_env(key) when is_atom(key) do
    key = key |> Atom.to_string() |> String.upcase()
    key = "EXRABBITMQ_CONNECTION_#{key}"

    System.get_env(key)
  end

  # With arity 2, this function deals with 3 cases:
  #   1. When the `key` is an atom, it's considered to be a configuration option name
  #     as set in one of the application's configuration files.
  #   2. When it's a binary, it's considered to be a value read from an environment variable,
  #     in which case, the value is formatted as per the type atom passed as the second argument
  #     to the function.
  #   3. If the environment variable is not set then nil is returned.
  @spec from_sys_env(atom | String.t() | nil, atom) :: String.t() | nil
  defp from_sys_env(key, type)

  defp from_sys_env(key, type) when is_atom(key) and key !== nil and is_atom(type) do
    key |> from_sys_env() |> from_sys_env(type)
  end

  defp from_sys_env(<<>> <> val, :integer), do: val |> Integer.parse() |> elem(0)
  defp from_sys_env(val, _), do: val

  # Merges an existing `ExRabbitMQ.Config.Connection` struct the default values when these are `nil`.
  defp merge_defaults(%__MODULE__{} = config) do
    %__MODULE__{
      username: config.username,
      password: config.password,
      host: config.host,
      port: config.port || 5672,
      vhost: config.vhost || "/",
      heartbeat: config.heartbeat || 20,
      reconnect_after: config.reconnect_after || 2_000,
      max_channels: config.max_channels || 65_535,
      pool: PoolConfig.get(config.pool || []),
      cleanup_after: config.cleanup_after || 5_000
    }
  end

  defp validate_connection_config(%__MODULE__{max_channels: max_channels} = config) do
    if max_channels >= 1 and max_channels <= 65_535 do
      config
    else
      Logger.warn("The maximum number of connections per channel is out of range 1 to 65535.")
      %__MODULE__{config | max_channels: 65_535}
    end
  end
end
