module Panino.Core.CommandLine
  ( FlagDefinition
  , ParsedFlags
  , firstNonBlank
  , hasFlag
  , lookupFlag
  , parseFlags
  , parseIntFlag
  , requireFlag
  , requireIntFlag
  , switchFlag
  , valueFlag
  ) where

import Data.Char (isSpace)
import Text.Read (readMaybe)

data FlagDefinition =
  FlagDefinition String FlagArity
  deriving (Eq, Show)

data FlagArity
  = RequiresValue
  | SwitchOnly
  deriving (Eq, Show)

data FlagValue
  = FlagValue String String
  | BareFlag String
  deriving (Eq, Show)

newtype ParsedFlags =
  ParsedFlags [FlagValue]
  deriving (Eq, Show)

valueFlag :: String -> FlagDefinition
valueFlag flag = FlagDefinition flag RequiresValue

switchFlag :: String -> FlagDefinition
switchFlag flag = FlagDefinition flag SwitchOnly

parseFlags :: [FlagDefinition] -> [String] -> Either String ParsedFlags
parseFlags definitions args =
  ParsedFlags <$> go args
  where
    go [] = Right []
    go (arg:rest)
      | not (isFlag arg) = Left ("unexpected argument: " <> arg)
      | Just (flag, value) <- splitFlagAssignment arg = do
          arity <- lookupDefinition definitions flag
          case arity of
            RequiresValue -> (FlagValue flag value :) <$> go rest
            SwitchOnly -> Left ("flag does not take a value: " <> flag)
      | otherwise = do
          arity <- lookupDefinition definitions arg
          case arity of
            SwitchOnly -> (BareFlag arg :) <$> go rest
            RequiresValue ->
              case rest of
                value:remaining
                  | not (isFlag value) -> (FlagValue arg value :) <$> go remaining
                _ -> Left ("missing value for flag: " <> arg)

lookupDefinition :: [FlagDefinition] -> String -> Either String FlagArity
lookupDefinition [] flag = Left ("unknown flag: " <> flag)
lookupDefinition (FlagDefinition name arity:rest) flag
  | name == flag = Right arity
  | otherwise = lookupDefinition rest flag

splitFlagAssignment :: String -> Maybe (String, String)
splitFlagAssignment arg =
  case break (== '=') arg of
    (flag, '=':value)
      | isFlag flag -> Just (flag, value)
    _ -> Nothing

isFlag :: String -> Bool
isFlag ('-':'-':_) = True
isFlag _ = False

lookupFlag :: String -> ParsedFlags -> Maybe String
lookupFlag flag (ParsedFlags values) = go values
  where
    go [] = Nothing
    go (FlagValue key value:rest)
      | key == flag = Just value
      | otherwise = go rest
    go (_:rest) = go rest

hasFlag :: String -> ParsedFlags -> Bool
hasFlag flag (ParsedFlags values) =
  any (== BareFlag flag) values

requireFlag :: String -> ParsedFlags -> Either String String
requireFlag flag values =
  case lookupFlag flag values of
    Just value -> Right value
    Nothing -> Left ("missing required flag: " <> flag)

parseIntFlag :: String -> Int -> ParsedFlags -> Either String Int
parseIntFlag flag fallback values =
  case lookupFlag flag values of
    Nothing -> Right fallback
    Just value -> parsePositiveInt flag value

requireIntFlag :: String -> ParsedFlags -> Either String Int
requireIntFlag flag values =
  case lookupFlag flag values of
    Nothing -> Left ("missing required flag: " <> flag)
    Just value -> parsePositiveInt flag value

parsePositiveInt :: String -> String -> Either String Int
parsePositiveInt flag value =
  case readMaybe value of
    Just parsed
      | parsed > 0 -> Right parsed
    _ -> Left ("invalid integer for " <> flag <> ": " <> value)

firstNonBlank :: [Maybe String] -> Maybe String
firstNonBlank [] = Nothing
firstNonBlank (Nothing:rest) = firstNonBlank rest
firstNonBlank (Just value:rest) =
  case trim value of
    "" -> firstNonBlank rest
    trimmed -> Just trimmed

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace

dropWhileEnd :: (a -> Bool) -> [a] -> [a]
dropWhileEnd predicate = reverse . dropWhile predicate . reverse
