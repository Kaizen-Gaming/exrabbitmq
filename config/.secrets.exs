# Template secrets configuration.
#
# Clone this file & rename it to {dev | prod | staging}.secrets.exs.
# Then edit it to configure the application credentials for your enviroment.

import Config

config :exrabbitmq, :connection,
  username: "guest",
  password: "guest",
  host: "localhost"
