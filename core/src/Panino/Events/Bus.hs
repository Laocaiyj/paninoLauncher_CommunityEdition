module Panino.Events.Bus
  ( EventBus
  , newEventBus
  , publishEvent
  , subscribeEvents
  ) where

import Control.Concurrent.STM
  ( STM
  , TChan
  , atomically
  , dupTChan
  , newBroadcastTChanIO
  , writeTChan
  )
import Panino.Api.Types (ApiEvent)

newtype EventBus = EventBus (TChan ApiEvent)

newEventBus :: IO EventBus
newEventBus = EventBus <$> newBroadcastTChanIO

publishEvent :: EventBus -> ApiEvent -> IO ()
publishEvent (EventBus channel) event =
  atomically (writeTChan channel event)

subscribeEvents :: EventBus -> STM (TChan ApiEvent)
subscribeEvents (EventBus channel) =
  dupTChan channel
