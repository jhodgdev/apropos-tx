{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}

module Apropos.Script.Iso.Constraint (
  PlutarchConstraint,
  IsoConstraint (..),
  Tuple (..),
  constraintEq,
  constraintNeq,
) where

import Plutarch (POpaque, popaque)
import Plutarch.Lift
import Plutarch.Prelude

-- where POpaque is a truthy value e.g. perror = False, PUnit = True
type PlutarchConstraint debruijn domain = Term debruijn (domain :--> POpaque)

data IsoConstraint debruijn domain = IsoConstraint
  { haskConstraint :: PConstantRepr domain -> Bool
  , plutarchConstraint :: PlutarchConstraint debruijn (PAsData (PConstanted domain))
  }

-- this is like && for constraints on the same type
instance Semigroup (IsoConstraint debruijn a) where
  (<>) a b =
    IsoConstraint
      { haskConstraint = \c -> haskConstraint a c && haskConstraint b c
      , plutarchConstraint =
          plutarchConstraint a
            `plutarchConstraintSemigroup` plutarchConstraint b
      }

plutarchConstraintSemigroup ::
  PlutarchConstraint debruijn a ->
  PlutarchConstraint debruijn a ->
  PlutarchConstraint debruijn a
plutarchConstraintSemigroup x y = plam $ \a -> opaqueSemigroup (papp x a) (papp y a)
  where
    opaqueSemigroup ig nor = papp (papp (plam $ \_ig _nor -> popaque $ pcon PUnit) ig) nor

instance Monoid (IsoConstraint debruijn a) where
  mempty =
    IsoConstraint
      { haskConstraint = const True
      , plutarchConstraint = plam $ \_ -> popaque $ pcon PUnit
      }

constraintNeq ::
  (Eq (PConstantRepr a)) =>
  IsoConstraint debruijn (Tuple a a)
constraintNeq =
  IsoConstraint
    { haskConstraint = uncurry (/=)
    , plutarchConstraint = plam $ \pp ->
        pif
          (papp pnot (papp pfstBuiltin (pfromData pp) #== papp psndBuiltin (pfromData pp)))
          (popaque $ pcon PUnit)
          perror
    }

constraintEq ::
  (Eq (PConstantRepr a)) =>
  IsoConstraint debruijn (Tuple a a)
constraintEq =
  IsoConstraint
    { haskConstraint = uncurry (==)
    , plutarchConstraint = plam $ \pp ->
        pif
          (papp pfstBuiltin (pfromData pp) #== papp psndBuiltin (pfromData pp))
          (popaque $ pcon PUnit)
          perror
    }

-- hmmmmm...
data Tuple a b = Tuple a b

instance (PConstant a, PConstant b) => PConstant (Tuple a b) where
  type PConstantRepr (Tuple a b) = (PConstantRepr a, PConstantRepr b)
  type PConstanted (Tuple a b) = PBuiltinPair (PAsData (PConstanted a)) (PAsData (PConstanted b))
  pconstantToRepr (Tuple x y) = (pconstantToRepr x, pconstantToRepr y)
  pconstantFromRepr (x, y) = do
    x' <- pconstantFromRepr @a x
    y' <- pconstantFromRepr @b y
    Just (Tuple x' y')
