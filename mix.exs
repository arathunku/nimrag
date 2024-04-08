defmodule Nimrag.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :nimrag,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: !!System.get_env("CI")
      ],
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      package: package(),
      name: "Nimrag",
      source_url: "https://github.com/arathunku/nimrag",
      homepage_url: "https://github.com/arathunku/nimrag",
      docs: &docs/0,
      description: """
      Use Garmin API from Elixir! Fetch activities, steps, and more from Garmin Connect.
      """,
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        check: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:hammer],
        flags: [:error_handling, :unknown],
        # Error out when an ignore rule is no longer useful so we can remove it
        list_unused_filters: true
      ]
    ]
  end

  def application do
    [
      mod: {Nimrag.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.4.14"},
      {:oauther, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:recase, "~> 0.7"},
      {:schematic, "~> 0.3"},
      {:hammer, "~> 6.2", runtime: false},
      {:plug, "~> 1.0", only: [:test]},
      {:excoveralls, "~> 0.18.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: [
        "clean",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "deps.unlock --check-unused",
        "test --warnings-as-errors",
        "dialyzer --format short",
        "credo"
      ]
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: "https://github.com/arathunku/nimrag",
      extras: extras(),
      api_reference: false,
      groups_for_extras: [
        {"Livebook examples", Path.wildcard("examples/*")}
      ],
      formatters: ["html"],
      main: "readme",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  def extras do
    [
      "README.md": [title: "Overview"],
      "CHANGELOG.md": [title: "Changelog"],
      # "CONTRIBUTING.md": [title: "Contributing"],
      "LICENSE.md": [title: "License"]
    ] ++ Path.wildcard("examples/*.livemd")
  end

  defp package do
    [
      maintainers: ["@arathunku"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://hexdocs.pm/nimrag/changelog.html",
        GitHub: "https://github.com/arathunku/nimrag"
      },
      files: ~w(lib CHANGELOG.md LICENSE.md mix.exs README.md .formatter.exs)
    ]
  end
end
