import Std
import Std.Data.RBMap.Basic
import Std.Data.RBMap.Lemmas
import LeanHoG.Graph
import Qq
import Mathlib.Tactic.Linarith

namespace LeanHoG

@[reducible]
def Graph.connected {G : Graph} : G.vertex → G.vertex → Prop := EqvGen G.adjacent

-- Neighbors are connected
lemma Graph.connected_of_adjacent {G : Graph} {u v : G.vertex} : G.adjacent u v → G.connected u v :=
  EqvGen.rel u v

-- Equal vertices are connected
lemma Graph.connected_of_eq {G : Graph} (u v : G.vertex) : u = v → G.connected u v := by
  intro eq
  rw [eq]
  apply EqvGen.refl

-- Connectedness is transitive
@[reducible]
lemma Graph.connected_trans {G : Graph} (u v w : G.vertex) :
  G.connected u v → G.connected v w → G.connected u w :=
  EqvGen.trans u v w

lemma Graph.connected_adj {G : Graph} (u v w : G.vertex) :
  G.adjacent u v → G.connected v w → G.connected u w := by
  intros uv vw
  apply Graph.connected_trans (v := v)
  · apply EqvGen.rel ; assumption
  · exact vw

@[reducible]
lemma Graph.connected_symm {G : Graph} (u v : G.vertex) :
  G.connected u v → G.connected v u :=
  EqvGen.symm u v

-- Connected components of a graph
class ConnectedComponents (G : Graph) : Type :=
  val : Nat -- number of components
  component : G.vertex → Fin val -- assigns a component to each vertex
  componentInhabited : ∀ (i : Fin val), ∃ u, component u = i -- each component is inhabited
  correct : ∀ u v, component u = component v ↔ G.connected u v

def Graph.numberOfConnectedComponents (G : Graph) [C : ConnectedComponents G] : Nat := C.val
def Graph.component (G : Graph) [C : ConnectedComponents G] (v : G.vertex) : Nat := C.component v

-- A certificate for connected components:
class ConnectedComponentsCertificate (G : Graph) : Type :=
  -- number of components
  val : Nat
  -- assignment of components to each vertex
  component : G.vertex → Fin val
  -- the endpoints of an edge are in the same component
  componentEdge : G.edgeSet.all (fun e => component (G.fst e) = component (G.snd e)) = true
  -- for each component, a chosen representative, called "the component root"
  root : Fin val → G.vertex
  -- each root is in the correct component
  rootCorrect : ∀ i, component (root i) = i

  -- For each component we give a directed spanning tree rooted at its component root.
  -- We call this tree the "component tree". All the component trees form a spanning forest.

  -- for each vertex that is not a root, the next step of the path leading to its root
  -- (and roots map to themselves)
  next : G.vertex → G.vertex
  -- To ensure that next is cycle-free, we witness the fact that it takes us closer to the root.
  -- the distance of a vertex to its component root
  distToRoot : G.vertex → Nat
  -- a root is at distance 0 from itself
  distRootZero : ∀ (i : Fin val), distToRoot (root i) = 0
  -- a vertex is a root if its distance to a root is 0
  distZeroRoot : ∀ (v : G.vertex), distToRoot v = 0 → v = root (component v)
  -- a root is a fixed point of next
  nextRoot : ∀ i, next (root i) = root i
  -- each vertex that is not a root is adjacent to the next one
  nextAdjacent : ∀ v, 0 < distToRoot v → G.adjacent v (next v)
  -- distance to root decreases as we travel along the path given by next
  distNext : ∀ v, 0 < distToRoot v → distToRoot (next v) < distToRoot v

def ConnectedComponentsCertificate.componentEdge' {G : Graph} [C : ConnectedComponentsCertificate G] :
  ∀ (e : G.edge), component (G.fst e.val) = component (G.snd e.val) := by
  intro e
  have compEdge := C.componentEdge
  unfold Std.RBSet.all at compEdge
  rw [Std.RBNode.all_iff] at compEdge
  rw [Std.RBNode.All_def] at compEdge
  have belongs : e.1 ∈ G.edgeSet.1 := by
    rw [← edge_in_node]
    rw [← Std.RBSet.contains_iff]
    exact e.property
  apply compEdge at belongs
  apply of_decide_eq_true at belongs
  apply belongs

-- adjacent vertices are in the same component
lemma ConnectedComponentsCertificate.componentAdjacent {G} [C : ConnectedComponentsCertificate G] :
  ∀ u v, G.adjacent u v → component u = component v := by
  intros u v uv
  apply ltByCases u v
  · intro cmp
    let e := G.adjacentEdge uv
    have r := Graph.adj_impl_ex_edge
    specialize r G u v e uv
    have t : e = Graph.adjacentEdge uv := by rfl
    specialize r cmp t
    have compo := C.componentEdge' e
    obtain ⟨left,right⟩ := r
    rw [left, right] at compo
    assumption
  · intro cmp
    unfold Graph.adjacent at uv
    unfold Graph.badjacent at uv
    simp [cmp]
  · intro cmp
    apply Graph.symmetricAdjacent at uv
    let e := G.adjacentEdge uv
    have r := Graph.adj_impl_ex_edge
    specialize r G v u e uv
    have t : e = Graph.adjacentEdge uv := by rfl
    specialize r cmp t
    have compo := C.componentEdge' e
    obtain ⟨left,right⟩ := r
    rw [left, right] at compo
    rw [eq_comm]
    assumption

-- the root of the component of a given vertex
@[simp]
def ConnectedComponentsCertificate.rootOf {G} [C : ConnectedComponentsCertificate G] : G.vertex → G.vertex :=
  (fun (v : G.vertex) => C.root (C.component v))

def ConnectedComponentsCertificate.rootOfNext {G} [C : ConnectedComponentsCertificate G] (v : G.vertex) :
  C.rootOf (C.next v) = C.rootOf v := by
  apply congrArg C.root
  cases Nat.eq_zero_or_pos (C.distToRoot v)
  case inl eq =>
    apply congrArg
    apply Eq.symm
    rw [C.distZeroRoot v eq]
    apply Eq.symm
    apply C.nextRoot
  case inr _ =>
    apply Eq.symm
    apply C.componentAdjacent
    apply C.nextAdjacent
    assumption

-- Auxuliary induction principle (think of f x as a "height" of x)
theorem heightInduction {α : Type} (f : α → Nat) (P : α → Prop) :
  (∀ x, (∀ y, f y < f x → P y) → P x) → ∀ x, P x := by
  intros ind a
  let Q := fun n => ∀ a, f a = n → P a
  have Qstep : ∀ n, (∀ m, m < n → Q m) → Q n
  { intros n h a ξ
    apply (ind a)
    intros b fb_lt_fa
    rw [ξ] at fb_lt_fa
    apply (h (f b)) fb_lt_fa
    rfl
  }
  exact @WellFounded.fix _ Q Nat.lt (Nat.lt_wfRel.wf) Qstep (f a) a rfl

-- Given a component certificate, each vertex is connected to its root
lemma connectedToRoot (G : Graph) [C : ConnectedComponentsCertificate G] :
  ∀ v, G.connected v (C.rootOf v) := by
  apply heightInduction C.distToRoot (fun v => G.connected v (C.rootOf v))
  intros v ih
  cases Nat.eq_zero_or_pos (C.distToRoot v)
  · apply G.connected_of_eq
    apply C.distZeroRoot v
    assumption
  · apply G.connected_adj v (C.next v) (C.rootOf v)
    · apply C.nextAdjacent ; assumption
    · rw [Eq.symm (C.rootOfNext v)]
      apply ih
      apply C.distNext
      assumption

-- From a components certificate we can derive the connected components
instance {G : Graph} [C : ConnectedComponentsCertificate G] : ConnectedComponents G :=
  { val := C.val ,
    component := C.component,
    componentInhabited := by { intro i ; exists (C.root i) ; apply C.rootCorrect },
    correct := by
      intros u v
      apply Iff.intro
      · intro eq
        apply G.connected_trans u (C.rootOf u) v
        · apply connectedToRoot
        · apply Graph.connected_symm
          unfold ConnectedComponentsCertificate.rootOf
          rw [eq]
          apply connectedToRoot
      · intro uv
        induction uv
        case mpr.rel x y xy => apply C.componentAdjacent ; assumption
        case mpr.refl => rfl
        case mpr.symm => apply Eq.symm ; assumption
        case mpr.trans eq₁ eq₂ => apply Eq.trans eq₁ eq₂
  }

-- A derived invariant: connectedness

def Graph.is_connected (G : Graph) := ∀ (u v : G.vertex), G.connected u v

theorem Graph.zero_component_connected (G: Graph) [C : ConnectedComponents G]: C.val = 0 → ∀ (u v : G.vertex), G.connected u v := by
  intro val_zero u v
  rw [← C.correct]
  let cu := C.component u
  simp [val_zero] at cu
  have neg : cu.val < 0 := cu.isLt
  contradiction


theorem Graph.one_component_connected (G: Graph) [C : ConnectedComponents G]: C.val = 1 → ∀ (u v : G.vertex), G.connected u v := by
  intro val_one u v
  have same_comp : C.component u = C.component v := by
    let cu := C.component u
    have cu_eq : cu = C.component u := by rfl
    let cv := C.component v
    have comp_eq_zero : ∀ v : (Fin C.val), v.val = 0 := by
      intro v
      rw [← Nat.lt_one_iff]
      rw [← val_one]
      exact v.isLt
    have cv_eq : cv = C.component v := by rfl
    rw [← cu_eq, ← cv_eq]
    rw [← Fin.val_eq_val]
    rw [comp_eq_zero, comp_eq_zero]
  rw [← C.correct]
  exact same_comp

theorem Graph.component_le_1_connected (G: Graph) [C : ConnectedComponents G]: C.val <= 1 → ∀ (u v : G.vertex), G.connected u v := by
  rw [le_iff_lt_or_eq]
  intro ineq
  cases ineq with
  | inl lt_one =>
    rw [Nat.lt_one_iff] at lt_one
    exact Graph.zero_component_connected G lt_one
  | inr eq_one =>
    exact Graph.one_component_connected G eq_one


theorem Graph.component_gt_1_connected (G: Graph) [C : ConnectedComponents G]: C.val > 1 → ¬ ∀ (u v : G.vertex), G.connected u v := by
  intro gt_one
  intro connected
  let root_index_zero : Fin C.val := Fin.mk 0 (by linarith)
  let root_index_one : Fin C.val := Fin.mk 1 (by linarith)
  have root_index_zero_zero : root_index_zero.val = 0 := by rfl
  have root_index_one_one : root_index_one.val = 1 := by rfl
  have diff_indices : root_index_zero.val ≠ root_index_one.val := by simp [root_index_zero_zero, root_index_one_one]
  rw [Fin.val_ne_iff] at diff_indices
  have exist_u : ∃ u : G.vertex, C.component u = root_index_zero := C.componentInhabited root_index_zero
  have exist_v : ∃ v : G.vertex, C.component v = root_index_one := C.componentInhabited root_index_one
  obtain ⟨u, prop_u⟩ := exist_u
  obtain ⟨v, prop_v⟩ := exist_v
  specialize connected u v
  rw [← C.correct] at connected
  rw [prop_u, prop_v] at connected
  contradiction

instance Graph.decide_connectivity (G : Graph) [C : ConnectedComponents G] : Decidable G.is_connected :=
  if e : C.val <= 1 then
    isTrue (G.component_le_1_connected e)
  else
    isFalse (G.component_gt_1_connected (by linarith))

end LeanHoG
