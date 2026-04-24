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
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:ex_aws, :plug, :req, :waffle, :waffle_ecto, :finch, :ecto, :ecto_sql],
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
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
      {:sweet_xml, "~> 0.7"},
      {:sftp_ex, "~> 0.2"},
      {:finch, "~> 0.16"},
      {:req, "~> 0.5"},
      {:plug, "~> 1.16"},

      # Compression - using built-in :zstd module from Erlang/OTP 28+

      # JSON handling
      {:jason, "~> 1.4"},

      # Database (for chunk metadata)
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},

      # UUID Generation
      {:elixir_uuid, "~> 1.2"},
      {:porcelain, "~> 2.0"},

      # Development and testing tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:stream_data, "~> 1.2", only: :test},
      {:propcheck, "~> 1.4", only: [:test, :dev], runtime: false}
    ]
  end
end
