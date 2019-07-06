defmodule CSQuery.Mixfile do
  use Mix.Project

  @name :csquery
  @version "1.0.0"
  @source_url "https://github.com/KineticCafe/csquery"

  @docs [
    main: "readme",
    extras: ["README.md", "Contributing.md", "Licence.md"]
  ]

  @deps [
    {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
    {:excoveralls, "~> 0.8", only: [:dev, :test], runtime: false},
    {:ex_doc, "~> 0.14", only: [:dev, :test], runtime: false},
    {:inch_ex, "~> 0.5", only: [:dev, :test], runtime: false}
  ]

  @description """
  CSQuery is a query builder for the AWS CloudSearch structured search syntax.
  """

  @package [
    files: ["lib", "mix.exs", "README.md", "Contributing.md", "Licence.md", ".formatter.exs"],
    licenses: ["MIT"],
    links: %{"GitHub" => @source_url}
  ]

  def project do
    [
      app: @name,
      version: @version,
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      elixirc_paths: ["lib"],
      deps: @deps,
      source_url: @source_url,
      docs: @docs,
      description: @description,
      package: @package,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.semaphore": :test,
        "coveralls.html": :test
      ]
    ]
  end
end
