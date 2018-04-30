{- |
   Module      : Data.GraphViz.Types.GraphSpec
   Description : Testing canonical graph representation
   Copyright   : Matthew Sackman, Ivan Lazar Miljenovic
   License     : BSD3
   Maintainer  : Ivan.Miljenovic@gmail.com



 -}
module Data.GraphViz.Types.GraphSpec where

import Data.GraphViz.Testing.Instances  ()
import Data.GraphViz.Testing.Properties
import Data.GraphViz.Testing.Proxy      (DGProxy(..))
import Data.GraphViz.Types.Graph        (DotGraph)

import Test.Hspec            (Spec)
import Test.Hspec.QuickCheck (prop)

import Data.Graph.Inductive.PatriciaTree (Gr)

--------------------------------------------------------------------------------

spec :: Spec
spec = do
  prop "Printing and parsing Dot graph"
       (prop_printParseID :: DotGraph Int -> Bool)
  prop "Find all nodes in a Dot graph"
       (prop_findAllNodes dproxy :: Gr () () -> Bool)
  prop "Find all nodes in an node-less Dot graph"
       (prop_findAllNodesE dproxy :: Gr () () -> Bool)
  prop "Find all edges in a Dot graph"
       (prop_findAllEdges dproxy :: Gr () () -> Bool)
  prop "Plain Dot graphs should have no structural information"
       (prop_noGraphInfo dproxy :: Gr () () -> Bool)

dproxy :: DGProxy DotGraph
dproxy = DGProxy
