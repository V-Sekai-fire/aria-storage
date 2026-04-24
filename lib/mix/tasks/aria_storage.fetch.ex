# SPDX-License-Identifier: MIT
# Copyright (c) 2026-present K. S. Ernest (iFire) Lee

defmodule Mix.Tasks.AriaStorage.Fetch do
  @shortdoc "Fetch and assemble a casync/desync asset from a remote store"

  @moduledoc """
  Downloads a `.caidx` or `.caibx` index from a remote URL, fetches all
  referenced chunks from the corresponding store, and assembles the output file.

  ## Usage

      mix aria_storage.fetch [options]

  ## Options

      --index URL     Index file URL (.caidx or .caibx). Required.
      --store URL     Chunk store base URL. Defaults to the index URL's
                      directory joined with `store/`.
      --output PATH   Directory to write the assembled output. Defaults to
                      the current directory.

  ## Examples

      # Fetch the V-Sekai Linux game build
      mix aria_storage.fetch \\
        --index https://v-sekai.github.io/casync-v-sekai-game/vsekai_game_linux_x86_64.caidx \\
        --store https://raw.githubusercontent.com/V-Sekai/casync-v-sekai-game/main/store \\
        --output /tmp/vsekai_linux

      # Fetch using default store inference (same base URL as index)
      mix aria_storage.fetch \\
        --index https://v-sekai.github.io/casync-v-sekai-game/vsekai_game_windows_x86_64.caidx \\
        --output /tmp/vsekai_windows

  ## Available indexes at v-sekai.github.io/casync-v-sekai-game

      vsekai_game_linux_x86_64.caidx
      vsekai_game_macos_x86_64.caidx
      vsekai_game_windows_x86_64.caidx

  The chunk store is at:
      https://raw.githubusercontent.com/V-Sekai/casync-v-sekai-game/main/store
  """

  use Mix.Task

  @base_url "https://v-sekai.github.io/casync-v-sekai-game"
  @default_store "https://raw.githubusercontent.com/V-Sekai/casync-v-sekai-game/main/store"

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:req)
    Application.ensure_all_started(:aria_storage)

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [index: :string, store: :string, output: :string]
      )

    index_url = Keyword.get(opts, :index) || default_index_url()
    store_url = Keyword.get(opts, :store) || infer_store_url(index_url)
    output_dir = Keyword.get(opts, :output, File.cwd!())

    Mix.shell().info("Index:  #{index_url}")
    Mix.shell().info("Store:  #{store_url}")
    Mix.shell().info("Output: #{output_dir}")

    File.mkdir_p!(output_dir)

    progress = fn done, total ->
      pct = if total > 0, do: round(done * 100 / total), else: 0
      Mix.shell().info("  chunks: #{done}/#{total} (#{pct}%)")
    end

    Mix.shell().info("Fetching index...")

    case AriaStorage.CasyncDecoder.decode_uri(index_url,
           store_uri: store_url,
           output_dir: output_dir,
           verify_integrity: true,
           progress_callback: progress
         ) do
      {:ok, result} ->
        Mix.shell().info("")
        Mix.shell().info("Done.")
        Mix.shell().info("  format:  #{result.format}")
        Mix.shell().info("  chunks:  #{result.chunk_count}")
        Mix.shell().info("  size:    #{format_bytes(result.file_size)}")

        if result.assembly_result do
          a = result.assembly_result
          Mix.shell().info("  output:  #{a.assembled_file}")
          Mix.shell().info("  written: #{format_bytes(a.bytes_written)}")
          Mix.shell().info("  verified: #{a.verification_passed}")
        end

      {:error, reason} ->
        Mix.raise("aria_storage.fetch failed: #{inspect(reason)}")
    end
  end

  defp default_index_url do
    Mix.shell().info(
      "No --index given. Fetching Linux build from #{@base_url}.\n" <>
        "Pass --index URL to choose a different platform."
    )

    "#{@base_url}/vsekai_game_linux_x86_64.caidx"
  end

  defp infer_store_url(index_url) do
    if String.contains?(index_url, "v-sekai.github.io/casync-v-sekai-game") do
      @default_store
    else
      # Best-effort: assume store/ is a sibling of the index file.
      index_url
      |> URI.parse()
      |> Map.update!(:path, &(Path.dirname(&1) <> "/store"))
      |> URI.to_string()
    end
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "unknown"
end
