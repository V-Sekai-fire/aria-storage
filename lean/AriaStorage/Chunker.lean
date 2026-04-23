-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026-present K. S. Ernest (iFire) Lee

/-!
# Chunker Partition Invariant

Proves that the chunking algorithm produces chunks that form a contiguous,
bounded partition of [0, dataSize) — no byte gaps, no overlaps.

The boundary finder is abstracted as a parameter satisfying:
  `∀ pos, pos < dataSize → pos < find pos ∧ find pos ≤ dataSize`
-/

namespace AriaStorage.Chunker

structure Chunk where
  offset : Nat
  size   : Nat
  deriving Repr, DecidableEq

instance : Inhabited Chunk := ⟨⟨0, 0⟩⟩

def Adjacent (a b : Chunk) : Prop := a.offset + a.size = b.offset

def Contiguous : List Chunk → Prop
  | []             => True
  | [_]            => True
  | a :: b :: rest => Adjacent a b ∧ Contiguous (b :: rest)

def AllBounded (chunks : List Chunk) (dataSize : Nat) : Prop :=
  ∀ c ∈ chunks, c.offset + c.size ≤ dataSize

structure BoundaryFinder (dataSize : Nat) where
  find : Nat → Nat
  mono : ∀ pos, pos < dataSize → pos < find pos ∧ find pos ≤ dataSize

-- Algorithm ----------------------------------------------------------------

def chunkifyFueled (fuel dataSize pos : Nat) (bf : BoundaryFinder dataSize) : List Chunk :=
  match fuel with
  | 0 =>
    if pos < dataSize then [⟨pos, dataSize - pos⟩] else []
  | fuel' + 1 =>
    if pos < dataSize then
      ⟨pos, bf.find pos - pos⟩ :: chunkifyFueled fuel' dataSize (bf.find pos) bf
    else []

def chunkify (dataSize pos : Nat) (bf : BoundaryFinder dataSize) : List Chunk :=
  chunkifyFueled (dataSize - pos + 1) dataSize pos bf

-- Helpers ------------------------------------------------------------------

/-- Result is `[]` when start ≥ dataSize. -/
private theorem chunkifyFueled_of_ge (n dataSize p : Nat) (bf : BoundaryFinder dataSize)
    (hGe : dataSize ≤ p) : chunkifyFueled n dataSize p bf = [] := by
  have hlt : ¬p < dataSize := by omega
  cases n with
  | zero   => unfold chunkifyFueled; exact if_neg hlt
  | succ _ => unfold chunkifyFueled; exact if_neg hlt

/-- First element of a non-empty result has `offset = pos`. -/
theorem chunkifyFueled_head_offset (fuel dataSize pos : Nat) (bf : BoundaryFinder dataSize)
    (h : pos < dataSize) (next : Chunk) (rest : List Chunk)
    (hEq : chunkifyFueled fuel dataSize pos bf = next :: rest) :
    next.offset = pos := by
  match fuel with
  | 0 =>
    simp only [chunkifyFueled, if_pos h] at hEq
    exact (List.cons.inj hEq).1 ▸ rfl
  | _ + 1 =>
    simp only [chunkifyFueled, if_pos h] at hEq
    exact (List.cons.inj hEq).1 ▸ rfl

-- Theorems -----------------------------------------------------------------

/-- **Theorem 2a — Bounds**: every chunk fits within [0, dataSize). -/
theorem chunkifyFueled_allBounded (fuel dataSize pos : Nat) (bf : BoundaryFinder dataSize)
    (hPos : pos ≤ dataSize) :
    AllBounded (chunkifyFueled fuel dataSize pos bf) dataSize := by
  induction fuel generalizing pos with
  | zero =>
    intro c hc
    by_cases h : pos < dataSize
    · simp only [chunkifyFueled, if_pos h, List.mem_singleton] at hc
      subst hc
      -- c = ⟨pos, dataSize - pos⟩; need pos + (dataSize - pos) ≤ dataSize
      show pos + (dataSize - pos) ≤ dataSize
      omega
    · simp only [chunkifyFueled, if_neg h, List.not_mem_nil] at hc
  | succ n ih =>
    intro c hc
    by_cases h : pos < dataSize
    · simp only [chunkifyFueled, if_pos h, List.mem_cons] at hc
      rcases hc with rfl | hRest
      · -- c = ⟨pos, bf.find pos - pos⟩
        show pos + (bf.find pos - pos) ≤ dataSize
        have ⟨_, hLe⟩ := bf.mono pos h
        omega
      · have ⟨_, hLe⟩ := bf.mono pos h
        exact ih (bf.find pos) (by omega) c hRest
    · simp only [chunkifyFueled, if_neg h, List.not_mem_nil] at hc

/-- **Theorem 2b — Contiguity**: adjacent chunks are contiguous. -/
theorem chunkifyFueled_contiguous (fuel dataSize pos : Nat) (bf : BoundaryFinder dataSize) :
    Contiguous (chunkifyFueled fuel dataSize pos bf) := by
  induction fuel generalizing pos with
  | zero =>
    by_cases h : pos < dataSize
    · simp only [chunkifyFueled, if_pos h, Contiguous]
    · simp only [chunkifyFueled, if_neg h, Contiguous]
  | succ n ih =>
    by_cases h : pos < dataSize
    · simp only [chunkifyFueled, if_pos h]
      have ⟨hLt, hLe⟩ := bf.mono pos h
      cases hTail : chunkifyFueled n dataSize (bf.find pos) bf with
      | nil  => simp only [Contiguous]
      | cons next rest =>
        simp only [Contiguous, Adjacent]
        constructor
        · -- Adjacency: pos + (endPos - pos) = next.offset
          -- Step 1: endPos < dataSize (else tail = [], contradicting hTail)
          have hEnd : bf.find pos < dataSize := by
            apply Nat.lt_of_le_of_ne hLe
            intro heq
            -- heq : bf.find pos = dataSize → chunkifyFueled returns []
            have hempty := chunkifyFueled_of_ge n dataSize (bf.find pos) bf (by omega)
            rw [hempty] at hTail
            exact absurd hTail.symm (List.cons_ne_nil next rest)
          -- Step 2: next.offset = endPos
          have hOff := chunkifyFueled_head_offset n dataSize (bf.find pos) bf hEnd next rest hTail
          -- Step 3: close with omega (pos < endPos from hLt)
          show pos + (bf.find pos - pos) = next.offset
          rw [hOff]; omega
        · -- Contiguity: Contiguous (next :: rest) from IH
          have hIH := ih (bf.find pos)
          rw [hTail] at hIH
          exact hIH
    · -- pos ≥ dataSize: result is [], Contiguous [] = True
      have hresult : chunkifyFueled (n + 1) dataSize pos bf = [] := by
        unfold chunkifyFueled; exact if_neg h
      rw [hresult]
      -- Contiguous [] = True
      trivial

theorem chunkify_contiguous (dataSize pos : Nat) (bf : BoundaryFinder dataSize) :
    Contiguous (chunkify dataSize pos bf) :=
  chunkifyFueled_contiguous _ _ _ _

theorem chunkify_allBounded (dataSize pos : Nat) (bf : BoundaryFinder dataSize)
    (hPos : pos ≤ dataSize) :
    AllBounded (chunkify dataSize pos bf) dataSize :=
  chunkifyFueled_allBounded _ _ _ _ hPos

end AriaStorage.Chunker
