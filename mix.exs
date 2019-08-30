defmodule ExRabbitMQ.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exrabbitmq,
      version: "5.0.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() not in [:dev, :test],
      start_permanent: Mix.env() not in [:dev, :test],
      deps: deps()
    ]
    |> Keyword.merge(package())
  end

  defp elixirc_paths(:test), do: ["lib", "test/extras"]
  defp elixirc_paths(_), do: ["lib"]

  def application, do: do_application(Mix.env())

  defp do_application(:test) do
    [
      extra_applications: [:logger]
    ]
  end

  defp do_application(_) do
    [
      extra_applications: [:logger, :poolboy]
    ]
  end

  defp deps do
    [
      {:amqp, "~> 1.1"},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:ex_doc, "~> 0.20.2", only: :dev, runtime: false},
      {:poolboy, github: "StoiximanServices/poolboy", branch: "weighted_strategy"}
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
