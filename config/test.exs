# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

import Config

config :aria_storage, AriaStorage.Repo,
  url:
    System.get_env(
      "TEST_DATABASE_URL",
      "postgresql://root@localhost:26257/aria_storage_test?sslmode=disable"
    ),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5
