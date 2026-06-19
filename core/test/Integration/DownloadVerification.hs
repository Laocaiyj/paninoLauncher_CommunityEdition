{-# LANGUAGE OverloadedStrings #-}

module Integration.DownloadVerification
  ( assertDownloadVerification
  ) where

import Control.Exception (finally)
import qualified Data.ByteString.Char8 as BS8
import Panino.Download.Manager (sha1HexFile)
import Panino.Download.VerificationIndex
  ( flushVerificationIndex
  , recordVerifiedFile
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )
import TestSupport
  ( assertEqual
  , removeIfExists
  )

assertDownloadVerification :: FilePath -> IO ()
assertDownloadVerification tempDir = do
  let shaPath = tempDir </> "panino-core-sha1-test.txt"
  BS8.writeFile shaPath "abc"
  runAssertions shaPath `finally` cleanup shaPath

runAssertions :: FilePath -> IO ()
runAssertions shaPath = do
  let indexPath = takeDirectory shaPath </> "verification-index.json"
  assertEqual
    "streaming sha1"
    "a9993e364706816aba3e25717850c26c9cd0d89d"
    =<< sha1HexFile shaPath
  setEnv "PANINO_VERIFICATION_INDEX" indexPath
  recordVerifiedFile shaPath (Just "a9993e364706816aba3e25717850c26c9cd0d89d")
  flushVerificationIndex

cleanup :: FilePath -> IO ()
cleanup shaPath = do
  unsetEnv "PANINO_VERIFICATION_INDEX"
  removeIfExists shaPath
  removeIfExists (takeDirectory shaPath </> "verification-index.json")
