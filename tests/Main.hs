{-# LANGUAGE QuasiQuotes #-}
module Main where

import Test.Hspec
import System.IO.Temp
import Data.String.Interpolate (i)
import System.Process

main :: IO ()
main = hspec spec

spec :: IO ()
spec = do

  describe "garnix.enable" $
    it "fails if fileSystems./ is overriden" $ do
     [i|
       {
         fileSystems."/".device = "/dev/sdb1";
       }
     |] =!!> "fileSystems./.device must be set to /dev/sda1"
    it "fails if bootloader is overriden" $ do
    it "succeeds if nothing else is set" $ do

  describe "garnix.persistence.enable" $


(=!>) :: String -> String -> Expectation
conf =!> expectedErr = withSystemTempDirectory "garnix-lib" $ \dir -> do
  (ExitFailure _, _, err) <- readProcessWithExitCode "nix" ["build"
  err `shouldContain` expectedErr
