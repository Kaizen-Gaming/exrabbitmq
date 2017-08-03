defmodule ExRabbitMQ.Mixfile do
  use Mix.Project

  def project do
    [app: :exrabbitmq,
     version: "1.0.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     name: "ExRabbitMQ",
     source_url: "https://exrabbitmq",
     homepage_url: "http://exrabbitmq",
     docs: [main: "readme",
            logo: "logo.png",
            extras: ["README.md", "test/TEST.md"]]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 0.8.1", runtime: false},
      {:dialyxir, "~> 0.5.0", only: [:dev]},
      {:amqp, "~> 0.2.3"},
      {:ex_doc, "~> 0.16.2"},
    ]
  end
end
