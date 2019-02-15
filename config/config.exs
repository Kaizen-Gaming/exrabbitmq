use Mix.Config

if File.exists?("#{__DIR__}/#{Mix.env()}.exs") do
  import_config "#{Mix.env()}.exs"
end

if File.exists?("#{__DIR__}/#{Mix.env()}.secrets.exs") do
  import_config "#{Mix.env()}.secrets.exs"
end
