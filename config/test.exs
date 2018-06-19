use Mix.Config

config :exrabbitmq, :test_different_connections,
  username: "guest",
  password: "guest",
  host: "localhost",
  reconnect_after: 500,
  pool: [size: 20, max_overflow: 5]

config :exrabbitmq, :test_max_channels,
  username: "guest",
  password: "guest",
  host: "localhost",
  reconnect_after: 500,
  max_channels: 1,
  pool: [size: 2, max_overflow: 1]
