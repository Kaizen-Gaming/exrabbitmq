defmodule ExRabbitMQ.Mixfile do
  use Mix.Project

  def project do
    [app: :exrabbitmq,
     version: "2.6.0",
     elixir: "~> 1.5",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
    |> merge_package_info()
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

  defp merge_package_info(project_spec) do
    project_spec
    |> Keyword.merge([
      name: "ExRabbitMQ",
      source_url: "https://github.com/StoiximanServices/exrabbitmq",
      homepage_url: "https://github.com/StoiximanServices/exrabbitmq/blob/master/README.md",
      docs: [main: "ExRabbitMQ", logo: "logo.png"],
      description: "A thin, boilerplate hiding wrapper for https://github.com/pma/amqp (RabbitMQ client library)",
      package: [
        maintainers: ["sadesyllas"],
        licenses: ["MIT"],
        links: %{"Github" => "https://github.com/StoiximanServices/exrabbitmq"}
      ],
    ])
  end
end
