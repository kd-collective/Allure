module Main where

import System.Directory

import Action
import State
import DungeonState
import qualified Display
import Random
import qualified Save
import Turn
import qualified Config
import ActorAdd
import Item
import qualified Keys as K

main :: IO ()
main = Display.startup start

-- | Either restore a saved game, or setup a new game.
start :: Display.InternalSession -> IO ()
start internalSession = do
  config <- Config.config
  let section = Config.getItems config "macros"
      !macros = K.macroKey section
      sess = (internalSession, macros)
  -- check if we have a savegame
  f <- Save.file config
  b <- doesFileExist f
  restored <- if b
              then do
                     Display.displayBlankConfirm sess "Restoring save game"
                     Save.restoreGame config
              else return $ Right "Welcome to Allure of the Stars!"  -- new game
  case restored of
    Right msg  -> do
      -- TODO: move somewhere sane
      configS <-
        case Config.getOption config "engine" "startingRandomGenerator" of
          Just g -> do
            setStdGen g
            return config
          Nothing -> do
            -- Record the randomly chosen starting generator for debugging.
            g <- getStdGen
            return $ Config.set config "engine" "startingRandomGenerator" g
      (ploc, lvl, dng) <- rndToIO $ generate configS
      asso <- rndToIO dungeonAssocs
      let defState = defaultState dng lvl
          state = defState { sconfig = configS, sassocs = asso }
          hstate = initialHeroes ploc state
      handlerToIO sess hstate msg handle
    Left (state, g) -> do
      setStdGen g
      handlerToIO sess state "Welcome back to Allure of the Stars." handle
