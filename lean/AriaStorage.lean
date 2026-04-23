-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026-present K. S. Ernest (iFire) Lee

import AriaStorage.BuzHash
import AriaStorage.Chunker
import AriaStorage.Index

/-!
# AriaStorage Lean4 Formal Properties

Lean4 proofs for the core invariants of the aria-storage Elixir library,
which is the planned replacement for the Go `desync` chunk server.

Modules:
- `AriaStorage.BuzHash`  — rolling hash terminates; result ≤ maxEnd
- `AriaStorage.Chunker`  — chunk boundaries cover data with no gaps or overlaps
- `AriaStorage.Index`    — SHA-512/256 identity; index round-trip axioms
-/
