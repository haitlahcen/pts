{-# LANGUAGE NoMonomorphismRestriction, FlexibleContexts #-}
module PTS.Main where

import Control.Monad.Assertions (checkAssertions)
import Control.Monad.Reader (runReaderT)
import Control.Monad.State (MonadState, evalStateT)
import Control.Monad.Trans (MonadIO, liftIO)
import Control.Monad.Log (runConsoleLogT)

import qualified Data.Set as Set

import Parametric.Error
import Parametric.Pretty hiding (when)

import PTS.Dynamics
import PTS.File
import PTS.Instances
import PTS.Options
import PTS.Statics
import PTS.Syntax

import System.Directory (findFile)
import System.Environment (getArgs)
import System.Exit (exitSuccess, exitFailure)
import System.IO (hPutStrLn, stderr, hFlush, stdout)

import Tools.Errors

infixl 2 >>>
(>>>) = flip (.)

main = parseCommandLine processJobs

runMainErrors act = do
  result <- runErrorsT act
  case result of
    Left errors -> do
      liftIO $ hFlush stdout
      liftIO $ hPutStrLn stderr $ showErrors $ errors
      return False
    Right result -> do
      return True

runMainState act = evalStateT act []

processJobs jobs = do
  success <- runMainState $ runMainErrors $ mapM_ processJob jobs
  if success
    then exitSuccess
    else exitFailure

processJob :: (Functor m, MonadIO m, MonadErrors [FOmegaError] m, MonadState [(Name, Binding M)] m) => (Options, FilePath) -> m ()
processJob (opt, file) = do
  let path = optPath opt
  file <- liftIO (findFile path file) >>= maybe (fail ("file not found: " ++ file)) return
  mod <- checkAssertions (runReaderT (runConsoleLogT (processFile file) (optDebugType opt)) opt)
  return ()
