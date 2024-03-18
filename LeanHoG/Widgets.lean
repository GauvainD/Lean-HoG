import LeanHoG.Invariant.Hamiltonicity.Basic
import LeanHoG.Invariant.Hamiltonicity.SatEncoding
import Lean
import LeanSAT
import Qq

open Lean Widget Elab Command Term Meta LeanSAT Qq
namespace LeanHoG

@[widget_module]
def visualize : Widget.Module where
  javascript := include_str ".." / "build" /"js" / "graphVisualization.js"

def Graph.toVisualizationFormat : Graph → Json := fun G =>
  Json.mkObj [
    ("vertexSize", G.vertexSize),
    ("edgeList", Lean.toJson G.edgeTree.toList)
  ]

def HamiltonianPath.toVisualizationFormat (G : Graph) :
  HamiltonianPath G → Json := fun hp =>
  Json.mkObj [
    ("vertexSize", G.vertexSize),
    ("edgeList", Lean.toJson G.edgeTree.toList),
    ("hamiltonianPath", Lean.toJson hp.path.vertices)
  ]

instance widgetInstance : Solver IO := (Solver.Impl.DimacsCommand "kissat")

def IO.unsafeGet {α} [Inhabited α] (val : IO α) : α := Id.run do
  let .ok val' s := val.run () | return default
  return val'

def HamiltonianPath.toVisualizationFormat? (G : Graph) : IO Json := do
  let hp ← tryFindHamiltonianPath G
  match hp with
  | some hp =>
    return Json.mkObj [
      ("vertexSize", G.vertexSize),
      ("edgeList", Lean.toJson G.edgeTree.toList),
      ("hamiltonianPath", Lean.toJson hp.path)
    ]
  | none => return Json.null

/-- Use `#visualizeGraph G` to render a visualization of the graph `G` in the panel widget.
This is done using the `https://js.cytoscape.org/` javascript library. -/
syntax (name := visualizeGraphCmd) "#visualizeGraph " term : command

@[command_elab visualizeGraphCmd]
def elabVisualizeGraphCmd : CommandElab
  | stx@`(#visualizeGraph $g) => liftTermElabM do
    let wi : Expr ←
      elabWidgetInstanceSpecAux (mkIdent `visualize) (← ``((Graph.toVisualizationFormat $g)))
    let wi : WidgetInstance ← evalWidgetInstance wi
    savePanelWidgetInfo wi.javascriptHash wi.props stx
  | _ => throwUnsupportedSyntax

def buildVisualizationInstance (G : Graph) [inst : HamiltonianPath G] : Json := HamiltonianPath.toVisualizationFormat G inst

syntax (name := visualizeHamiltonianPathCmd) "#visualizeHamiltonianPath" term : command

@[command_elab visualizeHamiltonianPathCmd]
unsafe def elabVisualizeHamiltonianPathCmd : CommandElab
  | stx@`(#visualizeHamiltonianPath $g) => liftTermElabM do
    let gg : Expr ← elabTerm g none
    let hpInst ← mkAppM ``HamiltonianPath #[gg]
    if let .some _ ← synthInstance? hpInst then
      let wi : Expr ← elabWidgetInstanceSpecAux (mkIdent `visualize) (← ``(buildVisualizationInstance $g))
      let wi : WidgetInstance ← evalWidgetInstance wi
      savePanelWidgetInfo wi.javascriptHash wi.props stx
    else
      IO.println "Hamiltonian path for graph not found."

  | _ => throwUnsupportedSyntax


end LeanHoG
