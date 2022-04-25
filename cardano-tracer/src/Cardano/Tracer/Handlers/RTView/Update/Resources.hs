{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.Tracer.Handlers.RTView.Update.Resources
  ( updateResourcesCharts
  , updateResourcesHistory
  ) where

import           Control.Concurrent.STM.TVar (readTVarIO)
import           Control.Monad (forM_, unless)
import           Control.Monad.Extra (whenJust)
import qualified Data.Map.Strict as M
import           Data.Time.Clock (getCurrentTime)
import           Graphics.UI.Threepenny.Core
import           Data.Text (unpack)
import           Data.Word (Word64)
import           Text.Read (readMaybe)

import           Cardano.Tracer.Handlers.Metrics.Utils
import           Cardano.Tracer.Handlers.RTView.State.Historical
import           Cardano.Tracer.Handlers.RTView.State.Last
import           Cardano.Tracer.Handlers.RTView.UI.Charts
import           Cardano.Tracer.Handlers.RTView.Update.Utils
import           Cardano.Tracer.Handlers.RTView.UI.Types
import           Cardano.Tracer.Types

updateResourcesHistory
  :: AcceptedMetrics
  -> ResourcesHistory
  -> LastResources
  -> IO ()
updateResourcesHistory acceptedMetrics (ResHistory rHistory) lastResources = do
  now <- getCurrentTime
  allMetrics <- readTVarIO acceptedMetrics
  forM_ (M.toList allMetrics) $ \(nodeId, (ekgStore, _)) -> do
    metrics <- liftIO $ getListOfMetrics ekgStore
    forM_ metrics $ \(metricName, metricValue) -> do
      let valueS = unpack metricValue
      case metricName of
        "stat.cputicks"   -> updateCPUUsage nodeId valueS now
        "mem.resident"    -> updateRSSMemory nodeId valueS now
        "rts.gcLiveBytes" -> return () -- updateRTSBytesUsed
        "rts.gcMajorNum"  -> return () -- updateGcMajorNum
        "rts.gcMinorNum"  -> return () -- updateGcMinorNum
        "rts.gcticks"     -> return () -- updateGCTicks
        "rts.mutticks"    -> return () -- updateMutTicks
        -- "rts.stat.threads" TODO
        _ -> return ()
 where
  updateCPUUsage nodeId valueS now =
    whenJust (readMaybe valueS) $ \(cpuTicks :: Integer) -> do
      lastOnes <- readTVarIO lastResources
      case M.lookup nodeId lastOnes of
        Nothing ->
          -- There is no last resources for this node yet.
          addNullResources lastResources nodeId
        Just resourcesForNode -> do
          let tns        = utc2ns now
              tDiffInSec = max 0.1 $ fromIntegral (tns - cpuLastNS resourcesForNode) / 1000_000_000 :: Double
              ticksDiff  = cpuTicks - cpuLastTicks resourcesForNode
              cpuV       = fromIntegral ticksDiff / fromIntegral (100 :: Integer) / tDiffInSec
              newCPUPct  = if cpuV < 0 then 0.0 else cpuV * 100.0
          addHistoricalData rHistory nodeId now CPUData $ ValueD newCPUPct
          updateLastResources lastResources nodeId $ \current ->
            current { cpuLastTicks = cpuTicks
                    , cpuLastNS = tns
                    }

  updateRSSMemory nodeId valueS now =
    whenJust (readMaybe valueS) $ \(bytes :: Word64) -> do
      let memoryInMB = fromIntegral bytes / 1024 / 1024 :: Double
      addHistoricalData rHistory nodeId now MemoryData $ ValueD memoryInMB

updateResourcesCharts
  :: ConnectedNodes
  -> ResourcesHistory
  -> DatasetsIndices
  -> DatasetsTimestamps
  -> UI ()
updateResourcesCharts connectedNodes (ResHistory rHistory) datasetIndices datasetTimestamps = do
  connected <- liftIO $ readTVarIO connectedNodes
  forM_ connected $ \nodeId -> do
    addPointsToAChart nodeId CPUData    CPUChart
    addPointsToAChart nodeId MemoryData MemoryChart
 where
  addPointsToAChart nodeId dataName chartId = do
    history <- liftIO $ getHistoricalData rHistory nodeId dataName
    unless (null history) $ do
      getLatestDisplayedTS datasetTimestamps nodeId dataName >>= \case
        Nothing ->
          -- There is no saved latestTS for this node and chart yet,
          -- so display all the history and remember the latestTS.
          addPointsToChart chartId nodeId datasetIndices history
        Just storedTS -> do
          -- Some of the history for this node and chart is already displayed,
          -- so cut displayed points first. The only points we should add now
          -- are the points with 'ts' that is bigger than 'storedTS'.
          let onlyNewPoints = cutOldPoints storedTS history
          addPointsToChart chartId nodeId datasetIndices onlyNewPoints
      let (latestTS, _) = last history
      saveLatestDisplayedTS datasetTimestamps nodeId dataName latestTS

  cutOldPoints _ [] = []
  cutOldPoints oldTS (point@(ts, _):newerPoints) =
    if ts > oldTS
      then
        -- This point is newer than 'oldTS', take it and all the following
        -- as well, because they are definitely newer (points are sorted by ts).
        point : newerPoints
      else
        -- This point are older than 'oldTS', it means that it already was displayed.
        cutOldPoints oldTS newerPoints
