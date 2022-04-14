{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.Tracer.Handlers.RTView.Update.Errors
  ( updateErrors
  ) where

import           Control.Concurrent.STM.TVar (readTVarIO)
import           Control.Monad (forM_)
import qualified Data.Map.Strict as M
import qualified Graphics.UI.Threepenny as UI
import           Graphics.UI.Threepenny.Core

import           Cardano.Tracer.Handlers.Metrics.Utils
import           Cardano.Tracer.Types

updateErrors
  :: UI.Window
  -> AcceptedMetrics
  -> UI ()
updateErrors _window acceptedMetrics = do
  allMetrics <- liftIO $ readTVarIO acceptedMetrics
  forM_ (M.toList allMetrics) $ \(_nodeId, (ekgStore, _)) -> do
    metrics <- liftIO $ getListOfMetrics ekgStore
    forM_ metrics $ \(_metricName, _metricValue) ->
      return ()
{-
      updateMetricsElements window nodeId metricName metricValue

updateMetricsElements
  :: UI.Window
  -> NodeId
  -> MetricName
  -> MetricValue
  -> UI ()
updateMetricsElements window nodeId metricName metricValue =
  case metricName of
    "Stat.Cputicks" -> return ()
    "Mem.Resident" -> return ()
    "RTS.GcLiveBytes" -> return ()
    "RTS.GcMajorNum" -> return ()
    "RTS.GcMinorNum" -> return ()
    "RTS.Gcticks" -> return ()
    "RTS.Mutticks" -> return ()
    "Stat.Threads" -> return ()
    _ -> return ()
-}

