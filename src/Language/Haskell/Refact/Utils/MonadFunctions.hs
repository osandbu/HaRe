{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
module Language.Haskell.Refact.Utils.MonadFunctions
       (
         initRefactModule

       -- * Conveniences for state access

       -- * Original API provided
       , fetchToks -- ^Deprecated
       , fetchOrigToks
       , putToks -- ^Deprecated
       , getTypecheckedModule
       , getRefactStreamModified
       , getRefactInscopes
       , getRefactRenamed
       , putRefactRenamed
       , getRefactParsed
       , putParsedModule
       , clearParsedModule

       -- * TokenUtils API
       , putToksForSpan
       , getToksForSpan
       , putToksForPos
       , putToksAfterSpan
       , putToksAfterPos
       , putDeclToksAfterSpan
       , removeToksForSpan
       , removeToksForPos
       -- , putNewSpanAndToks
       -- , putNewPosAndToks

       -- * For debugging
       , getTokenTree

       -- * State flags for managing generic traversals
       , getRefactDone
       , setRefactDone
       , clearRefactDone

       -- , Refact -- ^ TODO: Deprecated, use RefactGhc
       -- , runRefact -- ^ TODO: Deprecated, use runRefactGhc
       ) where

import Control.Monad.State
import Data.Maybe
import Exception
import qualified Control.Monad.IO.Class as MU

import qualified Bag           as GHC
import qualified BasicTypes    as GHC
import qualified DynFlags      as GHC
import qualified FastString    as GHC
import qualified GHC           as GHC
import qualified GhcMonad      as GHC
import qualified GHC.Paths     as GHC
import qualified HsSyn         as GHC
import qualified Module        as GHC
-- import qualified MonadUtils    as GHC
import qualified Outputable    as GHC
import qualified RdrName       as GHC
import qualified SrcLoc        as GHC
import qualified TcEvidence    as GHC
import qualified TcType        as GHC
import qualified TypeRep       as GHC
import qualified Var           as GHC
import qualified Lexer         as GHC
import qualified Coercion      as GHC
import qualified ForeignCall   as GHC
import qualified InstEnv       as GHC

import qualified Data.Data as SYB

import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.TokenUtils
import Language.Haskell.Refact.Utils.TokenUtilsTypes
import Language.Haskell.Refact.Utils.TypeSyn

import Data.Tree

-- ---------------------------------------------------------------------

-- |fetch the possibly modified tokens. Deprecated
fetchToks :: RefactGhc [PosToken]
fetchToks = do
  Just tm <- gets rsModule
  liftIO $ putStrLn $ "fetchToks" ++ (showToks $ retrieveTokens $ rsTokenCache tm)
  return $ retrieveTokens $ rsTokenCache tm

-- |fetch the pristine token stream
fetchOrigToks :: RefactGhc [PosToken]
fetchOrigToks = do
  liftIO $ putStrLn "fetchOrigToks"
  Just tm <- gets rsModule
  return $ rsOrigTokenStream tm

-- |Replace the module tokens with a modified set. 
-- Deprecated
putToks :: [PosToken] -> Bool -> RefactGhc ()
putToks toks isModified = do
  liftIO $ putStrLn $ "putToks " ++ (showToks toks)
  st <- get
  let Just tm = rsModule st
  let rsModule' = Just (tm {rsTokenCache = mkTreeFromTokens toks, rsStreamModified = isModified})
  put $ st { rsModule = rsModule' }


-- TODO: ++AZ: these individual calls should happen via the TokenUtils
--       API, have a simple get/put interface here only

-- |Get the current tokens for a given GHC.SrcSpan.
getToksForSpan ::  GHC.SrcSpan -> RefactGhc [PosToken]
getToksForSpan sspan = do
  st <- get
  let Just tm = rsModule st
  let (forest',toks) = getTokensFor (rsTokenCache tm) sspan 
  let rsModule' = Just (tm {rsTokenCache = forest'})
  put $ st { rsModule = rsModule' }
  liftIO $ putStrLn $ "getToksForSpan " ++ (GHC.showPpr sspan) ++ ":" ++ (show (ghcSpanStartEnd sspan,toks))
  return toks


-- |Replace the tokens for a given GHC.SrcSpan, return new GHC.SrcSpan
-- delimiting new tokens
putToksForSpan ::  GHC.SrcSpan -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksForSpan sspan toks = do
  liftIO $ putStrLn $ "putToksForSpan " ++ (GHC.showPpr sspan)
  st <- get
  let Just tm = rsModule st
  let (forest',newSpan) = updateTokensForSrcSpan (rsTokenCache tm) sspan toks
  let rsModule' = Just (tm {rsTokenCache = forest', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return newSpan

-- |Replace the tokens for a given GHC.SrcSpan, return GHC.SrcSpan
-- they are placed in
putToksForPos ::  (SimpPos,SimpPos) -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksForPos pos toks = do
  liftIO $ putStrLn $ "putToksForPos " ++ (show pos) ++ (showToks toks)
  st <- get
  let Just tm = rsModule st
  let sspan = posToSrcSpan (rsTokenCache tm) pos
  let (forest',newSpan) = updateTokensForSrcSpan (rsTokenCache tm) sspan toks
  let rsModule' = Just (tm {rsTokenCache = forest', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return newSpan

-- |Add tokens after a designated GHC.SrcSpan
putToksAfterSpan :: GHC.SrcSpan -> Positioning -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksAfterSpan oldSpan pos toks = do
  liftIO $ putStrLn $ "putToksAfterSpan " ++ (GHC.showPpr oldSpan)
  st <- get
  let Just tm = rsModule st
  let (forest',newSpan) = addToksAfterSrcSpan (rsTokenCache tm) oldSpan pos toks
  let rsModule' = Just (tm {rsTokenCache = forest', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return newSpan

-- |Add tokens after a designated GHC.SrcSpan
putToksAfterPos :: (SimpPos,SimpPos) -> Positioning -> [PosToken] -> RefactGhc GHC.SrcSpan
putToksAfterPos pos position toks = do
  liftIO $ putStrLn $ "putToksAfterPos " ++ (show pos) ++ " at "  ++ (show position)
  st <- get
  let Just tm = rsModule st
  let sspan = posToSrcSpan (rsTokenCache tm) pos
  let (forest',newSpan) = addToksAfterSrcSpan (rsTokenCache tm) sspan position toks
  let rsModule' = Just (tm {rsTokenCache = forest', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return newSpan

-- |Add tokens after a designated GHC.SrcSpan, and update the AST
-- fragment to reflect it
putDeclToksAfterSpan :: (SYB.Data t) => GHC.SrcSpan -> GHC.Located t -> Positioning -> [PosToken] -> RefactGhc (GHC.Located t)
-- putDeclToksAfterSpan :: (SYB.Data t) => GHC.SrcSpan -> GHC.Located t -> Positioning -> [PosToken] -> RefactGhc t
putDeclToksAfterSpan oldSpan t pos toks = do
  liftIO $ putStrLn $ "putDeclToksAfterSpan " ++ (GHC.showPpr oldSpan) ++ ":" ++ (show (pos,toks))
  st <- get
  let Just tm = rsModule st
  let (forest'',_newSpan, t') = addDeclToksAfterSrcSpan (rsTokenCache tm) oldSpan pos toks t
  let rsModule' = Just (tm {rsTokenCache = forest'', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return t'

-- |Remove a GHC.SrcSpan and its associated tokens
removeToksForSpan :: GHC.SrcSpan -> RefactGhc ()
removeToksForSpan sspan = do
  liftIO $ putStrLn $ "removeToksForSpan " ++ (GHC.showPpr sspan)
  st <- get
  let Just tm = rsModule st
  let forest' = removeSrcSpan (rsTokenCache tm) (srcSpanToForestSpan sspan)
  let rsModule' = Just (tm {rsTokenCache = forest', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  return ()

-- |Remove a GHC.SrcSpan and its associated tokens
removeToksForPos :: (SimpPos,SimpPos) -> RefactGhc ()
removeToksForPos pos = do
  liftIO $ putStrLn $ "removeToksForPos " ++ (show pos)
  st <- get
  let Just tm = rsModule st
  let sspan = posToSrcSpan (rsTokenCache tm) pos
  let forest' = removeSrcSpan (rsTokenCache tm) (srcSpanToForestSpan sspan)
  let rsModule' = Just (tm {rsTokenCache = forest', rsStreamModified = True})
  put $ st { rsModule = rsModule' }
  liftIO $ putStrLn $ "removeToksForPos result:" ++ (show forest')
  return ()

-- ---------------------------------------------------------------------

-- |Get the Token Tree for debug purposes
getTokenTree :: RefactGhc (Tree Entry)
getTokenTree = do
  st <- get
  let Just tm = rsModule st
  return (rsTokenCache tm)

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

getRefactDone :: RefactGhc Bool
getRefactDone = do
  flags <- gets rsFlags
  return (rsDone flags)

setRefactDone :: RefactGhc ()
setRefactDone = do
  st <- get
  put $ st { rsFlags = RefFlags True }

clearRefactDone :: RefactGhc ()
clearRefactDone = do
  st <- get
  put $ st { rsFlags = RefFlags False }

-- ---------------------------------------------------------------------

initRefactModule
  :: GHC.TypecheckedModule -> [PosToken] -> Maybe RefactModule
initRefactModule tm toks 
  = Just (RefMod { rsTypecheckedMod = tm
                 , rsOrigTokenStream = toks
                 , rsTokenCache = mkTreeFromTokens toks
                 , rsStreamModified = False
                 })


-- EOF

