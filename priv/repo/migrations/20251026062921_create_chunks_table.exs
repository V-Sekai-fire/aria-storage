# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.Repo.Migrations.CreateChunksTable do
  use Ecto.Migration

  def change do
    create table(:chunks) do
      add :data, :binary, null: false
      timestamps()
    end

    create unique_index(:chunks, [:data])
  end
end
