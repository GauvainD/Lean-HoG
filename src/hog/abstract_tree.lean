-- A tree in the graph theory sense, i.e. for a connected graph a subgraph on all vertices and no cycles
-- We want to look at spanning trees. A spanning tree for a graph G with |V(G)| = n has n-1 edges
-- A spanning tree of G is a subgraph that has as vertices the vertices of G. There may be many possible spanning trees for a graph.
-- A spanning forest is a collection of spanning trees for each connected component of G

-- Goals:
-- [x] Give the abstract definition of a tree
-- [x] Give an example of two connected vertices that aren't adjacent
-- [ ] Give a concrete example of a tree
-- [ ] Give a model of an abstract tree as a element of type simple_irreflexive_graph
-- [x] Actually define a graph as a certain simple_irreflexive_graph
-- [ ] count the number of spanning trees in this forest
-- [ ] witness that a graph has a given spannign forest
-- [ ] prove that this witness really describes a spanning forest in G
-- [ ] prove that the size of the tree set of a spanning forest is in bijection with the set of connected components of G

import .graph
import .connected_component

structure abstract_tree : Type :=
  (G : simple_irreflexive_graph)
  (has_correct_num_edges : G.vertex_size - 1 = G.edge_size . bool_reflect)
  (connected : connected_graph G)

def hog : BST Edge :=
{ tree := BT.node {edge := (2, 3)} (BT.node {edge := (1, 4)} (BT.leaf {edge := (0, 4)}) (BT.empty)) (BT.leaf {edge := (3, 4)}),
  is_bst := begin simp, bool_reflect end
}

def g : simple_irreflexive_graph := from_BST 5 hog

#eval g.vertex_size

-- The edge relation for graphs is decidable
#check g.edge_decidable (@fin.mk 5 1 (by obviously)) (@fin.mk 5 4 (by obviously))

-- This is how we can compute the edge relation on a graph
-- It's a bit of a pain in the ass, but it actually computes
def one := (@fin.mk 5 1 (by obviously))
def two := (@fin.mk 5 2 (by obviously))
def three := (@fin.mk 5 3 (by obviously))
def four := (@fin.mk 5 4 (by obviously))

#eval @decidable.to_bool (g.edge one four) (g.edge_decidable one four)
#eval @decidable.to_bool (g.edge four three) (g.edge_decidable four three)
#eval @decidable.to_bool (g.edge two four) (g.edge_decidable two four)

lemma one_four : @connected g one four :=
begin
  apply connected_edge,
  obviously
end

lemma four_three : @connected g four three :=
begin
  apply connected_edge,
  obviously
end

-- We can compose paths
lemma one_three : @connected g one three := one_four ⊕ four_three

#check @connected g one three

-- Now we have to show this relation for a concrete tree using the equivalence relation generated by edge
def simple_tree : abstract_tree := 
{ G := from_BST 5 hog,
  connected := 
    begin 
      unfold connected_graph,
      intros u v,
      simp,
      sorry
    end
}