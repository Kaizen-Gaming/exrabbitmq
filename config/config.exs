import Config

config :logger,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  backends: [:console],
  level: :debug

config :logger, :console,
  format: "\n$time [$level] $metadata- $message\n",
  metadata: [:module],
  colors: [enabled: true, info: :green]

if File.exists?("#{__DIR__}/#{Mix.env()}.exs") do
  import_config "#{Mix.env()}.exs"
end

if File.exists?("#{__DIR__}/#{Mix.env()}.secrets.exs") do
  import_config "#{Mix.env()}.secrets.exs"
end
