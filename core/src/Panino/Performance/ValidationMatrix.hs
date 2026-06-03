{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.ValidationMatrix
  ( ProfilePrior(..)
  , ValidationHardware(..)
  , ValidationInstance(..)
  , ValidationResult(..)
  , ValidationScenario(..)
  , defaultValidationHardwareMatrix
  , defaultValidationInstances
  , defaultValidationMatrix
  , generateProfilePriors
  , successiveHalving
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.List
  ( sortOn
  )
import Data.Maybe (mapMaybe)
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Performance.Objective
  ( PerformanceScore(..)
  )

data ValidationInstance = ValidationInstance
  { validationInstanceId :: Text
  , validationInstanceKind :: Text
  , validationInstanceLoader :: Maybe Text
  , validationInstanceShader :: Bool
  } deriving (Eq, Show)

instance ToJSON ValidationInstance where
  toJSON instanceSpec =
    object
      [ "id" .= validationInstanceId instanceSpec
      , "kind" .= validationInstanceKind instanceSpec
      , "loader" .= validationInstanceLoader instanceSpec
      , "shader" .= validationInstanceShader instanceSpec
      ]

data ValidationHardware = ValidationHardware
  { validationHardwareChip :: Text
  , validationHardwareMemoryGb :: Int
  , validationHardwareDisplay :: Text
  } deriving (Eq, Show)

instance ToJSON ValidationHardware where
  toJSON hardware =
    object
      [ "chip" .= validationHardwareChip hardware
      , "memoryGb" .= validationHardwareMemoryGb hardware
      , "display" .= validationHardwareDisplay hardware
      ]

data ValidationScenario = ValidationScenario
  { validationScenarioId :: Text
  , validationScenarioInstance :: ValidationInstance
  , validationScenarioHardware :: ValidationHardware
  } deriving (Eq, Show)

instance ToJSON ValidationScenario where
  toJSON scenario =
    object
      [ "id" .= validationScenarioId scenario
      , "instance" .= validationScenarioInstance scenario
      , "hardware" .= validationScenarioHardware scenario
      ]

data ValidationResult = ValidationResult
  { validationResultScenarioId :: Text
  , validationResultProfileId :: Text
  , validationResultKind :: Text
  , validationResultStatus :: Text
  , validationResultScore :: Maybe PerformanceScore
  } deriving (Eq, Show)

instance ToJSON ValidationResult where
  toJSON result =
    object
      [ "scenarioId" .= validationResultScenarioId result
      , "profileId" .= validationResultProfileId result
      , "kind" .= validationResultKind result
      , "status" .= validationResultStatus result
      , "score" .= validationResultScore result
      ]

data ProfilePrior = ProfilePrior
  { profilePriorProfileId :: Text
  , profilePriorScenarioCount :: Int
  , profilePriorAverageScore :: Double
  , profilePriorRejectedCount :: Int
  } deriving (Eq, Show)

instance ToJSON ProfilePrior where
  toJSON prior =
    object
      [ "profileId" .= profilePriorProfileId prior
      , "scenarioCount" .= profilePriorScenarioCount prior
      , "averageScore" .= profilePriorAverageScore prior
      , "rejectedCount" .= profilePriorRejectedCount prior
      ]

defaultValidationInstances :: [ValidationInstance]
defaultValidationInstances =
  [ ValidationInstance "vanilla" "vanilla" Nothing False
  , ValidationInstance "light-fabric" "light_fabric" (Just "fabric") False
  , ValidationInstance "medium-modpack" "medium_modpack" (Just "fabric") False
  , ValidationInstance "large-modpack" "large_modpack" (Just "fabric") False
  , ValidationInstance "shader" "shader" (Just "fabric") True
  ]

defaultValidationHardwareMatrix :: [ValidationHardware]
defaultValidationHardwareMatrix =
  [ ValidationHardware chip memory display
  | chip <- ["M1", "M2", "M3", "M4"]
  , memory <- [8, 16, 32]
  , display <- ["builtin", "external"]
  ]

defaultValidationMatrix :: [ValidationScenario]
defaultValidationMatrix =
  [ ValidationScenario
      (validationInstanceId instanceSpec <> "-" <> validationHardwareChip hardware <> "-" <> memoryText hardware <> "-" <> validationHardwareDisplay hardware)
      instanceSpec
      hardware
  | instanceSpec <- defaultValidationInstances
  , hardware <- defaultValidationHardwareMatrix
  ]
  where
    memoryText hardware = "mem" <> fromStringInt (validationHardwareMemoryGb hardware)

successiveHalving :: Int -> [ValidationResult] -> [ValidationResult]
successiveHalving survivors results =
  take (max 1 survivors) $
    sortOn (Down . resultRank) $
      filter ((== "complete") . validationResultStatus) results
  where
    resultRank result =
      case validationResultScore result of
        Just score
          | not (scoreRejected score) -> scoreOverall score
        _ -> -1

generateProfilePriors :: [ValidationResult] -> [ProfilePrior]
generateProfilePriors results =
  mapMaybe priorFor profileIds
  where
    completeResults = filter ((== "complete") . validationResultStatus) results
    profileIds = unique (map validationResultProfileId completeResults)
    priorFor profileId =
      let matches = filter ((== profileId) . validationResultProfileId) completeResults
          scores = mapMaybe validationResultScore matches
          usable = filter (not . scoreRejected) scores
       in case scores of
            [] -> Nothing
            _ ->
              Just
                ProfilePrior
                  { profilePriorProfileId = profileId
                  , profilePriorScenarioCount = length scores
                  , profilePriorAverageScore =
                      if null usable
                        then 0
                        else sum (map scoreOverall usable) / fromIntegral (length usable)
                  , profilePriorRejectedCount = length (filter scoreRejected scores)
                  }

unique :: Eq a => [a] -> [a]
unique =
  foldr (\item acc -> if item `elem` acc then acc else item : acc) []

fromStringInt :: Int -> Text
fromStringInt =
  Text.pack . show
