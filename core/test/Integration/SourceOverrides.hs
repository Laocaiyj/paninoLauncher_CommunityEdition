module Integration.SourceOverrides
  ( assertSourceOverrides
  ) where

import Control.Exception (finally)
import Panino.Net.Http (metadataRetryCount)
import Panino.Net.Probe (sourceHostKey)
import Panino.Net.Sources (resolveSourceUrls)
import System.Environment
  ( setEnv
  , unsetEnv
  )
import TestSupport (assertEqual)

assertSourceOverrides :: IO ()
assertSourceOverrides =
  clearSourceOverrideEnv *> runAssertions `finally` clearSourceOverrideEnv

runAssertions :: IO ()
runAssertions = do
  setEnv "PANINO_MODRINTH_API_BASE" "https://mirror.example"
  assertEqual
    "source override keeps official fallback"
    [ "https://mirror.example/v2/search"
    , "https://api.modrinth.com/v2/search"
    ]
    =<< resolveSourceUrls "https://api.modrinth.com/v2/search"
  setEnv "PANINO_MODRINTH_API_BASE" "https://mirror-a.example,https://mirror-b.example/"
  assertEqual
    "source override accepts mirror profiles"
    [ "https://mirror-a.example/v2/search"
    , "https://mirror-b.example/v2/search"
    , "https://api.modrinth.com/v2/search"
    ]
    =<< resolveSourceUrls "https://api.modrinth.com/v2/search"
  setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
  assertEqual
    "source override can disable official fallback"
    [ "https://mirror-a.example/v2/search"
    , "https://mirror-b.example/v2/search"
    ]
    =<< resolveSourceUrls "https://api.modrinth.com/v2/search"
  unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
  unsetEnv "PANINO_MODRINTH_API_BASE"
  setEnv "PANINO_MOJANG_LIBRARIES_BASE" "https://libraries.mirror.example/maven"
  assertEqual
    "source override rewrites Mojang libraries"
    [ "https://libraries.mirror.example/maven/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
    , "https://libraries.minecraft.net/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
    ]
    =<< resolveSourceUrls "https://libraries.minecraft.net/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
  unsetEnv "PANINO_MOJANG_LIBRARIES_BASE"
  setEnv "PANINO_MOJANG_RESOURCES_BASE" "https://resources.mirror.example/assets"
  assertEqual
    "source override rewrites Mojang assets"
    [ "https://resources.mirror.example/assets/aa/hash"
    , "https://resources.download.minecraft.net/aa/hash"
    ]
    =<< resolveSourceUrls "https://resources.download.minecraft.net/aa/hash"
  unsetEnv "PANINO_MOJANG_RESOURCES_BASE"
  setEnv "PANINO_HTTP_RETRY_COUNT" "0"
  assertEqual "metadata retry count accepts zero" 0 =<< metadataRetryCount
  setEnv "PANINO_HTTP_RETRY_COUNT" "12"
  assertEqual "metadata retry count clamps high values" 10 =<< metadataRetryCount
  setEnv "PANINO_HTTP_RETRY_COUNT" "invalid"
  assertEqual "metadata retry count falls back on invalid input" 3 =<< metadataRetryCount
  unsetEnv "PANINO_HTTP_RETRY_COUNT"
  assertEqual
    "source host key keeps scheme and authority"
    "https://api.modrinth.com"
    (sourceHostKey "https://api.modrinth.com/v2/search")

clearSourceOverrideEnv :: IO ()
clearSourceOverrideEnv = do
  unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
  unsetEnv "PANINO_HTTP_RETRY_COUNT"
  unsetEnv "PANINO_MODRINTH_API_BASE"
  unsetEnv "PANINO_MOJANG_LIBRARIES_BASE"
  unsetEnv "PANINO_MOJANG_RESOURCES_BASE"
