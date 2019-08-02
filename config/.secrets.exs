# Template secrets configuration.
#
# Clone this file & rename it to {dev | prod | staging}.secrets.exs.
# Then edit it to configure the application credentials for your enviroment.

import Config

for connection <- [:test_different_connections, :test_max_channels] do
  config :exrabbitmq, connection,
  username: "guest",
  password: "guest",
  host: "localhost",
  application_name: "exrabbitmq_tests"
end
