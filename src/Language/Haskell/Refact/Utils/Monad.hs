{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
module Language.Haskell.Refact.Utils.Monad
       ( ParseResult
       -- , RefactResult
       , RefactSettings(..)
       , RefactState(..)
       , RefactModule(..)
       , RefactFlags(..)
       -- , initRefactModule
       -- GHC monad stuff
       , RefactGhc
       , runRefactGhc
       , getRefacSettings

       {- ++AZ++ moved to MonadUtils, to break import cycle
       -- * Conveniences for state access
       , fetchToks
       , fetchOrigToks
       , putToks
       , getTypecheckedModule
       , getRefactStreamModified
       , getRefactInscopes
       , getRefactRenamed
       , putRefactRenamed
       , getRefactParsed
       , putParsedModule
       , clearParsedModule

       -- * State flags for managing generic traversals
       , getRefactDone
       , setRefactDone
       , clearRefactDone
       -}

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
import qualified MonadUtils    as GHC
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

import Language.Haskell.Refact.Utils.TokenUtilsTypes
import Language.Haskell.Refact.Utils.TypeSyn

import Data.Tree

-- ---------------------------------------------------------------------

data RefactSettings = RefSet
        { rsetImportPath :: [FilePath]
        } deriving (Show)

data RefactModule = RefMod
        { rsTypecheckedMod :: GHC.TypecheckedModule
        , rsOrigTokenStream :: [PosToken]  -- ^Original Token stream for the current module
        -- , rsTokenStream     :: [PosToken]  -- ^Token stream for the current module, maybe modified
        , rsTokenCache :: Tree Entry -- ^Token stream for the current module, maybe modified, in SrcSpan tree form
        , rsStreamModified :: Bool     -- ^current module has updated the token stream
        }

data RefactFlags = RefFlags
       { rsDone :: Bool -- ^Current traversal has already made a change
       }

-- | State for refactoring a single file. Holds/hides the token
-- stream, which gets updated transparently at key points.
data RefactState = RefSt
        { rsSettings :: RefactSettings -- ^Session level settings
        , rsUniqState :: Int -- ^ Current Unique creator value, incremented every time it is used
        , rsFlags :: RefactFlags -- ^ Flags for controlling generic traversals
        -- The current module being refactored
        , rsModule :: Maybe RefactModule
        }

-- |Result of parsing a Haskell source file. The first element in the
-- result is the inscope relation, the second element is the export
-- relation and the third is the AST of the module. This is likely to
-- change as we learn more
type ParseResult = GHC.TypecheckedModule


-- ---------------------------------------------------------------------
-- StateT and GhcT stack

type RefactGhc a = GHC.GhcT (StateT RefactState IO) a

instance (MonadIO (GHC.GhcT (StateT RefactState IO))) where
         liftIO = GHC.liftIO

instance GHC.MonadIO (StateT RefactState IO) where
         liftIO f = MU.liftIO f

instance ExceptionMonad m => ExceptionMonad (StateT s m) where
    gcatch f h = StateT $ \s -> gcatch (runStateT f s) (\e -> runStateT (h e) s)
    gblock = mapStateT gblock
    gunblock = mapStateT gunblock

instance (MonadState RefactState (GHC.GhcT (StateT RefactState IO))) where
    get = lift get
    put = lift . put
    -- state = lift . state

instance (MonadTrans GHC.GhcT) where
   lift = GHC.liftGhcT

{-
instance MonadPlus (RefactGhc a) where
   mzero = RefactGhc (StateT(\ st -> mzero))

   -- x `mplus` y =  RefactGhc (StateT ( \ st -> runRefact x st `mplus` runRefact y st))  
   -- ^Try one of the refactorings, x or y, with the same state plugged in
-}

{-
instance (MonadPlus (GHC.GhcT (StateT RefactState IO))) where
  mzero = lift mzero

  -- For somewhereMStaged to work, the b leg should only be evaluated
  -- if the a leg is mzero
  mplus a b = do
                a' <- a 
                case a' of
                  mzero -> do
                            b'  <- b
                            return b'
                  _ -> return a'
-}

runRefactGhc ::
  RefactGhc a -> RefactState -> IO (a, RefactState)
runRefactGhc comp initState = do
    runStateT (GHC.runGhcT (Just GHC.libdir) comp) initState

getRefacSettings :: RefactGhc RefactSettings
getRefacSettings = do
  s <- get
  return (rsSettings s)

-- ---------------------------------------------------------------------
{- ++AZ++ moved to MonadUtils, to break import cycle


fetchToks :: RefactGhc [PosToken]
fetchToks = do
  Just tm <- gets rsModule
  return $ rsTokenStream tm

fetchOrigToks :: RefactGhc [PosToken]
fetchOrigToks = do
  Just tm <- gets rsModule
  return $ rsOrigTokenStream tm

putToks :: [PosToken] -> Bool -> RefactGhc ()
putToks toks isModified = do
  st <- get
  let Just tm = rsModule st
  let rsModule' = Just (tm {rsTokenStream = toks, rsStreamModified = isModified})
  put $ st { rsModule = rsModule' }

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

++AZ++ end of move to MonadUtils -}

-- ---------------------------------------------------------------------
-- ++AZ++ trying to wrap this in GhcT, or vice versa
-- For inspiration:
-- https://github.com/bjpop/berp/blob/200fa0f26a4da7c6f6ff6fcdc29a2468a1c39e60/src/Berp/Interpreter/Monad.hs
{-
type Repl a = GhcT (StateT ReplState Compile) a

data ReplState = ReplState { repl_inputState :: !InputState }

runRepl :: Maybe FilePath -> Repl a -> IO a
runRepl filePath comp = do
   initInputState <- initializeInput defaultSettings
   let initReplState = ReplState { repl_inputState = initInputState }
   runCompileMonad $ (flip evalStateT) initReplState $ runGhcT filePath comp

withInputState :: (InputState -> Repl a) -> Repl a
withInputState f = do
   state <- liftGhcT $ gets repl_inputState
   f state

-- Ugliness because GHC has its own MonadIO class
instance MU.MonadIO m => MonadIO (GhcT m) where
   liftIO = MU.liftIO

instance MonadIO m => MU.MonadIO (StateT s m) where
   liftIO = MT.liftIO

instance ExceptionMonad m => ExceptionMonad (StateT s m) where
    gcatch f h = StateT $ \s -> gcatch (runStateT f s) (\e -> runStateT (h e) s)
    gblock = mapStateT gblock
    gunblock = mapStateT gunblock
-}

