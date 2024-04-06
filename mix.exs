defmodule Nimrag.MixProject do
  use Mix.Project

  def project do
    [
      app: :nimrag,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Nimrag.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4.14"},
      {:oauther, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:recase, "~> 0.7"},
      {:schematic, "~> 0.1"},
      {:hammer, "~> 6.1", runtime: false}
    ]
  end
end
