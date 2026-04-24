# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

import Config

crdb_ssl =
  case System.get_env("CRDB_CA_CERT") do
    nil ->
      false

    ca ->
      [
        cacertfile: ca,
        certfile: System.get_env("CRDB_CLIENT_CERT"),
        keyfile: System.get_env("CRDB_CLIENT_KEY"),
        verify: :verify_peer,
        server_name_indication: ~c"crdb"
      ]
  end

config :aria_storage, AriaStorage.Repo,
  adapter: Ecto.Adapters.Postgres,
  url:
    System.get_env(
      "DATABASE_URL",
      "postgresql://root@localhost:26257/aria_storage?sslmode=disable"
    ),
  pool_size: 10,
  migration_lock: false,
  ssl: crdb_ssl

import_config "#{config_env()}.exs"
