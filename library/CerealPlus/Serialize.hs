-- |
-- A monad-transformer over "Data.Serialize.Put".
module CerealPlus.Serialize
  (
    Serialize,
    run,
    runLazy,
    exec,
    execLazy,
    liftPut,
    mapBase,
  )
  where

import CerealPlus.Prelude
import qualified Data.Serialize.Put as Cereal
import qualified Control.Monad.Layer as Layers


-- | A serialization monad transformer.
newtype Serialize m a = Serialize (WriterT (PutM' ()) m a)
  deriving (Functor, Applicative, Monad, MonadIO, MonadTrans, MonadPlus, Alternative)

instance (Monad m) => Layers.MonadTransFunctor (Serialize m) where
  transMap = mapBase

instance (Monad m) => Layers.MonadTrans (Serialize m) where
  type Outer (Serialize m) = Serialize
  transInvmap = const . Layers.transMap

instance (Monad m) => Layers.MonadLayerFunctor (Serialize m) where
  layerMap = Layers.transMap

instance (Monad m) => Layers.MonadLayer (Serialize m) where
  type Inner (Serialize m) = m
  layerInvmap = const . Layers.layerMap
  layer = lift



newtype PutM' a = PutM' (Cereal.PutM a)
  deriving (Functor, Applicative, Monad)

-- | Required for 'WriterT'
instance Monoid (PutM' ()) where
  mempty = return ()
  mappend a b = a >> b


-- | Run and get the monad result paired with a bytestring of serialized data.
run :: Monad m => Serialize m a -> m (a, ByteString)
run (Serialize w) = do
  (a, PutM' putM) <- runWriterT w
  return (a, Cereal.runPut putM)

-- | Run and get the monad result paired with a lazy bytestring of serialized data.
runLazy :: Monad m => Serialize m a -> m (a, LazyByteString)
runLazy (Serialize w) = do
  (a, PutM' putM) <- runWriterT w
  return (a, Cereal.runPutLazy putM)

-- | Run and get a bytestring of serialized data.
exec :: Monad m => Serialize m a -> m ByteString
exec (Serialize w) = do
  PutM' putM <- execWriterT w
  return $ Cereal.runPut putM

-- | Run and get a lazy bytestring of serialized data.
execLazy :: Monad m => Serialize m a -> m LazyByteString
execLazy (Serialize w) = do
  PutM' putM <- execWriterT w
  return $ Cereal.runPutLazy putM

-- | Run a `Cereal.Put` action of the \"cereal\" library.
liftPut :: Monad m => Cereal.Put -> Serialize m ()
liftPut put = Serialize $ tell $ PutM' put

-- | Change the base monad. Same as `Layers.transMap` of the \"layers\" library.
mapBase :: (forall b. m b -> m' b) -> Serialize m a -> Serialize m' a
mapBase f (Serialize writer) = Serialize $ mapWriterT f writer