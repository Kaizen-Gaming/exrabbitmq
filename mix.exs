defmodule ExRabbitMQ.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exrabbitmq,
      version: "3.0.0-pre.1",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
    |> Keyword.merge(package())
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.8", runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.18", runtime: false},
      {:amqp, "~> 0.3"}
    ]
  end

  defp package do
    [
      name: "ExRabbitMQ",
      source_url: "https://github.com/StoiximanServices/exrabbitmq",
      homepage_url: "https://github.com/StoiximanServices/exrabbitmq/blob/master/README.md",
      docs: [main: "ExRabbitMQ", logo: "logo.png"],
      description:
        "A thin, boilerplate hiding wrapper for https://github.com/pma/amqp (RabbitMQ client library)",
      package: [
        maintainers: ["sadesyllas", "indyone"],
        licenses: ["MIT"],
        links: %{"Github" => "https://github.com/StoiximanServices/exrabbitmq"}
      ]
    ]
  end
end
