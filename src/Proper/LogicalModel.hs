module Proper.LogicalModel
  ( LogicalModel(..)
  , Enumerable(..)
  , enumerateScenariosWhere
  , satisfiesFormula
  , enumerateSolutions
  , module Proper.LogicalModel.Formula
  , module Proper.LogicalModel.Enumerable
  , module Proper.LogicalModel.Enumerable.TH
  ) where
import Proper.LogicalModel.Enumerable
import Proper.LogicalModel.Enumerable.TH
import Proper.LogicalModel.Formula
import Data.Set (Set)
import qualified Data.Set as Set
import qualified Data.Map as Map

class (Enumerable p, Eq p, Ord p, Show p) => LogicalModel p where
  logic :: Formula p

enumerateScenariosWhere :: forall p . LogicalModel p => Formula p -> [Set p]
enumerateScenariosWhere holds = enumerateSolutions $ logic :&&: holds :&&: allPresentInFormula
  where
    allPresentInFormula :: Formula p
    allPresentInFormula = All (mention <$> (enumerated :: [p]))
    mention :: p -> Formula p
    mention p = Var p :||: Not (Var p)

enumerateSolutions :: LogicalModel p => Formula p -> [Set p]
enumerateSolutions f = fromSolution <$> solve_all f
  where
    fromSolution :: LogicalModel p => Map.Map p Bool -> Set p
    fromSolution m = Set.fromList $ filter isInSet enumerated
      where
        isInSet k = Just True == Map.lookup k m

satisfiesFormula :: forall p . LogicalModel p => Formula p -> Set p -> Bool
satisfiesFormula f s = satisfiable $ f :&&: All (Var <$> set) :&&: None (Var <$> unset)
  where
    set :: [p]
    set = Set.toList s
    unset :: [p]
    unset = filter (`notElem` s) (enumerated :: [p])

