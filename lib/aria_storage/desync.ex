# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.Desync do
  @moduledoc """
  Elixir wrapper for the `desync` command-line tool.

  This module provides a convenient interface for interacting with `desync`
  for content-defined chunking, indexing, and file assembly.
  """

  alias Porcelain

  @desync_command "desync"

  @doc """
  Chunks a file and creates an index file using `desync make`.

  ## Parameters
  - `source_path`: The path to the file to be chunked.
  - `index_path`: The desired path for the output index file (.caibx).
  - `store_path`: The path to the chunk store (local directory or URL).
  - `opts`: Optional keyword list for `desync make` command.

  ## Examples
      AriaStorage.Desync.make("/path/to/file.glb", "/path/to/file.caibx", "/path/to/chunk_store")
  """
  @spec make(String.t(), String.t(), String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, String.t()}
  def make(source_path, index_path, store_path, opts \\ []) do
    # Ensure absolute paths for desync command
    abs_source_path = Path.expand(source_path)
    abs_index_path = Path.expand(index_path)
    abs_store_path = Path.expand(store_path)

    args = [
      "make",
      "-s", abs_store_path,
      abs_index_path,
      abs_source_path
    ] ++ format_opts(opts)

    execute_desync(args)
  end

  @doc """
  Extracts a blob from an index file using `desync extract`.

  ## Parameters
  - `index_path`: The path to the index file (.caibx).
  - `output_path`: The desired path for the re-assembled file.
  - `store_path`: The path to the chunk store.
  - `opts`: Optional keyword list for `desync extract` command.

  ## Examples
      AriaStorage.Desync.extract("/path/to/file.caibx", "/path/to/output.glb", "/path/to/chunk_store")
  """
  @spec extract(String.t(), String.t(), String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract(index_path, output_path, store_path, opts \\ []) do
    # Ensure absolute paths for desync command
    abs_index_path = Path.expand(index_path)
    abs_output_path = Path.expand(output_path)
    abs_store_path = Path.expand(store_path)

    args = [
      "extract",
      "-s", abs_store_path,
      abs_index_path,
      abs_output_path
    ] ++ format_opts(opts)

    execute_desync(args)
  end

  @doc """
  Lists all chunk IDs contained in an index file using `desync list-chunks`.

  ## Parameters
  - `index_path`: The path to the index file (.caibx).
  - `opts`: Optional keyword list for `desync list-chunks` command.

  ## Examples
      AriaStorage.Desync.list_chunks("/path/to/file.caibx")
  """
  @spec list_chunks(String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, String.t()}
  def list_chunks(index_path, opts \\ []) do
    args = [
      "list-chunks",
      index_path
    ] ++ format_opts(opts)

    execute_desync(args)
  end

  # Executes the desync command using Porcelain
  defp execute_desync(args) do
    case Porcelain.exec(@desync_command, args) do
      %Porcelain.Result{status: 0, out: stdout} ->
        {:ok, String.trim(stdout)}
      %Porcelain.Result{status: status, err: stderr} ->
        {:error, "desync command failed with exit status #{status}: #{String.trim(stderr)}"}
    end
  end

  # Formats keyword options into command-line arguments
  defp format_opts(opts) do
    Enum.flat_map(opts, fn
      {key, true} -> ["--" <> Atom.to_string(key)]
      {_key, value} when is_boolean(value) -> [] # Don't include false flags
      {key, value} -> ["--" <> Atom.to_string(key), to_string(value)]
    end)
  end
end
