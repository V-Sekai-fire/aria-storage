# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.Repo do
  use Ecto.Repo,
    otp_app: :aria_storage,
    adapter: Ecto.Adapters.SQLite3

  # @impl true
  # def migrations(), do: [] # Placeholder, will be updated
end
