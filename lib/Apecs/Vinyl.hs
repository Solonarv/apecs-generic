{-# LANGUAGE UndecidableInstances #-}
-- | Provides a Vinyl-based alternative to 'Apecs.TH.makeWorld'.
module Apecs.Vinyl
  ( type WorldRec'
  , type WorldRec
  , type InitWorldRec
  , initWorldRec
  ) where

import Control.Monad.Reader

import Apecs.Core
import Apecs.Util
import Data.Vinyl
import Data.Vinyl.ARec
import Data.Vinyl.TypeLevel

-- | @'WorldRec' cs@ is a world containing the components listed in @cs@.
-- It is backed by a @'Data.Vinyl.ARec.ARec'@, so it should be reasonably
-- performant for most operations.
newtype WorldRec cs = WorldRec (ARec StoreFor cs)

-- | A convenience synonym for @'WorldRec'@ that adds an
-- @'EntityCounter'@ to the list of components.
type WorldRec' cs = WorldRec (EntityCounter ': cs)

-- | @'StoreFor' c@ is a newtype wrapper around @'Storage' c@,
-- suitable as an interpretation functor for Vinyl.
newtype StoreFor c = StoreFor { getStoreFor :: Storage c }

instance {-# OVERLAPPABLE #-} (Monad m, NatToInt (RIndex c cs), Component c) => Has (WorldRec cs) m c where
  getStore = asks $ \(WorldRec stores) -> getStoreFor (aget @c stores)

-- | Helper class for the implementation of @'initWorldRec'@.
-- 
-- An instance for @'InitWorldRec' m cs@ simply states that the store for
-- every member of @cs@ has an @'ExplInit' m@ instance.
--
-- This could
-- be replaced with some combinators from Vinyl, but using a fresh class
-- is easier to understand and takes less typechecker wrangling.
class Applicative m => InitWorldRec m cs where
  initWorldRec_ :: m (Rec StoreFor cs)

instance Applicative m => InitWorldRec m '[] where
  initWorldRec_ = pure RNil

instance (InitWorldRec m cs, ExplInit m (Storage c)) => InitWorldRec m (c ': cs) where
  initWorldRec_ = (:&) <$> (StoreFor <$> explInit) <*> initWorldRec_

-- | Initialize a @'WorldRec' cs@. This is the pendant of the
-- @initXXX@ function generated by @"Apecs.TH"@.
initWorldRec :: (InitWorldRec m cs, NatToInt (RLength cs)) => m (WorldRec cs)
initWorldRec = WorldRec . toARec <$> initWorldRec_