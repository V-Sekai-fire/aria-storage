-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026-present K. S. Ernest (iFire) Lee

/-!
# BuzHash Rolling Hash — Termination and Bound Safety

Models `AriaStorage.Chunks.RollingHash` (Elixir) and proves:

1. **Termination** — `rollingSearch` always halts (structural via fuel)
2. **Bound safety** — result is always ≤ `maxEnd` (no out-of-bounds offset)

The hash table and formulas match desync's `chunker.go` exactly.
-/

/-- Safe byte access with default 0, defined at root scope so dot notation works. -/
@[irreducible]
def ByteArray.safeGet (data : ByteArray) (i : Nat) : UInt8 :=
  if h : i < data.size then data[i]'h else 0

namespace AriaStorage.BuzHash

/-- Rolling window size. Must equal desync's `ChunkerWindowSize = 48`. -/
def windowSize : Nat := 48

/-- 32-bit left rotate, matching desync's `rol32`. -/
def rol32 (v s : UInt32) : UInt32 :=
  let s' := s % 32
  (v <<< s') ||| (v >>> (32 - s'))

/-!
The 256-entry hash table is identical to desync's `hashTable`.
Declared as an axiom; verified by `chunks_verification_test.exs`.
-/
axiom hashTable : Array UInt32
axiom hashTable_size : hashTable.size = 256

noncomputable def lookupHash (b : UInt8) : UInt32 :=
  hashTable.getD b.toNat 0

/-- Slide the rolling hash one position forward.
    Matches desync's `update_hash` and Elixir's `update_buzhash/3`. -/
noncomputable def updateBuzHash (hash : UInt32) (outByte inByte : UInt8) : UInt32 :=
  let outVal := rol32 (lookupHash outByte) windowSize.toUInt32
  let inVal  := lookupHash inByte
  (rol32 hash 1 ^^^ outVal) ^^^ inVal

/-- Hash after sliding the window one step.
    `@[irreducible]` stops `split` from descending into the inner `if` in `safeGet`. -/
@[irreducible]
noncomputable def stepHash (data : ByteArray) (pos : Nat) (hash : UInt32) : UInt32 :=
  updateBuzHash hash (data.safeGet (pos + 1 - windowSize)) (data.safeGet (pos + 1))

/-!
## Rolling Search (fuel-parametrised)

No `let`-bindings with nested ifs in the else branch, so Lean4's `split`
tactic peels off exactly the three outer `if-then-else` levels.
-/

noncomputable def rollingSearchFueled (fuel : Nat) (data : ByteArray) (pos maxEnd : Nat)
    (hash disc : UInt32) : Nat :=
  match fuel with
  | 0 => maxEnd
  | fuel' + 1 =>
    if pos ≥ maxEnd then maxEnd
    else if pos + 1 ≥ data.size then maxEnd
    else if disc ≠ 0 && stepHash data pos hash % disc == disc - 1 then
      min (pos + 2) maxEnd
    else
      rollingSearchFueled fuel' data (pos + 1) maxEnd (stepHash data pos hash) disc

noncomputable def rollingSearch (data : ByteArray) (pos maxEnd : Nat)
    (hash disc : UInt32) : Nat :=
  rollingSearchFueled (maxEnd - pos + 1) data pos maxEnd hash disc

/-!
## Safety Theorems
-/

/-- **Theorem 1 — Bound safety**: `rollingSearch` never returns > `maxEnd`. -/
theorem rollingSearchFueled_le_maxEnd (fuel : Nat) (data : ByteArray) (pos maxEnd : Nat)
    (hash disc : UInt32) :
    rollingSearchFueled fuel data pos maxEnd hash disc ≤ maxEnd := by
  induction fuel generalizing pos hash disc with
  | zero => simp [rollingSearchFueled]
  | succ n ih =>
    unfold rollingSearchFueled
    -- Flat three-level if-chain; split handles each level.
    split
    · exact Nat.le_refl _             -- pos ≥ maxEnd → maxEnd
    · split
      · exact Nat.le_refl _           -- pos+1 ≥ data.size → maxEnd
      · split
        · exact Nat.min_le_right _ _  -- boundary hit → min _ maxEnd
        · exact ih _ _ _              -- no boundary → recursive (IH)

theorem rollingSearch_le_maxEnd (data : ByteArray) (pos maxEnd : Nat)
    (hash disc : UInt32) :
    rollingSearch data pos maxEnd hash disc ≤ maxEnd :=
  rollingSearchFueled_le_maxEnd _ _ _ _ _ _

end AriaStorage.BuzHash
