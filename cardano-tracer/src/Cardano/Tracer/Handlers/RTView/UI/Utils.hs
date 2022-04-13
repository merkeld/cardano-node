{-# LANGUAGE FlexibleContexts #-}

module Cardano.Tracer.Handlers.RTView.UI.Utils
  ( (##)
  , dataState
  , dataTooltip
  , findAndDo
  , findByClassAndDo
  , findAndSet
  , findByClassAndSet
  , findAndAdd
  , findAndHide
  , findAndShow
  , image
  , showIt
  , showInline
  , hideIt
  , pageTitle
  , pageTitleNotify
  ) where

import           Data.Text (Text, unpack)
import           Control.Monad (void)
import           Control.Monad.Extra (whenJustM)
import qualified Graphics.UI.Threepenny as UI
import           Graphics.UI.Threepenny.Core

(##) :: UI Element -> String -> UI Element
(##) el anId = el # set UI.id_ anId

findAndDo
  :: UI.Window
  -> Text
  -> (Element -> UI ())
  -> UI ()
findAndDo window elId =
  whenJustM (UI.getElementById window (unpack elId))

findByClassAndDo
  :: UI.Window
  -> Text
  -> (Element -> UI ())
  -> UI ()
findByClassAndDo window className doIt =
  UI.getElementsByClassName window (unpack className) >>= mapM_ doIt

findAndSet
  :: (UI Element -> UI Element)
  -> UI.Window
  -> Text
  -> UI ()
findAndSet doIt window elId =
  findAndDo window elId $ \el -> void $ element el # doIt

findAndAdd
  :: [UI Element]
  -> UI.Window
  -> Text
  -> UI ()
findAndAdd els window elId =
  findAndDo window elId $ \el -> void $ element el #+ els

findByClassAndSet
  :: (UI Element -> UI Element)
  -> UI.Window
  -> Text
  -> UI ()
findByClassAndSet doIt window className =
  UI.getElementsByClassName window (unpack className)
  >>= mapM_ (\el -> void $ element el # doIt)

findAndShow, findAndHide
  :: UI.Window -> Text -> UI ()
findAndShow = findAndSet showIt
findAndHide = findAndSet hideIt

showIt, showInline, hideIt :: UI Element -> UI Element
showIt     = set style [("display", "block")]
showInline = set style [("display", "inline")]
hideIt     = set style [("display", "none")]

pageTitle, pageTitleNotify :: String
pageTitle       = "Cardano RTView"
pageTitleNotify = "(!) Cardano RTView"

dataTooltip :: WriteAttr Element String
dataTooltip = mkWriteAttr $ set' (attr "data-tooltip")

dataState :: Attr Element String
dataState = dataAttr "state"

dataAttr :: String -> Attr Element String
dataAttr name = mkReadWriteAttr getData setData
 where
  getData   el = callFunction $ ffi "$(%1).data(%2)" el name
  setData v el = runFunction  $ ffi "$(%1).data(%2,%3)" el name v

image :: String -> String -> UI Element
image imgClass svg = UI.span #. imgClass # set html svg
