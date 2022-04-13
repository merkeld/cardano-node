{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.Tracer.Handlers.RTView.Update.Nodes
  ( updateNodes
  ) where

import           Control.Concurrent.STM (atomically)
import           Control.Concurrent.STM.TVar (readTVar)
import           Control.Monad (forM_, unless, when)
import           Control.Monad.Extra (whenJust, whenJustM)
import           Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as M
import           Data.Set (Set, (\\))
import qualified Data.Set as S
import qualified Data.Text as T
import           Data.Time.Calendar
import           Data.Time.Clock (UTCTime (..), addUTCTime, diffUTCTime, getCurrentTime)
import           Data.Time.Format (defaultTimeLocale, formatTime)
import qualified Graphics.UI.Threepenny as UI
import           Graphics.UI.Threepenny.Core
import           Text.Read (readMaybe)

import           Cardano.Tracer.Configuration
import           Cardano.Tracer.Handlers.RTView.State.Displayed
import           Cardano.Tracer.Handlers.RTView.UI.HTML.Node.Column
import           Cardano.Tracer.Handlers.RTView.UI.Utils
import           Cardano.Tracer.Handlers.RTView.Update.NodeInfo
import           Cardano.Tracer.Types

updateNodes
  :: UI.Window
  -> ConnectedNodes
  -> DisplayedElements
  -> DataPointRequestors
  -> PageReloadedFlag
  -> NonEmpty LoggingParams
  -> UI ()
updateNodes window connectedNodes displayedElements dpRequestors reloadFlag loggingConfig = do
  (connected, displayedEls, afterReload) <- liftIO . atomically $ (,,)
    <$> readTVar connectedNodes
    <*> readTVar displayedElements
    <*> readTVar reloadFlag
  if afterReload
    then do
      -- Ok, web-page was reload (i.e. it's the first update after DOM-rendering),
      -- so displayed state should be restored immediately.
      addColumnsForConnected window connected loggingConfig
      checkNoNodesState window connected
      askNSetNodeInfo window dpRequestors connected displayedElements
      liftIO $ updateDisplayedElements displayedElements connected
      liftIO $ pageWasNotReload reloadFlag
    else do
      -- Check connected/disconnected nodes since previous UI's update.
      let displayed = S.fromList $ M.keys displayedEls
      when (connected /= displayed) $ do
        let disconnected   = displayed \\ connected -- In 'displayed' but not in 'connected'.
            newlyConnected = connected \\ displayed -- In 'connected' but not in 'displayed'.
        deleteColumnsForDisconnected window connected disconnected
        addColumnsForConnected window newlyConnected loggingConfig
        checkNoNodesState window connected
        askNSetNodeInfo window dpRequestors newlyConnected displayedElements
        liftIO $ updateDisplayedElements displayedElements connected
  setUptimeForNodes window connected displayedElements

addColumnsForConnected
  :: UI.Window
  -> Set NodeId
  -> NonEmpty LoggingParams
  -> UI ()
addColumnsForConnected window newlyConnected loggingConfig = do
  unless (S.null newlyConnected) $
    findAndShow window "main-table-container"
  forM_ newlyConnected $ addNodeColumn window loggingConfig

deleteColumnsForDisconnected
  :: UI.Window
  -> Set NodeId
  -> Set NodeId
  -> UI ()
deleteColumnsForDisconnected window connected disconnected = do
  forM_ disconnected $ deleteNodeColumn window
  when (S.null connected) $
    findAndHide window "main-table-container"

checkNoNodesState :: UI.Window -> Set NodeId -> UI ()
checkNoNodesState window connected =
  if S.null connected
    then do
      findAndShow window "no-nodes"
      findAndShow window "no-nodes-info"
    else do
      findAndHide window "no-nodes"
      findAndHide window "no-nodes-info"

setUptimeForNodes
  :: UI.Window
  -> Set NodeId
  -> DisplayedElements
  -> UI ()
setUptimeForNodes window connected displayedElements = do
  now <- liftIO $ getCurrentTime
  forM_ connected $ \nodeId@(NodeId anId) -> do
    let nodeStartElId  = anId <> "__node-start-time"
        nodeUptimeElId = anId <> "__node-uptime"
    whenJustM (liftIO $ getDisplayedValue displayedElements nodeId nodeStartElId) $ \tsRaw ->
      whenJust (readMaybe (T.unpack tsRaw) :: Maybe UTCTime) $ \startTime -> do
        let uptimeDiff = now `diffUTCTime` startTime
            uptime = uptimeDiff `addUTCTime` nullTime
            uptimeFormatted = formatTime defaultTimeLocale "%X" uptime
            daysNum = utctDay uptime `diffDays` utctDay nullTime
            uptimeWithDays = if daysNum > 0
                               -- Show days only if 'uptime' > 23:59:59.
                               then show daysNum <> "d " <> uptimeFormatted
                               else uptimeFormatted
        findAndSet (set text uptimeWithDays) window nodeUptimeElId
 where
  nullTime = UTCTime (ModifiedJulianDay 0) 0
