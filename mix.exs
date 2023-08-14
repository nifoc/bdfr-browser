defmodule BdfrBrowser.MixProject do
  use Mix.Project

  def project do
    [
      app: :bdfr_browser,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex],
      mod: {BdfrBrowser.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:jason, "~> 1.4"},
      {:earmark, "~> 1.4"},
      {:file_system, "~> 0.2.10"},
      {:typed_struct, "~> 0.3.0", runtime: false}
    ]
  end
end
