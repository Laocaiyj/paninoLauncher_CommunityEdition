module Panino.Download.Hash
  ( FileDigest(..)
  , HashState
  , appendHashChunk
  , emptyHashState
  , finalizeHashState
  , hashFileState
  , sha1HexFile
  ) where

import qualified Crypto.Hash.SHA1 as SHA1
import qualified Data.ByteString as BS
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Word (Word8)
import Numeric (showHex)
import System.IO
  ( Handle
  , IOMode(ReadMode)
  , withBinaryFile
  )

data FileDigest = FileDigest
  { fileDigestSize :: Integer
  , fileDigestSha1 :: Text
  } deriving (Eq, Show)

data HashState = HashState
  { hashStateSize :: Integer
  , hashStateContext :: SHA1.Ctx
  }

sha1HexFile :: FilePath -> IO Text
sha1HexFile path =
  fileDigestSha1 . finalizeHashState <$> hashFileState path

hashFileState :: FilePath -> IO HashState
hashFileState path =
  withBinaryFile path ReadMode $ \handle ->
    hashLoop handle emptyHashState

hashLoop :: Handle -> HashState -> IO HashState
hashLoop handle context = do
  chunk <- BS.hGetSome handle 262144
  if BS.null chunk
    then pure context
    else hashLoop handle (appendHashChunk context chunk)

emptyHashState :: HashState
emptyHashState =
  HashState
    { hashStateSize = 0
    , hashStateContext = SHA1.init
    }

appendHashChunk :: HashState -> BS.ByteString -> HashState
appendHashChunk state chunk =
  HashState
    { hashStateSize = hashStateSize state + fromIntegral (BS.length chunk)
    , hashStateContext = SHA1.update (hashStateContext state) chunk
    }

finalizeHashState :: HashState -> FileDigest
finalizeHashState state =
  FileDigest
    { fileDigestSize = hashStateSize state
    , fileDigestSha1 = Text.pack (concatMap byteToHex (BS.unpack (SHA1.finalize (hashStateContext state))))
    }

byteToHex :: Word8 -> String
byteToHex byte =
  case showHex byte "" of
    [single] -> ['0', single]
    pair -> pair
