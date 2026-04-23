-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026-present K. S. Ernest (iFire) Lee

/-!
# Index Format — SHA-512/256 Identity and Round-Trip Axioms

Documents two contract axioms that the Elixir implementation must satisfy
to be wire-compatible with desync clients (Godot, desync CLI):

1. **SHA-512/256 identity** — The chunk ID algorithm
   (`:crypto.hash(:sha512, data) |> binary_part(0, 32)`) is exactly
   SHA-512/256 (FIPS 180-4 §6.7), not plain SHA-256.
   A silent switch to SHA-256 would produce incompatible chunk IDs.

2. **Index round-trip** — `deserialize(serialize(index)) = .ok index` for any
   valid index. Required so that aria-storage can read back its own `.caibx`
   files and desync can read indexes written by aria-storage.

Stated as axioms because the properties are verified by Elixir tests
(`casync_format_roundtrip_test.exs`) rather than a Lean4 implementation
of the binary format or SHA-512.
-/

namespace AriaStorage.Index

/-!
## Abstract Types
-/

/-- Abstract index (mirrors the `AriaStorage.Index` Elixir struct). -/
opaque Index : Type := Unit

/-- Predicate: index is structurally valid (≥1 chunk, sizes consistent). -/
opaque ValidIndex : Index → Prop

/-- Serialise an index to `.caibx` binary. -/
opaque serialize : Index → ByteArray

/-- Parse result. -/
inductive ParseResult (α : Type) where
  | ok  : α → ParseResult α
  | err : String → ParseResult α
  deriving Repr, DecidableEq

/-- Parse a `.caibx` binary back to an index. -/
axiom deserialize : ByteArray → ParseResult Index

/-!
## Axiom 1 — SHA-512/256 Identity

The Elixir chunk ID is `:crypto.hash(:sha512, data) |> binary_part(0, 32)`,
which is exactly SHA-512/256 (first 32 bytes of SHA-512).
This axiom pins the identity at the type level so a future refactor cannot
silently switch to plain SHA-256.
-/

opaque sha512     : ByteArray → ByteArray
opaque sha512_256 : ByteArray → ByteArray

/-- **Axiom 1**: SHA-512/256 = first 32 bytes of SHA-512. -/
axiom sha512_256_eq_sha512_prefix (data : ByteArray) :
    sha512_256 data = (sha512 data).extract 0 32

/-- SHA-512 output is always 64 bytes. -/
axiom sha512_output_size (data : ByteArray) : (sha512 data).size = 64

/-!
## Axiom 2 — Index Round-Trip
-/

/-- **Axiom 2**: valid index survives serialize/deserialize. -/
axiom index_roundtrip (idx : Index) (h : ValidIndex idx) :
    deserialize (serialize idx) = ParseResult.ok idx

/-!
## Derived Properties
-/

/-- A round-trip never yields a parse error for a valid index. -/
theorem serialize_parse_not_err (idx : Index) (h : ValidIndex idx) :
    ¬ ∃ msg, deserialize (serialize idx) = ParseResult.err msg := by
  intro ⟨msg, hErr⟩
  have hOk := index_roundtrip idx h
  rw [hErr] at hOk
  -- hOk : ParseResult.err msg = ParseResult.ok idx
  -- Different constructors of ParseResult, so this is absurd.
  simp at hOk

/-- The deserialized index equals the original (not just "some ok value"). -/
theorem roundtrip_exact (idx : Index) (h : ValidIndex idx) :
    ∃ idx', deserialize (serialize idx) = ParseResult.ok idx' ∧ idx' = idx := by
  exact ⟨idx, index_roundtrip idx h, rfl⟩

end AriaStorage.Index
