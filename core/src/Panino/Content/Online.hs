{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online
  ( ContentLoaderRequest(..)
  , ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
  , MinecraftPackageRequest(..)
  , contentLoaderMetadata
  , contentMinecraftPackage
  , contentMinecraftVersions
  , contentProject
  , contentSearch
  ) where

import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.CurseForge
  ( curseForgeProject
  , curseForgeSearch
  )
import Panino.Content.Online.Minecraft
  ( contentLoaderMetadata
  , contentMinecraftPackage
  , contentMinecraftVersions
  )
import Panino.Content.Online.Modrinth
  ( modrinthProject
  , modrinthSearch
  )
import Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
  , MinecraftPackageRequest(..)
  , OnlineSearchPage
  )

contentSearch :: Manager -> ContentSearchRequest -> IO OnlineSearchPage
contentSearch manager request =
  case contentSearchSource request of
    "modrinth" -> modrinthSearch manager request
    "curseForge" -> curseForgeSearch manager request
    other -> fail ("unsupported content source: " <> Text.unpack other)

contentProject :: Manager -> ContentProjectRequest -> IO ContentProjectResponse
contentProject manager request =
  case contentProjectSource request of
    "modrinth" -> modrinthProject manager request
    "curseForge" -> curseForgeProject manager request
    other -> fail ("unsupported content source: " <> Text.unpack other)
