{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.Tracer.Handlers.RTView.Update
  ( update
  ) where

import           Control.Concurrent.STM.TVar (readTVarIO)
import           Control.Monad (forM_)
import           Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as M
import qualified Graphics.UI.Threepenny as UI
import           Graphics.UI.Threepenny.Core

import           Cardano.Tracer.Configuration
import           Cardano.Tracer.Handlers.RTView.State.Displayed
import           Cardano.Tracer.Handlers.RTView.State.TraceObjects
import           Cardano.Tracer.Handlers.RTView.Update.Nodes
import           Cardano.Tracer.Handlers.RTView.Update.Peers
import           Cardano.Tracer.Types

update
  :: UI.Window
  -> ConnectedNodes
  -> DisplayedElements
  -> SavedTraceObjects
  -> DataPointRequestors
  -> PageReloadedFlag
  -> NonEmpty LoggingParams
  -> UI ()
update window connectedNodes displayedElements savedTO dpRequestors reloadFlag loggingConfig = do
  updateNodes
    window
    connectedNodes
    displayedElements
    dpRequestors
    reloadFlag
    loggingConfig
  checkSavedTraceObjects
 where
  checkSavedTraceObjects = do
    savedTraceObjects <- liftIO $ readTVarIO savedTO
    forM_ (M.toList savedTraceObjects) $ \(nodeId, savedTOForNode) ->
      forM_ (M.toList savedTOForNode) $ \(namespace, trObValue) ->
        case namespace of
          "Cardano.Node.Peers" -> updatePeers window nodeId displayedElements trObValue
          "density" -> return () -- updateElement
          "slotNum" -> return ()
          "blockNum" -> return ()
          "slotInEpoch" -> return ()
          "epoch" -> return ()
          "forks" -> return ()
          "txsInMempool"  -> return ()
          "mempoolBytes"  -> return ()
          "txsProcessedNum"  -> return ()
          "blocksForgedNum"  -> return ()
          "nodeCannotForge"  -> return ()
          "nodeIsLeaderNum"  -> return ()
          "slotsMissedNum" -> return ()
          "operationalCertificateStartKESPeriod"  -> return ()
          "operationalCertificateExpiryKESPeriod"  -> return ()
          "currentKESPeriod"  -> return ()
          "remainingKESPeriods" -> return ()
          _ -> return ()

{-
updateElement = do
  let elId = ""
      elValue = trObValue
  liftIO (getDisplayedValue displayedElements nodeId elId) >>= \case
    Nothing ->
      -- There is no displayed value for this element yet.
      setAndSave elId elValue
    Just displayedValue ->
      -- There is a value that already displayed, check if it changed.
      unless (elValue == displayedValue) $
        setAndSave elId elValue
 where
   setAndSave elId elValue = do
    findAndSet (set text $ T.unpack elValue) window elId
    liftIO $ saveDisplayedValue displayedElements nodeId elId elValue
-}
