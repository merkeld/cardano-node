{-# LANGUAGE QuasiQuotes #-}

module Cardano.Tracer.Handlers.RTView.UI.JS.Charts
  ( prepareChartsJS
  , addDatasetChartJS
  , addPointsChartJS
  , getDatasetsLengthChartJS
  , newTimeChartJS
  ) where

import           Data.List (intercalate)
import           Data.String.QQ
import           Data.Text (Text)
import qualified Graphics.UI.Threepenny as UI
import           Graphics.UI.Threepenny.Core

import           Cardano.Tracer.Handlers.RTView.State.Historical
import           Cardano.Tracer.Handlers.RTView.Update.Utils

prepareChartsJS :: UI ()
prepareChartsJS =
  UI.runFunction $ UI.ffi "window.charts = new Map();"

newTimeChartJS
  :: String
  -> String
  -> String
  -> UI ()
newTimeChartJS chartId chartName yValuesLabel =
  UI.runFunction $ UI.ffi newTimeChartJS' chartId chartName yValuesLabel

newTimeChartJS' :: String
newTimeChartJS' = [s|
var ctx = document.getElementById(%1).getContext('2d');
var chart = new Chart(ctx, {
  type: 'line',
  data: {
    datasets: []
  },
  options: {
    animation: false,
    showLine: true,
    elements: {
      point: {
        radius: 2
      }
    },
    responsive: true,
    plugins: {
      title: {
        display: true,
        align: 'start',
        font: {
          size: 18
        },
        text: %2
      }
    },
    scales: {
      x: {
        type: 'time',
        title: {
          display: true,
          text: 'Time in UTC'
        },
        time: {
          displayFormats: {
            millisecond: 'MMM D YYYY HH:mm:ss.SSS',
            second:      'MMM D YYYY HH:mm:ss',
            minute:      'MMM D YYYY HH:mm',
            hour:        'MMM D YYYY hh a',
          },
          unit: 'minute'
        }
      },
      y: {
        title: {
          display: true,
          text: %3
        }
      }
    }
  }
});
window.charts.set(%1, chart);
|]

addDatasetChartJS
  :: String
  -> Text
  -> String
  -> UI ()
addDatasetChartJS chartId nodeName color =
  UI.runFunction $ UI.ffi addDatasetChartJS' chartId nodeName color

addDatasetChartJS' :: String
addDatasetChartJS' = [s|
const newDataset = {
  label: %2,
  backgroundColor: %3,
  borderColor: %3,
  data: [],
  fill: false
};
window.charts.get(%1).data.datasets.push(newDataset);
window.charts.get(%1).update({duration: 0});
|]

getDatasetsLengthChartJS :: String -> UI Int
getDatasetsLengthChartJS chartId =
  UI.callFunction $ UI.ffi "window.charts.get(%1).data.datasets.length;" chartId

addPointsChartJS
  :: String
  -> Int
  -> [(POSIXTime, ValueH)]
  -> UI ()
addPointsChartJS chartId datasetIx points = do
  UI.runFunction $ UI.ffi pushToDataset
  UI.runFunction $ UI.ffi "window.charts.get(%1).update({duration: 0});" chartId
 where
  pushToDataset =
    "window.charts.get('"
    <> chartId
    <> "').data.datasets["
    <> show datasetIx
    <> "].data.push("
    <> pointsList
    <> ");"
  pointsList = intercalate ", " $ map mkPointObject points
  mkPointObject (ts, valueH) =
    "{x: '" <> show (s2utc ts) <> "', y: " <> show valueH <> "}"
