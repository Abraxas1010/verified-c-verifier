import HeytingLean.LeanSP.Lang.YulSemantics

/-!
# LeanSP.Verify.Hoare

Hoare logic for Yul programs. `HoareTriple` uses `execStmt` from YulSemantics (H10).

## Error policy

`HoareTriple` and `HoareBlockTriple` enforce **total correctness modulo fuel**:
execution must produce `.ok` for all sufficient fuel values. Reverts, invalid states,
and other runtime errors make the triple **false**, not vacuously true. This prevents
proving correctness of programs that silently revert or error.

`PartialHoareTriple` / `PartialHoareBlockTriple` provide the weaker partial-correctness
semantics (`| _ => True`) for cases where the caller explicitly accepts unknown error
outcomes. These must be opted into by name — the default triple rejects errors.

`HoareRevertTriple` handles the intermediate case: `.ok` must satisfy `Q`, `.revert`
must satisfy `R`, and all other errors (except fuel exhaustion) are rejected.
-/

namespace LeanSP.Verify

open LeanSP.Yul
open LeanSP.EVM
open LeanSP.Arith

-- ==========================================
-- Hoare Triple Definitions (total correctness modulo fuel)
-- ==========================================

/-- Total Hoare triple (modulo fuel): execution must succeed or exhaust fuel.
    Reverts and runtime errors make this **false**, not vacuously true. -/
def HoareTriple (P : YulState → Prop) (s : Stmt) (Q : YulState → Prop) : Prop :=
  ∀ (fuel : Nat) (st : YulState),
    P st → match execStmt fuel s st with
    | .ok st' => Q st'
    | .error .outOfFuel => True
    | _ => False

/-- Total block triple (modulo fuel): execution must succeed or exhaust fuel. -/
def HoareBlockTriple (P : YulState → Prop) (stmts : Array Stmt) (Q : YulState → Prop) : Prop :=
  ∀ (fuel : Nat) (st : YulState),
    P st → match execBlock fuel stmts st with
    | .ok st' => Q st'
    | .error .outOfFuel => True
    | _ => False

/-- Revert-aware triple: `.ok` must satisfy `Q`, `.revert` must satisfy `R`,
    fuel exhaustion is tolerated, all other errors are rejected. -/
def HoareRevertTriple (P : YulState → Prop) (s : Stmt) (Q : YulState → Prop)
    (R : ByteArray → YulState → Prop) : Prop :=
  ∀ (fuel : Nat) (st : YulState),
    P st → match execStmt fuel s st with
    | .ok st' => Q st'
    | .error (.revert data st') => R data st'
    | .error .outOfFuel => True
    | _ => False

-- ==========================================
-- Partial correctness variants (explicit opt-in)
-- ==========================================

/-- Partial Hoare triple: if execution succeeds, `Q` holds. Does NOT rule out
    reverts, errors, or any non-ok outcome — use only when the caller explicitly
    accepts unknown failure modes. -/
def PartialHoareTriple (P : YulState → Prop) (s : Stmt) (Q : YulState → Prop) : Prop :=
  ∀ (fuel : Nat) (st : YulState),
    P st → match execStmt fuel s st with | .ok st' => Q st' | _ => True

/-- Partial block triple: if execution succeeds, `Q` holds. -/
def PartialHoareBlockTriple (P : YulState → Prop) (stmts : Array Stmt)
    (Q : YulState → Prop) : Prop :=
  ∀ (fuel : Nat) (st : YulState),
    P st → match execBlock fuel stmts st with | .ok st' => Q st' | _ => True

-- ==========================================
-- Proved Rules
-- ==========================================

theorem consequence {P P' Q Q' : YulState → Prop} {s : Stmt}
    (hPre : ∀ st, P' st → P st) (hPost : ∀ st, Q st → Q' st)
    (hTriple : HoareTriple P s Q) : HoareTriple P' s Q' := by
  intro fuel st hP'
  specialize hTriple fuel st (hPre st hP')
  revert hTriple
  cases execStmt fuel s st with
  | ok st' => exact hPost st'
  | error e =>
    cases e with
    | outOfFuel => exact id
    | _ => exact id

theorem partial_consequence {P P' Q Q' : YulState → Prop} {s : Stmt}
    (hPre : ∀ st, P' st → P st) (hPost : ∀ st, Q st → Q' st)
    (hTriple : PartialHoareTriple P s Q) : PartialHoareTriple P' s Q' := by
  intro fuel st hP'
  have h := hTriple fuel st (hPre st hP')
  revert h; cases execStmt fuel s st <;> (intro h; first | exact hPost _ h | trivial)

theorem partial_hoare_true {P : YulState → Prop} {s : Stmt} :
    PartialHoareTriple P s (fun _ => True) := by
  intro fuel st _; cases execStmt fuel s st <;> trivial

-- ==========================================
-- Simple evaluator for proofs (non-partial, non-recursive into bodies)
-- ==========================================

/-- Evaluate simple argument expressions. -/
def evalSimpleArgs : List Expr → YulState → Option (List Word256)
  | [], _ => some []
  | (.ident name) :: rest, st =>
      match VarStore.get? st.vars name with
      | some v => (evalSimpleArgs rest st).map (v :: ·)
      | none => none
  | (.nat n) :: rest, st => (evalSimpleArgs rest st).map (BitVec.ofNat 256 n :: ·)
  | (.bool b) :: rest, st => (evalSimpleArgs rest st).map ((if b then Word256.one else Word256.zero) :: ·)
  | _ :: _, _ => none

/-- Evaluate a simple expression. -/
def evalSimpleExpr (e : Expr) (st : YulState) : Option (Word256 × YulState) :=
  match e with
  | .ident name => (VarStore.get? st.vars name).map (·, st)
  | .nat n => some (BitVec.ofNat 256 n, st)
  | .bool b => some (if b then Word256.one else Word256.zero, st)
  | .call fn args =>
      match evalSimpleArgs args.toList st with
      | some argVals =>
          match evalPrimop fn argVals st with
          | some ([v], st') => some (v, st')
          | _ => none
      | none => none
  | _ => none

/-- Result of executing a simple block. -/
inductive SimpleResult where
  | ok : YulState → SimpleResult
  | revert : YulState → SimpleResult
  | error : SimpleResult
  deriving Inhabited

/-- Execute a flat block (no nesting into sub-blocks).
    For `if` bodies, only handles single-statement bodies (sufficient for SafeMath). -/
def execSimpleBlock : List Stmt → YulState → SimpleResult
  | [], st => .ok st
  | (.let_ name rhs) :: rest, st =>
      match evalSimpleExpr rhs st with
      | some (v, st') =>
          execSimpleBlock rest { st' with vars := VarStore.insert st'.vars name v }
      | none => .error
  | (.assign name rhs) :: rest, st =>
      match evalSimpleExpr rhs st with
      | some (v, st') =>
          execSimpleBlock rest { st' with vars := VarStore.insert st'.vars name v }
      | none => .error
  | (.if_ cond body) :: rest, st =>
      match evalSimpleExpr cond st with
      | some (v, st') =>
          if v != Word256.zero then
            -- Handle single-statement if bodies (covers SafeMath revert pattern)
            match body.toList with
            | [.revert args] => .revert st'
            | _ => .error  -- Complex bodies not handled by simple evaluator
          else execSimpleBlock rest st'
      | none => .error
  | (.revert _) :: _, st => .revert st
  | (.expr e) :: rest, st =>
      match evalSimpleExpr e st with
      | some (_, st') => execSimpleBlock rest st'
      | none => .error
  | _ :: _, _ => .error

/-- Simple total Hoare triple: execution must produce `.ok` (no fuel in simple evaluator,
    so reverts and errors are both rejected). -/
def SimpleHoareTriple (P : YulState → Prop) (stmts : List Stmt) (Q : YulState → Prop) : Prop :=
  ∀ (st : YulState), P st →
    match execSimpleBlock stmts st with | .ok st' => Q st' | _ => False

/-- Simple revert-aware triple: `.ok` must satisfy `Q`, `.revert` must satisfy `R`,
    evaluator errors are rejected. -/
def SimpleHoareRevertTriple (P : YulState → Prop) (stmts : List Stmt)
    (Q : YulState → Prop) (R : YulState → Prop) : Prop :=
  ∀ (st : YulState), P st →
    match execSimpleBlock stmts st with
    | .ok st' => Q st' | .revert st' => R st' | .error => False

/-- Partial simple triple (explicit opt-in): if execution succeeds, `Q` holds. -/
def PartialSimpleHoareTriple (P : YulState → Prop) (stmts : List Stmt)
    (Q : YulState → Prop) : Prop :=
  ∀ (st : YulState), P st →
    match execSimpleBlock stmts st with | .ok st' => Q st' | _ => True

theorem simple_consequence {P P' Q Q' : YulState → Prop} {stmts : List Stmt}
    (hPre : ∀ st, P' st → P st) (hPost : ∀ st, Q st → Q' st)
    (h : SimpleHoareTriple P stmts Q) : SimpleHoareTriple P' stmts Q' := by
  intro st hP'
  have := h st (hPre st hP')
  revert this
  match execSimpleBlock stmts st with
  | .ok st' => exact hPost st'
  | .revert _ => exact id
  | .error => exact id

theorem simple_skip {P : YulState → Prop} :
    SimpleHoareTriple P [] P := by
  intro st hP; exact hP

-- ==========================================
-- Helpers
-- ==========================================

def mkYulState (vars : List (String × Word256)) : YulState :=
  { evm := EVMState.default
    vars := vars
    funcs := FuncStore.empty }

def getVar (st : YulState) (name : String) : Option Word256 :=
  VarStore.get? st.vars name

end LeanSP.Verify
