{- |
   Module      : Data.GraphViz.Types
   Description : Definition of the GraphViz types.
   Copyright   : (c) Matthew Sackman, Ivan Lazar Miljenovic
   License     : 3-Clause BSD-style
   Maintainer  : Ivan.Miljenovic@gmail.com

   This module defines the overall types and methods that interact
   with them for the GraphViz library.
-}

module Data.GraphViz.Types
    ( DotGraph(..)
    , GraphID(..)
    , DotNode(..)
    , DotEdge(..)
    , parseDotGraph
    , setID
    , makeStrict
    ) where

import Data.GraphViz.Attributes
import Data.GraphViz.ParserCombinators

import Data.Char(isAsciiLower, isAsciiUpper, isDigit)
import Data.Maybe
import Control.Monad

-- -----------------------------------------------------------------------------

-- | The internal representation of a graph in Dot form.
data DotGraph = DotGraph { strictGraph     :: Bool
                         , directedGraph   :: Bool
                         , graphID         :: Maybe GraphID
                         , graphAttributes :: [Attribute]
                         , graphNodes      :: [DotNode]
                         , graphEdges      :: [DotEdge]
                         }
                deriving (Eq, Read)

makeStrict   :: DotGraph -> DotGraph
makeStrict g = g { strictGraph = True }

setID     :: GraphID -> DotGraph -> DotGraph
setID i g = g { graphID = Just i }

instance Show DotGraph where
    show g
        = unlines $ (hdr ++ " {") : (rest ++ ["}"])
        where
          hdr = strct . addId $ gType
          strct = if strictGraph g
                  then ("strict " ++)
                  else id
          addId = maybe id (\ i -> flip (++) $ ' ' : show i) $ graphID g
          gType = if directedGraph g then dirGraph else undirGraph
          rest = case graphAttributes g of
                   [] -> nodesEdges
                   a -> ("\tgraph " ++ show a ++ ";") : nodesEdges
          nodesEdges = map show (graphNodes g) ++ map show (graphEdges g)

dirGraph :: String
dirGraph = "digraph"

undirGraph :: String
undirGraph = "graph"

parseDotGraph :: Parse DotGraph
parseDotGraph = parse

instance Parseable DotGraph where
    parse = do isStrict <- parseAndSpace $ hasString "strict"
               gType <- strings [dirGraph,undirGraph]
               gId <- optional (parse `discard` whitespace)
               whitespace
               char '{'
               skipToNewline
               as <- liftM concat $
                     many (whitespace' >>
                           oneOf [ string "edge" >> skipToNewline >> return []
                                 , string "node" >> skipToNewline >> return []
                                 , string "graph" >> whitespace
                                              >> parse `discard` skipToNewline
                                 ]
                          )
               ns <- many1 (whitespace' >> parse `discard` skipToNewline)
               es <- many1 (whitespace' >> parse `discard` skipToNewline)
               char '}'
               return DotGraph { strictGraph = isStrict
                               , directedGraph = gType == dirGraph
                               , graphID = gId
                               , graphAttributes = as
                               , graphNodes = ns
                               , graphEdges = es
                               }

            `adjustErr`
            (++ "\nNot a valid DotGraph")

-- -----------------------------------------------------------------------------

data GraphID = Str String
             | Num Double
             | QStr QuotedString
             | HTML URL
               deriving (Eq, Read)

instance Show GraphID where
    show (Str str)  = str
    show (Num n)    = show n
    show (QStr str) = show str
    show (HTML url) = show url

instance Parseable GraphID where
    parse = oneOf [ liftM Str stringBlock
                  , liftM Num parse
                  , liftM QStr parse
                  , liftM HTML parse
                  ]
            `adjustErr`
            (++ "\nNot a valid GraphID")

-- -----------------------------------------------------------------------------

-- | A node in 'DotGraph' is either a singular node, or a cluster
--   containing nodes (or more clusters) within it.
--   At the moment, clusters are not parsed.
data DotNode
    = DotNode { nodeID :: Int
              , nodeAttributes :: [Attribute]
              }
    | DotCluster { clusterID         :: String
                 , clusterAttributes :: [Attribute]
                 , clusterElems      :: [DotNode]
                 }
      deriving (Eq, Read)

instance Show DotNode where
    show = init . unlines . addTabs . nodesToString

nodesToString :: DotNode -> [String]
nodesToString n@(DotNode {})
    | null nAs  = [nID ++ ";"]
    | otherwise = [nID ++ (' ':(show nAs ++ ";"))]
    where
      nID = show $ nodeID n
      nAs = nodeAttributes n
nodesToString c@(DotCluster {})
    = ["subgraph cluster_" ++ clusterID c ++ " {"] ++ addTabs inner ++ ["}"]
    where
      inner = case clusterAttributes c of
                [] -> nodes
                a  -> ("graph " ++ show a ++ ";") : nodes
      nodes = concatMap nodesToString $ clusterElems c


instance Parseable DotNode where
    parse = do nId <- parse
               as <- optional (whitespace >> parse)
               char ';'
               return DotNode { nodeID = nId
                              , nodeAttributes = fromMaybe [] as }
            `adjustErr`
            (++ "\nNot a valid DotNode")

-- | Prefix each 'String' with a tab character.
addTabs :: [String] -> [String]
addTabs = map ('\t':)

-- -----------------------------------------------------------------------------

-- | An edge in 'DotGraph'.
data DotEdge = DotEdge { edgeHeadNodeID :: Int
                       , edgeTailNodeID :: Int
                       , edgeAttributes :: [Attribute]
                       , directedEdge   :: Bool
                       }
             deriving (Eq, Read)

instance Show DotEdge where
    show e
        = '\t' : (show (edgeHeadNodeID e)
                  ++ edge ++ show (edgeTailNodeID e) ++ attributes)
          where
            edge = " " ++ (if directedEdge e then dirEdge else undirEdge) ++ " "
            attributes = case edgeAttributes e of
                           [] -> ";"
                           a  -> ' ':(show a ++ ";")

dirEdge :: String
dirEdge = "->"

undirEdge :: String
undirEdge = "--"

instance Parseable DotEdge where
    parse = do whitespace'
               eHead <- parse
               whitespace
               edgeType <- strings [dirEdge,undirEdge]
               whitespace
               eTail <- parse
               as <- optional (whitespace >> parse)
               char ';'
               return DotEdge { edgeHeadNodeID = eHead
                              , edgeTailNodeID = eTail
                              , edgeAttributes = fromMaybe [] as
                              , directedEdge   = edgeType == dirEdge
                              }
            `adjustErr`
            (++ "\nNot a valid DotEdge")

-- -----------------------------------------------------------------------------