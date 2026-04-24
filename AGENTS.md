# AGENTS.md — aria-storage

Guidance for AI coding agents working in this submodule.

## What this is

Elixir library for content-defined chunking and storage. Implements the
casync/desync `.caibx` / `.caidx` index format with zstd chunk compression.
Planned successor to `multiplayer-fabric-desync` (Go). Backends: local
filesystem, S3-compatible (via `ex_aws`), and Waffle.

Neither this library nor `multiplayer-fabric-desync` is removable until the
upload pipeline is fully wired through this library end-to-end.

## Build and test

```sh
mix compile
mix test
mix credo --min-priority high
mix format --check-formatted
```

## Key files

| Path | Purpose |
|------|---------|
| `mix.exs` | Dependencies: ex_aws, waffle, finch, req |
| `lib/aria_storage.ex` | Public API — delegating facade over internal modules |
| `lib/aria_storage/chunks.ex` | Content-defined chunking, zstd compress/decompress |
| `lib/aria_storage/index.ex` | `.caibx` / `.caidx` index serialization |
| `lib/aria_storage/chunk_store.ex` | Chunk CRUD over a configured backend |
| `lib/aria_storage/storage.ex` | Waffle/S3 file-level storage |

## Conventions

- All public functions return `{:ok, value}` or `{:error, reason}`.
- `raise` only for programmer errors (bad config at boot, wrong type).
- Every new `.ex` / `.exs` file needs SPDX headers in the first 2 KB:
  ```elixir
  # SPDX-License-Identifier: MIT
  # Copyright (c) 2026 K. S. Ernest (iFire) Lee
  ```
- Commit message style: sentence case, imperative, no `type(scope):` prefix.
  Example: `Add zstd streaming decompression to chunk store`
