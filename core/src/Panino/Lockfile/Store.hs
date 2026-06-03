{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Store
  ( currentLockfilePath
  , lastSolverExplainPath
  , lastSolverResultPath
  , readCurrentLockfile
  , writeCurrentLockfile
  , writeLastSolverArtifacts
  ) where

import Data.Aeson (eitherDecode, encode)
import qualified Data.ByteString.Lazy as BL
import Panino.Lockfile.Types
  ( LockfileExplain
  , PaninoLockfile
  , SolverResult
  , solverResultExplain
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )

currentLockfilePath :: FilePath -> FilePath
currentLockfilePath gameDir =
  gameDir </> ".panino" </> "panino-lock.json"

lastSolverResultPath :: FilePath -> FilePath
lastSolverResultPath gameDir =
  gameDir </> "downloads" </> "last-solver-result.json"

lastSolverExplainPath :: FilePath -> FilePath
lastSolverExplainPath gameDir =
  gameDir </> "downloads" </> "last-solver-explain.json"

readCurrentLockfile :: FilePath -> IO (Either String (Maybe PaninoLockfile))
readCurrentLockfile gameDir = do
  let path = currentLockfilePath gameDir
  exists <- doesFileExist path
  if not exists
    then pure (Right Nothing)
    else do
      decoded <- eitherDecode <$> BL.readFile path
      pure (Just <$> decoded)

writeCurrentLockfile :: FilePath -> PaninoLockfile -> IO FilePath
writeCurrentLockfile gameDir lockfile = do
  let path = currentLockfilePath gameDir
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode lockfile)
  pure path

writeLastSolverArtifacts :: FilePath -> SolverResult -> IO (FilePath, FilePath)
writeLastSolverArtifacts gameDir result = do
  let resultPath = lastSolverResultPath gameDir
      explainPath = lastSolverExplainPath gameDir
  createDirectoryIfMissing True (takeDirectory resultPath)
  BL.writeFile resultPath (encode result)
  writeLockfileExplain explainPath (solverResultExplain result)
  pure (resultPath, explainPath)

writeLockfileExplain :: FilePath -> LockfileExplain -> IO ()
writeLockfileExplain path explain = do
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode explain)
