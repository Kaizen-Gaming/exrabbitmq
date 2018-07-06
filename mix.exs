defmodule ExRabbitMQ.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exrabbitmq,
      version: "3.0.0-pre.2",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
    |> Keyword.merge(package())
  end

  defp elixirc_paths(:test), do: ["lib", "test/extras"]
  defp elixirc_paths(_), do: ["lib", "test/extras"]

  def application, do: do_application(Mix.env())

  defp do_application(:test), do: []
  defp do_application(_) do
    [
      extra_applications: [:logger, :poolboy]
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.9.3", runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.18", runtime: false},
      {:amqp, "~> 1.0"},
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
