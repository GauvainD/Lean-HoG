import Mathlib.Data.Matrix.Basic

import HoG.Tactic
import HoG.Graph
import HoG.Walk
import HoG.Invariant.ConnectedComponents
import HoG.Invariant.Hamiltonian.Definition
import LeanSAT

namespace HoG

open LeanSAT

/--
  For a given graph `g` encode finding a Hamiltonian path as a SAT problem.
-/
def Graph.hamiltonianPathEncodeToSAT (g : Graph) :
  Encode.EncCNF (Fin g.vertexSize → Fin g.vertexSize → IVar) :=
  open Encode.EncCNF in do
  let n := g.vertexSize
  if H : 0 < n then
    let varArr ←
      Array.initM n fun i =>
        Array.initM n fun j =>
          mkVar s!"x_{i},{j}"
    -- xᵢ,ⱼ represents vertex i appearing on the path at position j, as i,j ∈ {1,…,n}
    let vertexAtLoc (i : Fin n) (j : Fin n) := (varArr[i]!)[j]!
    -- ⋀ᵢ (⋁ⱼ (xᵢ,ⱼ)) ↔ every vertex appears somewhere on the path
    for i in List.fins n do
      let vars := (List.fins n).map (vertexAtLoc i) |>.toArray
      addClause (vars.map LitVar.mkPos)
    -- ⋀ᵢ (⋁ⱼ (xⱼ,ᵢ)) ↔ every position on the path is occupied by some vertex
    for i in List.fins n do
      let vars := (List.fins n).map (fun j => vertexAtLoc j i) |>.toArray
      addClause (vars.map LitVar.mkPos)
    -- ⋀_i ⋀_j≠k (¬xᵢ,ⱼ ∨ ¬xᵢ,ₖ) ↔ no vertex appears on the path more than once
    for i in List.fins n do
      for j in List.fins n do
        for k in List.fins n do
          if j ≠ k then
            let clause := #[(vertexAtLoc i j), (vertexAtLoc i k)].map LitVar.mkNeg
            addClause clause
    -- ⋀_i ⋀_j≠k (¬xⱼ,ᵢ ∨ ¬xₖ,ᵢ) ↔ no distinct vertices occupy the same position on the path
    for i in List.fins n do
      for j in List.fins n do
        for k in List.fins n do
          if j ≠ k then
            let clause := #[vertexAtLoc j i, vertexAtLoc k i].map LitVar.mkNeg
            addClause clause
    -- ⋀_(k < n) ⋀_((i,j) ∉ E) (¬xₖ,ᵢ ∨ ¬xₖ₊₁,ⱼ) ↔ non-adjacent vertices cannot be adjacent on the path
    for k in List.fins n do
      if k < n-1 then
        for i in List.fins n do
          for j in List.fins i do
            if (Edge.mk i j) ∉ g.edgeTree then
              let next : Fin n := ⟨ (k + 1) % n, by apply Nat.mod_lt; exact H⟩ -- TODO: hack, make nicer
              let clause := #[vertexAtLoc k i, vertexAtLoc next i].map LitVar.mkNeg
              addClause clause

    return vertexAtLoc
  else
    have h' : g.vertexSize = 0 := by simp_all
    return (by rw [h']; intro x; have := Fin.isLt x; contradiction)

/--
  For a given graph `g` encode finding a Hamiltonian cycle as a SAT problem.
-/
def Graph.hamiltonianCycleEncodeToSAT (g : Graph) :
  Encode.EncCNF (Fin g.vertexSize → Fin (g.vertexSize + 1) → IVar) :=
  open Encode.EncCNF in do
  let n := g.vertexSize
  if H : 0 < n then
    let varArr ←
      Array.initM n fun i =>
        Array.initM (n+1) fun j =>
          mkVar s!"x_{i},{j}"
    -- xᵢ,ⱼ represents vertex i appearing on the path at position j
    -- i ranges from 1 to n, j ranges from 1 to n+1 (as it needs to return to the first vertex)
    let vertexAtLoc (i : Fin n) (j : Fin (n + 1)) := (varArr[i]!)[j]!
    -- The cycle starts and end at vertex 0
    addClause #[LitVar.mkPos (vertexAtLoc ⟨0, H⟩ ⟨0, by simp [H]⟩)]
    addClause #[LitVar.mkPos (vertexAtLoc ⟨0, H⟩ n)]
    -- ⋀ᵢ (⋁ⱼ (xᵢ,ⱼ)) ↔ every vertex appears somewhere on the path
    -- we don't need to consider the last position of the path
    for i in List.fins n do
      let vars := (List.fins n).map (vertexAtLoc i) |>.toArray
      addClause (vars.map LitVar.mkPos)
    -- ⋀ᵢ (⋁ⱼ (xⱼ,ᵢ)) ↔ every position on the path is occupied by some vertex
    for i in List.fins n do
      let vars := (List.fins n).map (fun j => vertexAtLoc j i) |>.toArray
      addClause (vars.map LitVar.mkPos)
    -- ⋀_i ⋀_j≠k (¬xᵢ,ⱼ ∨ ¬xᵢ,ₖ) ↔ no vertex appears on the path more than once
    -- except vertex 0 on the first and last place
    for i in List.fins n do
      for j in List.fins n do
        for k in List.fins n do
          if j ≠ k then
            let clause := #[(vertexAtLoc i j), (vertexAtLoc i k)].map LitVar.mkNeg
            addClause clause
    -- ⋀_i ⋀_j≠k (¬xⱼ,ᵢ ∨ ¬xₖ,ᵢ) ↔ no distinct vertices occupy the same position on the path
    for i in List.fins (n + 1) do
      for j in List.fins n do
        for k in List.fins n do
          if j ≠ k then
            let clause := #[vertexAtLoc j i, vertexAtLoc k i].map LitVar.mkNeg
            addClause clause
    -- ⋀_(k < n) ⋀_((i,j) ∉ E) (¬xₖ,ᵢ ∨ ¬xₖ₊₁,ⱼ) ↔ non-adjacent vertices cannot be adjacent on the path
    for k in List.fins n do
      if k < n-1 then
        for i in List.fins n do
          for j in List.fins i do
            if (Edge.mk i j) ∉ g.edgeTree then
              let next : Fin n := ⟨ (k + 1) % n, by apply Nat.mod_lt; exact H⟩ -- TODO: hack, make nicer
              let clause := #[vertexAtLoc k i, vertexAtLoc next i].map LitVar.mkNeg
              addClause clause
    return vertexAtLoc
  else
    have h' : g.vertexSize = 0 := by simp_all
    return (by rw [h']; intro x; have := Fin.isLt x; contradiction)

/--
  Given a list of vertices of a graph, try to construct a `Path` in the graph from them.
  If the construction fails, return `none`.
-/
def buildPath {g : Graph} : Option (List (g.vertex)) → Option ((u v : g.vertex) ×' Path g u v)
  | none => none
  | some [] => none
  | some (v :: vs) =>
    let rec fold (first last : g.vertex) (p : Path g first last) :
      List (g.vertex) → Option ((u v : g.vertex) ×' Path g u v)
    | [] => some ⟨first, last, p⟩
    | v :: vs =>
      if h : g.adjacent last v then
        let w := Walk.right p.walk h
        if h' : Walk.isPath w = true then
          fold first v ⟨w, h'⟩ vs
        else
          none
      else
        none
    fold v v (Path.trivialPath v) vs

/--
  Given a list of vertices of a graph, try to construct a `Cycle` in the graph from them.
  If the construction fails, return `none`.
-/
def buildCycle {g : Graph} : Option (List (g.vertex)) → Option ((u : g.vertex) ×' Cycle g u)
  | none => none
  | some [] => none
  | some [v] =>
    let walk := Walk.trivial v
    some ⟨v, walk, by simp [List.all_distinct, Walk.vertices]⟩
  | some (v₁ :: v₂ :: vs) =>
    let rec fold (first last : g.vertex) (p : Path g first last) :
      List (g.vertex) → Option ((u v : g.vertex) ×' Path g u v)
    | [] => some ⟨first, last, p⟩
    | v :: vs =>
      if h : g.adjacent last v then
        let w := Walk.right p.walk h
        if h' : Walk.isPath w = true then
          fold first v ⟨w, h'⟩ vs
        else
          none
      else
        none
    let path := fold v₂ v₂ (Path.trivialPath v₂) vs
    match path with
    | none => none
    | some ⟨u,v,p⟩ =>
      if h : u = v₂ ∧ v = v₁ ∧ g.adjacent v₁ v₂ then
        have u_eq_v₂ := h.1
        have v_eq_v₁ := h.2.1
        let w : ClosedWalk g v₁ := Walk.left h.2.2 (u_eq_v₂ ▸ v_eq_v₁ ▸ p.walk)
        if cyc : w.isCycle then
        some ⟨ v₁,
          { cycle := w,
            isCycle := by
              subst u_eq_v₂
              subst v_eq_v₁
              exact cyc
          }⟩
        else
          none
      else
        none

/--
  Given a graph `g`, encode the problem of finding a Hamiltonian path as a SAT
  problem and then from the solution construct a `HamiltonianPath` in the graph.
-/
def findHamiltonianPath [Solver IO] (g : Graph) :
  IO (Option ((u v : g.vertex) ×' HamiltonianPath u v)) := do
  let (vertexAtLoc, enc) := Encode.EncCNF.new! (g.hamiltonianPathEncodeToSAT)
  -- IO.println s!"{enc}"
  match ← Solver.solve enc.toFormula with
  | .error =>
    IO.println "error"
    return none
  | .unsat =>
    IO.println "unsat"
    return none
  | .sat assn =>
    if h : 0 < g.vertexSize then
      let mut path : Array (g.vertex) := Array.mkArray g.vertexSize ⟨0, h⟩
      for i in List.fins g.vertexSize do
        for j in List.fins g.vertexSize do
          match assn.find? (vertexAtLoc i j) with
          | none => panic! "wtf"
          | some true =>
            path := path.set! j i
          | some false =>
            path := path
      let p := (buildPath (some path.toList))
      match p with
      | none => return none
      | some ⟨u,v,p⟩ =>
        if h' : p.isHamiltonian then
          return some ⟨u,v,p,h'⟩
        else
          return none
    else
      return none

/--
  Given a graph `g`, encode the problem of finding a Hamiltonian cycle as a SAT
  problem and then from the solution construct a `HamiltonianCycle` in the graph.
-/
def findHamiltonianCycle [Solver IO] (g : Graph) :
  IO (Option ((u : g.vertex) ×' HamiltonianCycle g u)) := do
  let (vertexAtLoc, enc) := Encode.EncCNF.new! (g.hamiltonianCycleEncodeToSAT)
  match ← Solver.solve enc.toFormula with
  | .error =>
    IO.println "error"
    return none
  | .unsat =>
    IO.println "unsat"
    return none
  | .sat assn =>
    if h : 0 < g.vertexSize then
      let mut path : Array (g.vertex) := Array.mkArray (g.vertexSize + 1) ⟨0, by simp [h]⟩
      for i in List.fins g.vertexSize do
        for j in List.fins (g.vertexSize + 1) do
          let v := vertexAtLoc i j
          match assn.find? v with
          | none => panic! s!"no assignment for ({i}, {j}) → {v}"
          | some true =>
            path := path.set! j i
          | some false =>
            path := path
      let c := (buildCycle (some path.toList))
      match c with
      | none => return none
      | some ⟨u,c⟩ =>
        if h' : c.isHamiltonian then
          return some ⟨u, c, h'⟩
        else
          return none
    else
      return none

end HoG