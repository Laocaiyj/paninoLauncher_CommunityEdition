{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.RendererCapability
  ( RendererCapability(..)
  , inferRendererCapability
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Text (Text)
import qualified Data.Text as Text

data RendererCapability = RendererCapability
  { rendererBackend :: Text
  , rendererCanUseMetalFx :: Bool
  , rendererCanVerifyFrameTime :: Bool
  , rendererNotes :: [Text]
  } deriving (Eq, Show)

instance ToJSON RendererCapability where
  toJSON capability =
    object
      [ "backend" .= rendererBackend capability
      , "canUseMetalFx" .= rendererCanUseMetalFx capability
      , "canVerifyFrameTime" .= rendererCanVerifyFrameTime capability
      , "notes" .= rendererNotes capability
      ]

inferRendererCapability :: Maybe Text -> Bool -> RendererCapability
inferRendererCapability maybeVersion companionAvailable =
  RendererCapability
    { rendererBackend = backend
    , rendererCanUseMetalFx = False
    , rendererCanVerifyFrameTime = companionAvailable
    , rendererNotes =
        [ "Minecraft Java renderer is not treated as a MetalFX target."
        , if companionAvailable
            then "Companion frame-time metrics can validate FPS claims."
            else "Without Companion Mod, Panino limits claims to launch, JVM and memory evidence."
        ]
    }
  where
    backend =
      case Text.toLower <$> maybeVersion of
        Just version | "26.2" `Text.isPrefixOf` version -> "vulkan_candidate"
        _ -> "java_renderer_unknown"
