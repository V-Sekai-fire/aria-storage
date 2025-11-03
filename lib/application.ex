# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.Application do
  @moduledoc false
  use Application
  @impl true
  def start(_type, _args) do
    children = [
      AriaStorage.Repo # Start the Ecto repository
    ]
    opts = [strategy: :one_for_one, name: AriaStorage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
