{-# LANGUAGE OverloadedStrings #-}

module Integration.LoaderShaderFixtureServer
  ( fakeLoaderShaderPreflightApp
  , minecraftManifestFixture
  , minecraftVersionFixture
  , modrinthDependencyVersionsJson
  , modrinthIrisVersionsJson
  , modrinthProjectJson
  , modrinthProjectMetadataFixture
  , curseForgeFilesFixture
  , curseForgeProjectFixture
  , rateLimitedInstallerProbeApp
  ) where

import Control.Concurrent.MVar
  ( MVar
  , modifyMVar_
  )
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List
  ( isInfixOf
  , isPrefixOf
  )
import Network.HTTP.Types
  ( hContentType
  , status200
  , status206
  , status404
  , status429
  )
import Network.Wai
  ( Request
  , Response
  , ResponseReceived
  , queryString
  , rawPathInfo
  , requestHeaderHost
  , requestMethod
  , responseLBS
  )

rateLimitedInstallerProbeApp :: MVar Int -> MVar Int -> Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
rateLimitedInstallerProbeApp headRequests rangeRequests request respond = do
  let path = BS8.unpack (rawPathInfo request)
      json = responseLBS status200 [(hContentType, "application/json")]
      text = responseLBS status200 [(hContentType, "text/plain")]
      notFound = responseLBS status404 [(hContentType, "text/plain")] "missing"
      rateLimited = responseLBS status429 [(hContentType, "text/plain")] "too many requests"
      installerPath = "forge-26.1.429-50.0.429-installer.jar" `isInfixOf` path
  case path of
    "/net/minecraftforge/forge/promotions_slim.json" ->
      respond (json "{\"promos\":{\"26.1.429-recommended\":\"50.0.429\"}}")
    "/v2/versions/loader/26.1.429" ->
      respond (json "[]")
    "/v3/versions/loader/26.1.429" ->
      respond (json "[]")
    "/net/neoforged/neoforge/maven-metadata.xml" ->
      respond (text "<metadata><versioning><versions></versions></versioning></metadata>")
    _
      | installerPath && requestMethod request == "HEAD" -> do
          modifyMVar_ headRequests (pure . (+ 1))
          respond rateLimited
      | installerPath && requestMethod request == "GET" -> do
          modifyMVar_ rangeRequests (pure . (+ 1))
          respond (responseLBS status206 [(hContentType, "application/octet-stream"), ("Content-Range", "bytes 0-0/1")] "x")
      | otherwise ->
          respond notFound

fakeLoaderShaderPreflightApp :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
fakeLoaderShaderPreflightApp request respond = do
  let path = BS8.unpack (rawPathInfo request)
      queryText = show (queryString request)
      requestBase =
        "http://"
          <> BS8.unpack
            ( case requestHeaderHost request of
                Just host -> host
                Nothing -> "127.0.0.1"
            )
      json = responseLBS status200 [(hContentType, "application/json")]
      text = responseLBS status200 [(hContentType, "text/plain")]
      notFound = responseLBS status404 [(hContentType, "text/plain")] "missing"
      okEmpty = responseLBS status200 [(hContentType, "application/octet-stream")] ""
      binary = responseLBS status200 [(hContentType, "application/octet-stream")]
  respond $
    case path of
      "/mc/game/version_manifest_v2.json" -> json (minecraftManifestFixture requestBase)
      "/versions/26.1.2.json" -> json (minecraftVersionFixture requestBase)
      "/versions/missing-client.json" -> json (minecraftMissingClientVersionFixture requestBase)
      "/assets/indexes/empty.json" -> json "{\"objects\":{}}"
      "/client.jar" -> binary "fake-client-jar"
      "/example/loader/1.0/loader-1.0.jar" -> binary "fake-loader-library"
      "/org/quiltmc/quilt-loader/0.29.1/quilt-loader-0.29.1.jar" -> binary "fake-quilt-loader-library"
      "/net/fabricmc/intermediary/26.1.2/intermediary-26.1.2.jar" -> binary "fake-intermediary-library"
      "/data/iris/iris-1.0.0.jar" -> binary "fake-iris-jar"
      "/data/oculus/oculus-1.0.0.jar" -> binary "fake-oculus-jar"
      "/data/fabric-api/fabric-api-1.0.0.jar" -> binary "fake-fabric-api-jar"
      "/data/sodium/sodium-1.0.0.jar" -> binary "fake-sodium-jar"
      "/v2/versions/loader/26.1.2" -> json fabricLoaderFixture
      "/v2/versions/loader/bad-dep" -> json fabricLoaderFixture
      "/v2/versions/loader/unsupported" -> json "[]"
      "/v2/versions/loader/26.1.2/0.16.0/profile/json" -> json (loaderProfileFixture "fabric-loader-0.16.0-26.1.2" "26.1.2")
      "/v2/versions/loader/bad-dep/0.16.0/profile/json" -> json (loaderProfileFixture "fabric-loader-0.16.0-bad-dep" "bad-dep")
      "/v3/versions/loader/26.1.2" -> json quiltLoaderFixture
      "/v3/versions/loader/unsupported" -> json "[]"
      "/v3/versions/loader/26.1.2/0.29.1/profile/json" -> json (loaderProfileFixture "quilt-loader-0.29.1-26.1.2" "26.1.2")
      "/net/minecraftforge/forge/promotions_slim.json" -> json forgePromotionsFixture
      "/net/neoforged/neoforge/maven-metadata.xml" -> text neoForgeMetadataFixture
      "/v2/project/iris" -> json (modrinthProjectMetadataFixture "iris" "Iris")
      "/v2/project/oculus" -> json (modrinthProjectMetadataFixture "oculus" "Oculus")
      "/v2/project/fabric-api" -> json (modrinthProjectMetadataFixture "fabric-api" "Fabric API")
      "/v2/project/sodium" -> json (modrinthProjectMetadataFixture "sodium" "Sodium")
      "/v2/project/iris/version"
        | "bad-dep" `isInfixOf` queryText -> json modrinthBadDependencyFixture
        | "quilt" `isInfixOf` queryText -> json "[]"
        | otherwise -> json (modrinthProjectFixture "iris" "iris-1.0.0.jar")
      "/v2/project/oculus/version"
        | "neoforge" `isInfixOf` queryText -> json "[]"
        | otherwise -> json (modrinthProjectFixtureForLoader "oculus" "oculus-1.0.0.jar" "forge")
      "/v2/project/fabric-api/version" -> json (modrinthProjectFixture "fabric-api" "fabric-api-1.0.0.jar")
      "/v2/project/sodium/version" -> json (modrinthProjectFixture "sodium" "sodium-1.0.0.jar")
      _ | requestMethod request == "HEAD" && "forge-missing-installer" `isInfixOf` path -> notFound
      _ | requestMethod request == "HEAD" -> okEmpty
      _ | "installer.jar" `isInfixOf` path -> binary "fake-installer"
      _ -> notFound

fabricLoaderFixture :: BL.ByteString
fabricLoaderFixture =
  "[{\"loader\":{\"version\":\"0.16.0\",\"stable\":true},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}}]"

quiltLoaderFixture :: BL.ByteString
quiltLoaderFixture =
  "[{\"loader\":{\"version\":\"0.20.0-beta.9\"},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}},{\"loader\":{\"version\":\"0.24.0\",\"stable\":true},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}},{\"loader\":{\"version\":\"0.29.2-beta.5\",\"stable\":false},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}},{\"loader\":{\"version\":\"0.29.1\",\"stable\":true},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}}]"

minecraftManifestFixture :: String -> BL.ByteString
minecraftManifestFixture base =
  BL8.pack
    ( "{\"versions\":[{\"id\":\"26.1.2\",\"url\":\""
        <> base
        <> "/versions/26.1.2.json\"},{\"id\":\"missing-client\",\"url\":\""
        <> base
        <> "/versions/missing-client.json\"}]}"
    )

minecraftVersionFixture :: String -> BL.ByteString
minecraftVersionFixture base =
  BL8.pack
    ( "{\"id\":\"26.1.2\",\"type\":\"release\",\"javaVersion\":{\"majorVersion\":21},\"downloads\":{\"client\":{\"url\":\""
        <> base
        <> "/client.jar\"}},\"assetIndex\":{\"id\":\"empty\",\"url\":\""
        <> base
        <> "/assets/indexes/empty.json\"},\"libraries\":[],\"mainClass\":\"net.minecraft.client.main.Main\",\"arguments\":{\"game\":[],\"jvm\":[\"-Djava.library.path=${natives_directory}\",\"-cp\",\"${classpath}\"]}}"
    )

minecraftMissingClientVersionFixture :: String -> BL.ByteString
minecraftMissingClientVersionFixture base =
  BL8.pack
    ( "{\"id\":\"missing-client\",\"type\":\"release\",\"javaVersion\":{\"majorVersion\":21},\"downloads\":{},\"assetIndex\":{\"id\":\"empty\",\"url\":\""
        <> base
        <> "/assets/indexes/empty.json\"},\"libraries\":[],\"mainClass\":\"net.minecraft.client.main.Main\",\"arguments\":{\"game\":[],\"jvm\":[]}}"
    )

loaderProfileFixture :: String -> String -> BL.ByteString
loaderProfileFixture profileId inheritsFrom =
  BL8.pack
    ( "{\"id\":\""
        <> profileId
        <> "\",\"inheritsFrom\":\""
        <> inheritsFrom
        <> "\",\"mainClass\":\""
        <> profileMainClass
        <> "\",\"libraries\":[{\"name\":\""
        <> profileLibraryName
        <> "\",\"downloads\":{\"artifact\":{\"url\":\""
        <> profileLibraryUrl
        <> "\"}}}]}"
    )
  where
    isQuiltProfile = "quilt-loader-" `isPrefixOf` profileId
    profileMainClass =
      if isQuiltProfile
        then "org.quiltmc.loader.impl.launch.knot.KnotClient"
        else "net.fabricmc.loader.impl.launch.knot.KnotClient"
    profileLibraryName =
      if isQuiltProfile
        then "org.quiltmc:quilt-loader:0.29.1"
        else "example:loader:1.0"
    profileLibraryUrl =
      if isQuiltProfile
        then "https://libraries.minecraft.net/org/quiltmc/quilt-loader/0.29.1/quilt-loader-0.29.1.jar"
        else "https://libraries.minecraft.net/example/loader/1.0/loader-1.0.jar"

forgePromotionsFixture :: BL.ByteString
forgePromotionsFixture =
  "{\"promos\":{\"26.1.2-recommended\":\"50.0.1\",\"forge-missing-installer-recommended\":\"50.0.404\"}}"

neoForgeMetadataFixture :: BL.ByteString
neoForgeMetadataFixture =
  "<metadata><versioning><versions><version>26.1.2.1</version></versions></versioning></metadata>"

modrinthProjectFixture :: String -> String -> BL.ByteString
modrinthProjectFixture project modFileName =
  modrinthProjectFixtureForLoader project modFileName "fabric"

modrinthProjectFixtureForLoader :: String -> String -> String -> BL.ByteString
modrinthProjectFixtureForLoader project modFileName loaderName =
  BL8.pack
    ( "[{\"id\":\""
        <> project
        <> "-version\",\"project_id\":\""
        <> project
        <> "\",\"name\":\""
        <> project
        <> "\",\"version_number\":\"1.0.0\",\"dependencies\":[],\"game_versions\":[\"26.1.2\"],\"loaders\":[\""
        <> loaderName
        <> "\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"url\":\"https://cdn.modrinth.com/data/"
        <> project
        <> "/"
        <> modFileName
        <> "\",\"filename\":\""
        <> modFileName
        <> "\",\"primary\":true}]}]"
    )

modrinthBadDependencyFixture :: BL.ByteString
modrinthBadDependencyFixture =
  "[{\"id\":\"iris-bad\",\"project_id\":\"iris\",\"name\":\"Iris Bad\",\"version_number\":\"1.0.0\",\"dependencies\":[{\"dependency_type\":\"required\"}],\"game_versions\":[\"bad-dep\"],\"loaders\":[\"fabric\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"hashes\":{\"sha1\":\"1111111111111111111111111111111111111111\"},\"url\":\"https://cdn.example/iris.jar\",\"filename\":\"iris.jar\",\"primary\":true,\"size\":1234}]}]"

modrinthDependencyVersionsJson :: BL8.ByteString
modrinthDependencyVersionsJson =
  "[{\"id\":\"fabric-api-version\",\"project_id\":\"fabric-api\",\"name\":\"Fabric API\",\"version_number\":\"1.0.0\",\"dependencies\":[],\"game_versions\":[\"26.1.2\"],\"loaders\":[\"fabric\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"hashes\":{\"sha1\":\"1111111111111111111111111111111111111111\"},\"url\":\"https://cdn.example/fabric-api-1.0.0.jar\",\"filename\":\"fabric-api-1.0.0.jar\",\"primary\":true,\"size\":1234}]}]"

modrinthProjectMetadataFixture :: BL8.ByteString -> BL8.ByteString -> BL8.ByteString
modrinthProjectMetadataFixture projectIdValue title =
  BL8.concat
    [ "{\"id\":\""
    , projectIdValue
    , "\",\"project_id\":\""
    , projectIdValue
    , "\",\"slug\":\""
    , projectIdValue
    , "\",\"title\":\""
    , title
    , "\",\"description\":\""
    , title
    , "\",\"project_type\":\"mod\",\"versions\":[\"26.1.2\"],\"loaders\":[\"fabric\"],\"status\":\"approved\"}"
    ]

modrinthIrisVersionsJson :: BL8.ByteString
modrinthIrisVersionsJson =
  "[{\"id\":\"iris-version\",\"project_id\":\"iris\",\"name\":\"Iris\",\"version_number\":\"1.0.0\",\"dependencies\":[{\"project_id\":\"fabric-api\",\"dependency_type\":\"required\"}],\"game_versions\":[\"26.1.2\"],\"loaders\":[\"fabric\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"hashes\":{\"sha1\":\"2222222222222222222222222222222222222222\"},\"url\":\"https://cdn.example/iris-1.0.0.jar\",\"filename\":\"iris-1.0.0.jar\",\"primary\":true,\"size\":2345}]}]"

curseForgeProjectFixture :: Int -> BL8.ByteString -> BL8.ByteString
curseForgeProjectFixture projectIdValue name =
  BL8.concat
    [ "{\"data\":{\"id\":"
    , BL8.pack (show projectIdValue)
    , ",\"name\":\""
    , name
    , "\",\"slug\":\""
    , BL8.pack (show projectIdValue)
    , "\",\"summary\":\""
    , name
    , "\",\"classId\":6,\"latestFilesIndexes\":[{\"gameVersion\":\"26.1.2\",\"modLoader\":4}],\"status\":1}}"
    ]

curseForgeFilesFixture :: Int -> BL8.ByteString -> BL8.ByteString -> [Int] -> BL8.ByteString
curseForgeFilesFixture fileIdValue fileNameValue sha1 dependencies =
  BL8.concat
    [ "{\"data\":[{\"id\":"
    , BL8.pack (show fileIdValue)
    , ",\"displayName\":\""
    , fileNameValue
    , "\",\"fileName\":\""
    , fileNameValue
    , "\",\"fileLength\":3456,\"downloadUrl\":\"https://edge.forgecdn.net/files/"
    , BL8.pack (show fileIdValue)
    , "/"
    , fileNameValue
    , "\",\"gameVersions\":[\"26.1.2\",\"Fabric\"],\"releaseType\":1,\"hashes\":[{\"algo\":1,\"value\":\""
    , sha1
    , "\"}],\"dependencies\":["
    , BL8.intercalate "," (map curseDependencyFixture dependencies)
    , "]}]}"
    ]

curseDependencyFixture :: Int -> BL8.ByteString
curseDependencyFixture projectIdValue =
  BL8.concat
    [ "{\"modId\":"
    , BL8.pack (show projectIdValue)
    , ",\"relationType\":3}"
    ]

modrinthProjectJson :: BL8.ByteString
modrinthProjectJson =
  "{\"id\":\"sodium\",\"title\":\"Sodium\"}"
