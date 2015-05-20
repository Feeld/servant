{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ViewPatterns #-}
module Servant.Common.BaseUrl where

import Control.Monad.Catch (MonadThrow, throwM)
import Data.List
import GHC.Generics
import Network.HTTP.Client (HttpException(InvalidUrlException))
import Network.URI
import Safe
import Text.Read

-- | URI scheme to use
data Scheme =
    Http  -- ^ http://
  | Https -- ^ https://
  deriving (Show, Eq, Ord, Generic)

-- | Simple data type to represent the target of HTTP requests
--   for servant's automatically-generated clients.
data BaseUrl = BaseUrl
  { baseUrlScheme :: Scheme -- ^ URI scheme to use
  , baseUrlHost :: String   -- ^ host (eg "haskell.org")
  , baseUrlPort :: Int      -- ^ port (eg 80)
  } deriving (Show, Eq, Ord, Generic)

showBaseUrl :: BaseUrl -> String
showBaseUrl (BaseUrl urlscheme host port) =
  schemeString ++ "//" ++ host ++ portString
    where
      schemeString = case urlscheme of
        Http  -> "http:"
        Https -> "https:"
      portString = case (urlscheme, port) of
        (Http, 80) -> ""
        (Https, 443) -> ""
        _ -> ":" ++ show port

parseBaseUrl :: MonadThrow m => String -> m BaseUrl
parseBaseUrl s = case parseURI (removeTrailingSlash s) of
  -- This is a rather hacky implementation and should be replaced with something
  -- implemented in attoparsec (which is already a dependency anyhow (via aeson)).
  Just (URI "http:" (Just (URIAuth "" host (':' : (readMaybe -> Just port)))) "" "" "") ->
    return (BaseUrl Http host port)
  Just (URI "http:" (Just (URIAuth "" host "")) "" "" "") ->
    return (BaseUrl Http host 80)
  Just (URI "https:" (Just (URIAuth "" host (':' : (readMaybe -> Just port)))) "" "" "") ->
    return (BaseUrl Https host port)
  Just (URI "https:" (Just (URIAuth "" host "")) "" "" "") ->
    return (BaseUrl Https host 443)
  _ -> if "://" `isInfixOf` s
    then throwM (InvalidUrlException s "Invalid base URL")
    else parseBaseUrl ("http://" ++ s)
 where
  removeTrailingSlash str = case lastMay str of
    Just '/' -> init str
    _ -> str
