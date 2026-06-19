{-# LANGUAGE OverloadedStrings #-}

module Integration.LocalInstanceStatus
  ( assertLocalInstanceStatus
  ) where

import Control.Monad (when)
import qualified Data.ByteString.Lazy.Char8 as BL8
import Panino.Api.MinecraftStatus
  ( MinecraftInstallStatusRequest(..)
  , MinecraftInstalledInstance(..)
  , fetchInstalledMinecraftInstances
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , removeDirectoryRecursive
  )
import System.FilePath ((</>))
import TestSupport (assertEqual)

assertLocalInstanceStatus :: FilePath -> IO ()
assertLocalInstanceStatus tempRoot = do
  let failedInstallRoot = tempRoot </> "panino-status-failed"
      failedVersionDir = failedInstallRoot </> "versions" </> "1.20.1"
  failedInstallExists <- doesDirectoryExist failedInstallRoot
  when failedInstallExists (removeDirectoryRecursive failedInstallRoot)
  createDirectoryIfMissing True failedVersionDir
  createDirectoryIfMissing True (failedInstallRoot </> "mods")
  createDirectoryIfMissing True (failedInstallRoot </> ".panino")
  BL8.writeFile (failedVersionDir </> "1.20.1.json") "{}"
  BL8.writeFile (failedVersionDir </> "1.20.1.jar") "jar"
  BL8.writeFile (failedInstallRoot </> ".panino" </> "install-state.json") "{\"state\":\"failed\"}"
  failedInstances <-
    fetchInstalledMinecraftInstances
      Nothing
      (MinecraftInstallStatusRequest ["1.20.1"] [failedInstallRoot])
  assertEqual "failed install-state is discovered but incomplete" [(False, False)] (map (\item -> (installedInstanceVersionJson item, installedInstanceClientJar item)) failedInstances)

  let inferredLoaderRoot = tempRoot </> "panino-status-loader-inferred"
      inferredBaseDir = inferredLoaderRoot </> "versions" </> "1.21.7"
      inferredQuiltDir = inferredLoaderRoot </> "versions" </> "quilt-loader-0.20.0-beta.9-1.21.7"
  inferredLoaderExists <- doesDirectoryExist inferredLoaderRoot
  when inferredLoaderExists (removeDirectoryRecursive inferredLoaderRoot)
  createDirectoryIfMissing True inferredBaseDir
  createDirectoryIfMissing True inferredQuiltDir
  createDirectoryIfMissing True (inferredLoaderRoot </> "mods")
  BL8.writeFile (inferredBaseDir </> "1.21.7.json") "{}"
  BL8.writeFile (inferredBaseDir </> "1.21.7.jar") "jar"
  BL8.writeFile (inferredQuiltDir </> "quilt-loader-0.20.0-beta.9-1.21.7.json") "{}"
  inferredInstances <-
    fetchInstalledMinecraftInstances
      Nothing
      (MinecraftInstallStatusRequest ["1.21.7"] [inferredLoaderRoot])
  assertEqual "local instance loader is inferred from loader profile" [(Just "quilt", Just "0.20.0-beta.9")] (map (\item -> (installedInstanceLoader item, installedInstanceLoaderVersion item)) inferredInstances)
