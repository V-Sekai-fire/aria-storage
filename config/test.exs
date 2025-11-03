# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

import Config

# Configure AriaStorage.Repo to use FoundationDB
config :aria_storage, AriaStorage.Repo,
  adapter: Ecto.Adapters.FoundationDB,
  database: "aria_storage.fdb", # Using a placeholder name, actual naming might depend on tenant strategy
  cluster_file: "/etc/foundationdb/fdb.cluster", # Explicitly pointing to the cluster file
  pool_size: 5,
  pool: EctoFoundationDB.Sandbox # Using FDB sandbox for test transactions
# Ensure environment variables do not override these settings for tests
config :aria_storage, AriaStorage.Repo, system_env_variable: false
