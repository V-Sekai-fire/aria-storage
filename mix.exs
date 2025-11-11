# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.MixProject do
  use Mix.Project

  def project do
    [
      app: :aria_storage,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: ["test"],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {AriaStorage.Application, []},
      # Explicitly list the repo for migrations for the aria_storage application
      ecto_repos: [AriaStorage.Repo]
    ]
  end

  defp deps do
    [
      # Storage and File Management
      {:waffle, "~> 1.1"},
      {:waffle_ecto, "~> 0.0.11"},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:hackney, "~> 1.18"},
      {:sweet_xml, "~> 0.7"},
      {:sftp_ex, "~> 0.2"},
      {:finch, "~> 0.16"},
      {:httpoison, "~> 1.8"},

      # Compression - using built-in :zstd module from Erlang/OTP 28+

      # JSON handling
      {:jason, "~> 1.4"},

      # Database (for chunk metadata)
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, "~> 0.22.0"},

      # UUID Generation
      {:elixir_uuid, "~> 1.2"},
      {:porcelain, "~> 2.0"},

      # Development and testing tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:stream_data, "~> 1.2", only: :test}
    ]
  end
end
