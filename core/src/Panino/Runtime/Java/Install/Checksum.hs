{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Runtime.Java.Install.Checksum
  ( fetchRuntimeSha256
  , verifySha256
  ) where

import Control.Exception
  ( SomeException
  , catch
  )
import Control.Monad (unless)
import Data.Char (isHexDigit)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Local.Path (removePathIfExists)
import Panino.Core.Types (urlString)
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , coreRequestWithTimeout
  , fetchText
  )
import Panino.Runtime.Java.Types (JavaRuntimeDownloadSpec(..))
import System.Exit (ExitCode(..))
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

fetchRuntimeSha256 :: Manager -> JavaRuntimeDownloadSpec -> IO Text
fetchRuntimeSha256 manager spec =
  case runtimeDownloadSha256 spec of
    Just sha256 -> pure sha256
    Nothing ->
      case runtimeDownloadChecksumUrl spec of
        Nothing -> fail "java_runtime_checksum_missing: provider did not expose checksum URL"
        Just url -> do
          text <- fetchText manager =<< coreRequestWithTimeout LongMetadata (urlString url) []
          maybe
            (fail "java_runtime_checksum_missing: checksum response did not contain SHA-256")
            pure
            (parseSha256 text)

verifySha256 :: FilePath -> Text -> IO ()
verifySha256 path expected = do
  actual <- sha256HexFile path
  unless (Text.toLower expected == Text.toLower actual) $ do
    removePathIfExists path
    fail "java_runtime_checksum_mismatch: downloaded Java archive failed SHA-256 verification"

parseSha256 :: Text -> Maybe Text
parseSha256 text =
  listToMaybe
    [ Text.toLower token
    | token <- Text.words text
    , Text.length token == 64
    , Text.all isHexDigit token
    ]

sha256HexFile :: FilePath -> IO Text
sha256HexFile path = do
  (exitCode, stdoutText, stderrText) <- tryShasum "/usr/bin/shasum" `catch` \(_ :: SomeException) -> tryShasum "shasum"
  case exitCode of
    ExitSuccess -> pure (parseOutput stdoutText)
    ExitFailure _ -> fail ("java_runtime_checksum_failed: " <> stderrText)
  where
    tryShasum command = do
      (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc command ["-a", "256", path]) ""
      pure (exitCode, stdoutText, stderrText)
    parseOutput =
      Text.toLower . Text.pack . takeWhile (/= ' ')
