-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026-present K. S. Ernest (iFire) Lee

import Lake
open Lake DSL

package «ariaStorage» where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib «AriaStorage» where
