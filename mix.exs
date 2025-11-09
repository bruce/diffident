defmodule Diffident.MixProject do
  use Mix.Project

  def project do
    [
      app: :diffident,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Structural diffs for Elixir values"
    ]
  end

  def package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bruce/diffident"},
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
