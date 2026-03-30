import HeytingLean.LoF.LeanKernel.FullKernelSKY
import HeytingLean.LoF.LeanKernel.BundleFaithfulness
import HeytingLean.LoF.LeanKernel.ScottCorrectness

/-!
# FullKernelSKYCorrectness (Phase 3 — Kernel Assurance Bridge)

States the correspondence between the SKY-compiled kernel algorithms
(`FullKernelSKY.whnfFullSky`, etc.) and the staged reference algorithms
(`WHNF.whnfWithDelta`, `DefEq.isDefEqWithDelta`, `Infer.infer?`, `Infer.check`).

## Type bridge

The staged algorithms work over `SExpr = Expr Nat Nat Nat Nat`.
The SKY compilation works over `E = Expr Nat Unit Unit Unit`.
On the supported fragment (no metavariables), these are isomorphic via
`Expr.map id (fun _ => ()) (fun _ => ()) (fun _ => ())`.

We define the correspondence at the `SExpr` level and project to `E` for
SKY compilation.

## Current state

This module defines the correspondence predicates. Proofs proceed in
dependency order: 3a (WHNF) → 3b (DefEq) → 3c (Infer) → 3d (Check).
-/

namespace HeytingLean
namespace LoF
namespace LeanKernel

namespace FullKernelSKYCorrectness

open HeytingLean.LoF
open HeytingLean.LoF.Combinators
open HeytingLean.LoF.LeanKernel
open HeytingLean.LoF.LeanKernel.BundleFaithfulness

/-! ## Type projection: SExpr → E -/

/-- Project `SExpr` (Nat metavar slots) to `E` (Unit metavar slots).
On supported expressions (no metavars), this is an isomorphism. -/
def toE (e : SExpr) : FullKernelSKY.E :=
  Expr.map id (fun _ => ()) (fun _ => ()) (fun _ => ()) e

/-- Compile an `SExpr` to a SKY combinator via Scott encoding + bracket abstraction. -/
def compileSExpr? (e : SExpr) : Option Comb :=
  FullKernelSKY.compileExprNatUnit? (toE e)

/-! ## Phase 3a: WHNF tag correspondence

The weakest useful form: after WHNF, the top constructor tag agrees. -/

/-- WHNF tag correspondence: the top-level constructor of the SKY-reduced
WHNF result matches that of the staged WHNF result, when both are decoded. -/
def WhnfTagAgrees
    (compiled : FullKernelSKY.FullCompiled)
    (cfg : Infer.Config Nat Nat Nat Nat)
    (envC rulesC : Comb)
    (fuelWhnf fuelReduce : Nat)
    (e : SExpr) : Prop :=
  let stagedResult := WHNF.whnfWithDelta cfg.constValue? cfg.iotaRules fuelWhnf e
  let skyTag := FullKernelSKY.runWhnfFullTagFuelWith
    compiled fuelWhnf fuelReduce envC rulesC (toE e)
  let stagedTag := match compileSExpr? stagedResult with
    | some c => Lean4LeanSKY.Decode.exprTagFuel fuelReduce c
    | none => none
  skyTag = stagedTag

/-! ## Phase 3b: DefEq correspondence -/

/-- DefEq correspondence: the SKY-compiled definitional equality check
agrees with the staged `isDefEqWithDelta`. -/
def DefEqAgrees
    (compiled : FullKernelSKY.FullCompiled)
    (cfg : Infer.Config Nat Nat Nat Nat)
    (envC rulesC : Comb)
    (fuel fuelReduce : Nat)
    (e1 e2 : SExpr) : Prop :=
  let stagedResult := DefEq.isDefEqWithDelta cfg.constValue? cfg.iotaRules fuel e1 e2
  let skyResult := FullKernelSKY.runIsDefEqFullFuelWith
    compiled fuel fuelReduce envC rulesC (toE e1) (toE e2)
  skyResult = some stagedResult

/-! ## Phase 3c: Infer tag correspondence -/

/-- Infer tag correspondence: the top-level constructor of the SKY-reduced
infer result matches that of the staged infer result. -/
def InferTagAgrees
    (compiled : FullKernelSKY.FullCompiled)
    (cfg : Infer.Config Nat Nat Nat Nat)
    (envC rulesC : Comb)
    (fuel fuelReduce : Nat)
    (e : SExpr) : Prop :=
  let stagedResult := Infer.infer? cfg fuel (Infer.Ctx.empty) e
  let skyTag := FullKernelSKY.runInferFullTagFuelWith
    compiled fuel fuelReduce envC rulesC (toE e)
  let stagedTag := match stagedResult with
    | some ty => match compileSExpr? ty with
      | some c => Lean4LeanSKY.Decode.exprTagFuel fuelReduce c
      | none => none
    | none => none
  skyTag = stagedTag

/-! ## Phase 3d: Check correspondence -/

/-- Check correspondence: the SKY-compiled type-check agrees with staged `check`. -/
def CheckAgrees
    (compiled : FullKernelSKY.FullCompiled)
    (cfg : Infer.Config Nat Nat Nat Nat)
    (envC rulesC : Comb)
    (fuel fuelReduce : Nat)
    (e ty : SExpr) : Prop :=
  let stagedResult := Infer.check cfg fuel (Infer.Ctx.empty) e ty
  let skyResult := FullKernelSKY.runCheckFullFuelWith
    compiled fuel fuelReduce envC rulesC (toE e) (toE ty)
  skyResult = some stagedResult

/-! ## Structural lemmas for toE -/

/-- `toE` preserves `.sort` (universe levels have their Param/Meta erased to Unit). -/
theorem toE_sort (u : SLevel) :
    toE (.sort u) = .sort (ULevel.map (fun _ => ()) (fun _ => ()) u) := by
  simp [toE, Expr.map]

/-- `toE` preserves `.bvar`. -/
theorem toE_bvar (n : Nat) : toE (.bvar n) = .bvar n := by
  simp [toE, Expr.map]

/-- `toE` preserves `.app`. -/
theorem toE_app (f a : SExpr) : toE (.app f a) = .app (toE f) (toE a) := by
  simp [toE, Expr.map]

/-- `toE` preserves `.lam`. -/
theorem toE_lam (bn : Nat) (bi : BinderInfo) (ty body : SExpr) :
    toE (.lam bn bi ty body) = .lam bn bi (toE ty) (toE body) := by
  simp [toE, Expr.map]

/-- `toE` preserves `.forallE`. -/
theorem toE_forallE (bn : Nat) (bi : BinderInfo) (ty body : SExpr) :
    toE (.forallE bn bi ty body) = .forallE bn bi (toE ty) (toE body) := by
  simp [toE, Expr.map]

/-! ## Phase 3 spot-checks: `native_decide`-verified correspondence on small terms

These are executable witnesses: the compiled SKY kernel produces the same
result as the staged reference kernel on specific inputs.  Each theorem is
proved by `native_decide` (compiles to C, runs natively). -/

/-- WHNF tag for `.sort .zero`: SKY-compiled WHNF agrees with tag "sort". -/
def whnfSortZeroCheckBool : Bool :=
  match FullKernelSKY.compileFull?, FullKernelSKY.emptyEnvComb?,
        FullKernelSKY.emptyRulesComb? with
  | some compiled, some envC, some rulesC =>
    FullKernelSKY.runWhnfFullTagFuelWith compiled 10 2000 envC rulesC
      (.sort .zero : FullKernelSKY.E) == some "sort"
  | _, _, _ => false

theorem whnf_sort_zero_spot : whnfSortZeroCheckBool = true := by native_decide

/-- WHNF tag for `.bvar 0`: already in WHNF, tag is "bvar". -/
def whnfBvarCheckBool : Bool :=
  match FullKernelSKY.compileFull?, FullKernelSKY.emptyEnvComb?,
        FullKernelSKY.emptyRulesComb? with
  | some compiled, some envC, some rulesC =>
    FullKernelSKY.runWhnfFullTagFuelWith compiled 10 2000 envC rulesC
      (.bvar 0 : FullKernelSKY.E) == some "bvar"
  | _, _, _ => false

theorem whnf_bvar_spot : whnfBvarCheckBool = true := by native_decide

/-- DefEq: `.sort .zero ≡ .sort .zero` — both sides agree `true`. -/
def defeqSortSortCheckBool : Bool :=
  match FullKernelSKY.compileFull?, FullKernelSKY.emptyEnvComb?,
        FullKernelSKY.emptyRulesComb? with
  | some compiled, some envC, some rulesC =>
    FullKernelSKY.runIsDefEqFullFuelWith compiled 10 2000 envC rulesC
      (.sort .zero) (.sort .zero) == some true
  | _, _, _ => false

theorem defeq_sort_sort_spot : defeqSortSortCheckBool = true := by native_decide

/-- DefEq: `.sort .zero ≢ .bvar 0` — both sides agree `false`. -/
def defeqSortBvarCheckBool : Bool :=
  match FullKernelSKY.compileFull?, FullKernelSKY.emptyEnvComb?,
        FullKernelSKY.emptyRulesComb? with
  | some compiled, some envC, some rulesC =>
    FullKernelSKY.runIsDefEqFullFuelWith compiled 10 2000 envC rulesC
      (.sort .zero) (.bvar 0) == some false
  | _, _, _ => false

theorem defeq_sort_bvar_spot : defeqSortBvarCheckBool = true := by native_decide

/-! ## Phase 3c spot-check: Infer -/

/-- Infer tag for `.sort .zero` in empty context: type is `.sort (.succ .zero)`, tag "sort". -/
def inferSortZeroCheckBool : Bool :=
  match FullKernelSKY.compileFull?, FullKernelSKY.emptyEnvComb?,
        FullKernelSKY.emptyRulesComb? with
  | some compiled, some envC, some rulesC =>
    FullKernelSKY.runInferFullTagFuelWith compiled 10 2000 envC rulesC
      (.sort .zero : FullKernelSKY.E) == some "sort"
  | _, _, _ => false

theorem infer_sort_zero_spot : inferSortZeroCheckBool = true := by native_decide

/-! ## Phase 3d spot-check: Check -/

/-- Check `.sort .zero` against `.sort (.succ .zero)` in empty context: should be `true`. -/
def checkSortZeroCheckBool : Bool :=
  match FullKernelSKY.compileFull?, FullKernelSKY.emptyEnvComb?,
        FullKernelSKY.emptyRulesComb? with
  | some compiled, some envC, some rulesC =>
    FullKernelSKY.runCheckFullFuelWith compiled 10 2000 envC rulesC
      (.sort .zero : FullKernelSKY.E) (.sort (.succ .zero)) == some true
  | _, _, _ => false

theorem check_sort_zero_spot : checkSortZeroCheckBool = true := by native_decide

/-- Check `.sort .zero` against `.bvar 0`: should be `false` (type mismatch). -/
def checkSortBvarMismatchCheckBool : Bool :=
  match FullKernelSKY.compileFull?, FullKernelSKY.emptyEnvComb?,
        FullKernelSKY.emptyRulesComb? with
  | some compiled, some envC, some rulesC =>
    FullKernelSKY.runCheckFullFuelWith compiled 10 2000 envC rulesC
      (.sort .zero : FullKernelSKY.E) (.bvar 0) == some false
  | _, _, _ => false

theorem check_sort_bvar_mismatch_spot : checkSortBvarMismatchCheckBool = true := by native_decide

end FullKernelSKYCorrectness

/-! ## Phase 4: End-to-End Assurance Bridge

Composes Phases 1-3 into a single end-to-end predicate: for a supported,
faithful bundle with unique names, the SKY-compiled kernel agrees with the
staged reference kernel on all obligations. -/

namespace EndToEndAssurance

open HeytingLean.LoF.LeanKernel
open HeytingLean.LoF.LeanKernel.BundleFaithfulness
open HeytingLean.LoF.LeanKernel.FullKernelSKYCorrectness

/-- A bundle has *unique* constant names. -/
def UniqueNames (b : ArbitraryLeanKernelBundle) : Prop :=
  ∀ c1 ∈ b.envConsts, ∀ c2 ∈ b.envConsts, c1.nameId = c2.nameId → c1 = c2

/-- Phase 2 is fully satisfied: environment types and values are preserved. -/
def Phase2Satisfied (b : ArbitraryLeanKernelBundle) : Prop :=
  EnvPreservesTypes b ∧ EnvPreservesValues b

/-- Phase 2 follows from unique names (composition of Phase 2 theorems). -/
theorem phase2_of_unique_names (b : ArbitraryLeanKernelBundle)
    (huniq : UniqueNames b) :
    Phase2Satisfied b :=
  ⟨envPreservesTypes_of_unique_names b huniq,
   envPreservesValues_of_unique_names b huniq⟩

/-- Phase 3 tag agreement for all WHNF obligations: each `.whnf` obligation
in the bundle has its SKY tag match the staged tag. -/
def Phase3WhnfObligationsAgree
    (b : ArbitraryLeanKernelBundle)
    (compiled : FullKernelSKY.FullCompiled)
    (envC rulesC : Comb)
    (fuelWhnf fuelReduce : Nat) : Prop :=
  ∀ o ∈ b.obligations, o.kind = .whnf →
    WhnfTagAgrees compiled (bundleConfig b) envC rulesC fuelWhnf fuelReduce o.expr

/-- Phase 3 agreement for all DefEq obligations. -/
def Phase3DefEqObligationsAgree
    (b : ArbitraryLeanKernelBundle)
    (compiled : FullKernelSKY.FullCompiled)
    (envC rulesC : Comb)
    (fuel fuelReduce : Nat) : Prop :=
  ∀ o ∈ b.obligations, o.kind = .defeq →
    ∀ e2 ∈ o.expr2?,
      DefEqAgrees compiled (bundleConfig b) envC rulesC fuel fuelReduce o.expr e2

/-- The **end-to-end** assurance predicate: a bundle is *assured* when
all phases hold simultaneously. -/
structure BundleAssured (b : ArbitraryLeanKernelBundle) (fuel fuelReduce : Nat) : Prop where
  /-- Phase 1: bundle is supported (no metavars, no overflow). -/
  supported : SupportedBundle b
  /-- Phase 1+: bundle is faithful at given fuel. -/
  faithful : FaithfulBundle b fuel
  /-- Phase 2: environment is faithfully reconstructed. -/
  envPreserved : Phase2Satisfied b
  /-- Phase 3a: WHNF tag correspondence on obligations. -/
  whnfAgrees : ∀ compiled envC rulesC,
    Phase3WhnfObligationsAgree b compiled envC rulesC fuel fuelReduce
  /-- Phase 3b: DefEq correspondence on obligations. -/
  defeqAgrees : ∀ compiled envC rulesC,
    Phase3DefEqObligationsAgree b compiled envC rulesC fuel fuelReduce

/-- **Main composition lemma**: Phase 2 is derivable from uniqueness alone.
This reduces the end-to-end assurance to: supported + faithful + unique names +
Phase 3 correspondence (the hard part). -/
theorem bundle_assured_of_unique_and_phase3
    (b : ArbitraryLeanKernelBundle) (fuel fuelReduce : Nat)
    (hsup : SupportedBundle b)
    (hfaith : FaithfulBundle b fuel)
    (huniq : UniqueNames b)
    (hwhnf : ∀ compiled envC rulesC,
      Phase3WhnfObligationsAgree b compiled envC rulesC fuel fuelReduce)
    (hdefeq : ∀ compiled envC rulesC,
      Phase3DefEqObligationsAgree b compiled envC rulesC fuel fuelReduce) :
    BundleAssured b fuel fuelReduce :=
  { supported := hsup
    faithful := hfaith
    envPreserved := phase2_of_unique_names b huniq
    whnfAgrees := hwhnf
    defeqAgrees := hdefeq }

end EndToEndAssurance

end LeanKernel
end LoF
end HeytingLean
