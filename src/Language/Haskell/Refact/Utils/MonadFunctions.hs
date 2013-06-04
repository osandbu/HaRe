{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
module Language.Haskell.Refact.Utils.MonadFunctions
       (
         initRefactModule

       -- * Conveniences for state access

       -- * Original API provided
       , fetchToks -- ^Deprecated
       , fetchToksFinal
       , fetchOrigToks
       -- , putToks -- ^Deprecated, destroys token tree
       , getTypecheckedModule
       , getRefactStreamModified
       , getRefactInscopes
       , getRefactRenamed
       , putRefactRenamed
       , getRefactParsed
       , putParsedModule
       , clearParsedModule
       , getRefactFileName

       -- * TokenUtils API
       , putToksForSpan
       , getToksForSpan
       , getToksBeforeSpan
       , putToksForPos
       , putToksAfterSpan
       , putToksAfterPos
       , putDeclToksAfterSpan
       , removeToksForSpan
       , removeToksForPos
       , syncDeclToLatestStash

       -- , putSrcSpan -- ^Make sure a SrcSpan is in the tree

       -- , putNewSpanAndToks
       -- , putNewPosAndToks
       -- * Managing token stash

       -- * For debugging
       , drawTokenTree
       , getTokenTree

       -- * State flags for managing generic traversals
       , getRefactDone
       , setRefactDone
       , clearRefactDone

       , setStateStorage
       , getStateStorage

       , logm
       -- , Refact -- ^ TODO: Deprecated, use RefactGhc
       -- , runRefact -- ^ TODO: Deprecated, use runRefactGhc
       ) where

import Control.Monad.State

import qualified FastString    as GHC
import qualified GHC           as GHC
-- import qualified MonadUtils    as GHC
import qualified Outputable    as GHC

import qualified Data.Data as SYB

import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.TokenUtils
import Language.Haskell.Refact.Utils.TokenUtilsTypes
import Language.Haskell.Refact.Utils.TypeSyn

import Data.Tree
import System.Log.FastLogger
import qualified Data.Map as Map

-- ---------------------------------------------------------------------

-- |fetch the possibly modified tokens. Deprecated
fetchToks :: RefactGhc [PosToken]
fetchToks = do
  Just tm <- gets rsModule
  let toks = retrieveTokens $ (tkCache $ rsTokenCache tm) Map.! mainTid
  -- logm $ "fetchToks" ++ (showToks toks)
  logm $ "fetchToks (not showing toks"
  return toks

-- |fetch the final tokens
fetchToksFinal :: RefactGhc [PosToken]
fetchToksFinal = do
  Just tm <- gets rsModule
  let toks = retrieveTokensFinal $ (tkCache $ rsTokenCache tm) Map.! mainTid
  -- logm $ "fetchToks" ++ (showToks toks)
  logm $ "fetchToksFinal (not showing toks)"
  return toks

-- |fetch the pristine token stream
fetchOrigToks :: RefactGhc [PosToken]
fetchOrigToks = do
  logm "fetchOrigToks"
  Just tm <- gets rsModule
  return $ rsOrigTokenStream tm

{-
-- |Replace the module tokens with a modified set. This destroys any
-- pre-existing structure in the token tree
-- Deprecated
putToks :: [PosToken] -> Bool -> RefactGhc ()
putToks toks isModified = do
  logm $ "putToks " ++ (showToks toks)
  st <- get
  let Just tm = rsModule st
  let rsModule' = Just (tm {rsTokenCache = initTokenCache toks, rsStreamModified = isModified})
  put $ st { rsModule = rsModule' }
-}

-- TODO: ++AZ: these individual calls should happen via the TokenUtils
--       API, have a simple get/put interface here only

-- |Get the current tokens for a given GHC.SrcSpan.
getToksForSpan ::  GHC.SrcSpan -> RefactGhc [PosToken]
getToksForSpan sspan = do
  st <- get
  let Just tm = rsModule st
  let forest = getTreeFromCache sspan (rsTokenCache tm)
  let (forest',toks) = getTokensFor forest sspan
  let tk' = replaceTreeInCache sspan forest' $ rsTokenCache tm
  let rsModule' = Just (tm {rsTokenCache = tk'})
  put $ st { rsModule = rsModule' }
  logm $ "getToksForSpan " ++ (GHC.showPpr sspan) ++ ":" ++ (show (showSrcSpanF sspan,toks))
  return toks

-- |Get the current tokens preceding a given GHC.SrcSpan.
getToksBeforeSpan ::  GHC.SrcSpan -> RefactGhc [PosToken]
getToksBeforeSpan sspan = do
  st <- get
  let Just tm = rsModule st
  let forest = getTreeFromCache sspan (rsTokenCache tm)
  let (forest',toks) = getTokensBefore forest sspan
  let tk' = replaceTreeInCache sspan forest' $ rsTokenCache tm
  let rsModule' = Just (tm {rsTokenCache = tk'})
  put $ st { rsModule = rsModule' }
  logm $ "getToksBeforeSpan " ++ (GHC.showPpr sspan) ++ ":" ++ (show (showSrcSpanF sspan,toks))
  return toks

-- |Replace the tokens for a given GHC.SrcSpan, return new GHC.SrcSpan
-- delimiting new tokens
putToksForSpan ::  GHC.SrcSpan -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksForSpan sspan toks = do
  logm $ "putToksForSpan " ++ (GHC.showPpr sspan) ++ ":" ++ (showSrcSpanF sspan) ++ (show toks)
  st <- get
  let Just tm = rsModule st

  let (tk',newSpan) = putToksInCache (rsTokenCache tm) sspan toks
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True })
  put $ st { rsModule = rsModule' }
  -- stashName <- stash oldTree
  return newSpan

-- |Replace the tokens for a given GHC.SrcSpan, return GHC.SrcSpan
-- they are placed in
-- ++AZ++ TODO: This bypasses the tree selection process.Perhaps
--              deprecate the function
putToksForPos ::  (SimpPos,SimpPos) -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksForPos pos toks = do
  logm $ "putToksForPos " ++ (show pos) ++ (showToks toks)
  st <- get
  let Just tm = rsModule st
  let mainForest = (tkCache $ rsTokenCache tm) Map.! mainTid
  let sspan = posToSrcSpan mainForest pos
  let (tk',newSpan) = putToksInCache (rsTokenCache tm) sspan toks
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True })
  put $ st { rsModule = rsModule' }
  -- stashName <- stash oldTree
  drawTokenTree ""
  return newSpan

-- |Add tokens after a designated GHC.SrcSpan
putToksAfterSpan :: GHC.SrcSpan -> Positioning -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksAfterSpan oldSpan pos toks = do
  logm $ "putToksAfterSpan " ++ (GHC.showPpr oldSpan) ++ ":" ++ (showSrcSpanF oldSpan) ++ " at " ++ (show pos) ++ ":" ++ (showToks toks)
  st <- get
  let Just tm = rsModule st
  let forest = getTreeFromCache oldSpan (rsTokenCache tm)
  let (forest',newSpan) = addToksAfterSrcSpan forest oldSpan pos toks
  let tk' = replaceTreeInCache oldSpan forest' $ rsTokenCache tm
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return newSpan

-- |Add tokens after a designated GHC.SrcSpan
putToksAfterPos :: (SimpPos,SimpPos) -> Positioning -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksAfterPos pos position toks = do
  logm $ "putToksAfterPos " ++ (show pos) ++ " at "  ++ (show position) ++ ":" ++ (show toks)
  st <- get
  let Just tm = rsModule st
  let mainForest = (tkCache $ rsTokenCache tm) Map.! mainTid
  let sspan = posToSrcSpan mainForest pos
  let forest = getTreeFromCache sspan (rsTokenCache tm)
  let (forest',newSpan) = addToksAfterSrcSpan forest sspan position toks
  let tk' = replaceTreeInCache sspan forest' $ rsTokenCache tm
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  logm $ "putToksAfterPos result:" ++ (show forest') ++ "\ntree:\n" ++ (drawTreeEntry forest')
  return newSpan

-- |Add tokens after a designated GHC.SrcSpan, and update the AST
-- fragment to reflect it
putDeclToksAfterSpan :: (SYB.Data t) => GHC.SrcSpan -> GHC.Located t -> Positioning -> [PosToken] -> RefactGhc (GHC.Located t)
putDeclToksAfterSpan oldSpan t pos toks = do
  logm $ "putDeclToksAfterSpan " ++ (GHC.showPpr oldSpan) ++ ":" ++ (show (showSrcSpanF oldSpan,pos,toks))
  st <- get
  let Just tm = rsModule st
  let forest = getTreeFromCache oldSpan (rsTokenCache tm)
  let (forest',_newSpan, t') = addDeclToksAfterSrcSpan forest oldSpan pos toks t
  let tk' = replaceTreeInCache oldSpan forest' (rsTokenCache tm)
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return t'

-- |Remove a GHC.SrcSpan and its associated tokens
removeToksForSpan :: GHC.SrcSpan -> RefactGhc ()
removeToksForSpan sspan = do
  logm $ "removeToksForSpan " ++ (GHC.showPpr sspan) ++ ":" ++ (showSrcSpanF sspan)
  st <- get
  let Just tm = rsModule st
  let tk' = removeToksFromCache (rsTokenCache tm) sspan
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  -- stashName <- stash oldTree -- Create a new entry for the old tree
  return ()

-- |Remove a GHC.SrcSpan and its associated tokens
removeToksForPos :: (SimpPos,SimpPos) -> RefactGhc ()
removeToksForPos pos = do
  logm $ "removeToksForPos " ++ (show pos)
  st <- get
  let Just tm = rsModule st
  let mainForest = (tkCache $ rsTokenCache tm) Map.! mainTid
  let sspan = posToSrcSpan mainForest pos
  let tk' = removeToksFromCache (rsTokenCache tm) sspan
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  drawTokenTree "removeToksForPos result"
  return ()

{-
-- |Insert a GHC.SrcSpan into the tree if it is not already there
putSrcSpan ::  GHC.SrcSpan -> RefactGhc ()
putSrcSpan sspan = do
  logm $ "putSrcSpan " ++ (GHC.showPpr sspan) ++ ":" ++ (showSrcSpanF sspan) 
  st <- get
  let Just tm = rsModule st
  let forest = getTreeFromCache sspan (rsTokenCache tm)
  let forest' = insertSrcSpan forest (srcSpanToForestSpan sspan)
  let tk' = replaceTreeInCache sspan forest' $ rsTokenCache tm
  let rsModule' = Just (tm {rsTokenCache = tk', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return ()
-}

-- ---------------------------------------------------------------------

-- |Print the Token Tree for debug purposes
drawTokenTree :: String -> RefactGhc ()
drawTokenTree msg = do
  st <- get
  let Just tm = rsModule st
  -- let mainForest = (tkCache $ rsTokenCache tm) Map.! mainTid
  -- logm $ msg ++ "\ncurrent token tree:\n" ++ (drawTreeEntry mainForest)
  logm $ msg ++ "\ncurrent token tree:\n" ++ (drawTokenCache (rsTokenCache tm))
  return ()

-- ---------------------------------------------------------------------

-- |Get the Token Tree for debug purposes
getTokenTree :: RefactGhc (Tree Entry)
getTokenTree = do
  st <- get
  let Just tm = rsModule st
  let mainForest = (tkCache $ rsTokenCache tm) Map.! mainTid
  return mainForest

-- ---------------------------------------------------------------------

syncDeclToLatestStash :: (SYB.Data t) => (GHC.Located t) -> RefactGhc (GHC.Located t)
syncDeclToLatestStash t = do
  st <- get
  let Just tm = rsModule st
  let t' = syncAstToLatestCache (rsTokenCache tm) t
  return t'

-- ---------------------------------------------------------------------
{-
-- |Add a new GHC.SrcSpan and tokens
putNewSpanAndToks :: GHC.SrcSpan -> [PosToken] -> RefactGhc ()
putNewSpanAndToks newSpan toks = do
  st <- get
  let Just tm = rsModule st
  let (forest',_) = addNewSrcSpanAndToks (rsTokenCache tm) oldSpan toks
  let rsModule' = Just (tm {rsTokenCache = forest', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
-}

-- ---------------------------------------------------------------------

getTypecheckedModule :: RefactGhc GHC.TypecheckedModule
getTypecheckedModule = do
  Just tm <- gets rsModule
  return $ rsTypecheckedMod tm

getRefactStreamModified :: RefactGhc Bool
getRefactStreamModified = do
  Just tm <- gets rsModule
  return $ rsStreamModified tm

getRefactInscopes :: RefactGhc InScopes
getRefactInscopes = GHC.getNamesInScope

getRefactRenamed :: RefactGhc GHC.RenamedSource
getRefactRenamed = do
  mtm <- gets rsModule
  let tm = gfromJust "getRefactRenamed" mtm
  return $ gfromJust "getRefactRenamed2" $ GHC.tm_renamed_source $ rsTypecheckedMod tm

putRefactRenamed :: GHC.RenamedSource -> RefactGhc ()
putRefactRenamed renamed = do
  st <- get
  mrm <- gets rsModule
  let rm = gfromJust "putRefactRenamed" mrm
  let tm = rsTypecheckedMod rm
  let tm' = tm { GHC.tm_renamed_source = Just renamed }
  let rm' = rm { rsTypecheckedMod = tm' }
  put $ st {rsModule = Just rm'}

getRefactParsed :: RefactGhc GHC.ParsedSource
getRefactParsed = do
  mtm <- gets rsModule
  let tm = gfromJust "getRefactParsed" mtm
  let t  = rsTypecheckedMod tm

  let pm = GHC.tm_parsed_module t
  return $ GHC.pm_parsed_source pm

putParsedModule
  :: GHC.TypecheckedModule -> [PosToken] -> RefactGhc ()
putParsedModule tm toks = do
  st <- get
  put $ st { rsModule = initRefactModule tm toks }

clearParsedModule :: RefactGhc ()
clearParsedModule = do
  st <- get
  put $ st { rsModule = Nothing }


-- ---------------------------------------------------------------------

getRefactFileName :: RefactGhc (Maybe FilePath)
getRefactFileName = do
  mtm <- gets rsModule
  case mtm of
    Nothing  -> return Nothing
    Just _tm -> do toks <- fetchOrigToks
                   return $ Just (GHC.unpackFS $ fileNameFromTok $ ghead "getRefactFileName" toks)

-- ---------------------------------------------------------------------

getRefactDone :: RefactGhc Bool
getRefactDone = do
  flags <- gets rsFlags
  logm $ "getRefactDone: " ++ (show (rsDone flags))
  return (rsDone flags)

setRefactDone :: RefactGhc ()
setRefactDone = do
  logm $ "setRefactDone" 
  st <- get
  put $ st { rsFlags = RefFlags True }

clearRefactDone :: RefactGhc ()
clearRefactDone = do
  logm $ "clearRefactDone" 
  st <- get
  put $ st { rsFlags = RefFlags False }

-- ---------------------------------------------------------------------

setStateStorage :: StateStorage -> RefactGhc ()
setStateStorage storage = do
  st <- get
  put $ st { rsStorage = storage }

getStateStorage :: RefactGhc StateStorage
getStateStorage = do
  storage <- gets rsStorage
  return storage

-- ---------------------------------------------------------------------

logm :: String -> RefactGhc ()
logm string = do
  settings <- getRefacSettings
  when (rsetLoggingOn settings) $ liftIO $ warningM "HaRe" string
  -- liftIO $ putStrLn string
  return ()

-- ---------------------------------------------------------------------

initRefactModule
  :: GHC.TypecheckedModule -> [PosToken] -> Maybe RefactModule
initRefactModule tm toks
  = Just (RefMod { rsTypecheckedMod = tm
                 , rsOrigTokenStream = toks
                 , rsTokenCache = initTokenCache toks
                 , rsStreamModified = False
                 })


-- EOF

