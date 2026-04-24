# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.Repo do
  use Ecto.Repo,
    otp_app: :aria_storage,
    adapter: Ecto.Adapters.Postgres
end
