defmodule Efetch.MixProject do
  use Mix.Project

  def project do
    [
      app: :efetch,
      mod: {Efetch, []},
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :os_mon, :sasl],
      mod: {Efetch.Main, []},
    ]
  end

  defp deps do
    [
      
    {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
    ]
  end
end
