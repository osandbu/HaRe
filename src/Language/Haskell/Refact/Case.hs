module Language.Haskell.Refact.Case(ifToCase) where

import qualified Data.Generics.Schemes as SYB
import qualified Data.Generics.Aliases as SYB
import qualified GHC.SYB.Utils         as SYB

import qualified GHC
import qualified DynFlags              as GHC
import qualified Outputable            as GHC
import qualified MonadUtils            as GHC
import qualified Name                  as GHC
import qualified RdrName               as GHC
import qualified OccName               as GHC

import qualified Data.Generics as SYB
import qualified GHC.SYB.Utils as SYB

import GHC.Paths ( libdir )
import Control.Monad
import Control.Monad.State
import Data.Data
import Data.Maybe

import Language.Haskell.Refact.Utils
import Language.Haskell.Refact.Utils.GhcUtils
import Language.Haskell.Refact.Utils.LocUtils
import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.MonadUtils
import Language.Haskell.Refact.Utils.TokenUtils
import Language.Haskell.Refact.Utils.TypeSyn
import Language.Haskell.Refact.Utils.TypeUtils

-- ---------------------------------------------------------------------

-- TODO: This boilerplate will be moved to the coordinator, just the refac session will be exposed
ifToCase :: [String] -> IO () -- For now
ifToCase args
  = do let fileName = args!!0
           beginPos = (read (args!!1), read (args!!2))::(Int,Int)
           endPos   = (read (args!!3), read (args!!4))::(Int,Int)
       runRefacSession Nothing (comp fileName beginPos endPos)
       return ()

comp :: String -> SimpPos -> SimpPos -> RefactGhc [ApplyRefacResult]
comp fileName beginPos endPos = do
       -- TODO: bring in getModuleGhc
       modInfo@(t, _toks) <- parseSourceFileGhc fileName
       let renamed = gfromJust "ifToCase" $ GHC.tm_renamed_source t
       let expr = locToExp beginPos endPos renamed
       case expr of
         Just exp1@(GHC.L _ (GHC.HsIf _ _ _ _))
                -> do refactoredMod <- applyRefac (doIfToCase exp1) (Just modInfo ) fileName
                      return [refactoredMod]
         _      -> error $ "You haven't selected an if-then-else  expression!" --  ++ (show (beginPos,endPos,fileName)) ++ "]:" ++ (SYB.showData SYB.Parser 0 $ ast)

doIfToCase ::
  GHC.Located (GHC.HsExpr GHC.Name)
  -> RefactGhc ()
doIfToCase expr = do
  rs <- getRefactRenamed
  reallyDoIfToCase expr rs

reallyDoIfToCase ::
  GHC.Located (GHC.HsExpr GHC.Name)
  -> GHC.RenamedSource
  -> RefactGhc ()
reallyDoIfToCase expr rs = do
   
   everywhereMStaged SYB.Renamer (SYB.mkM inExp) rs
   return ()
       where
         inExp :: (GHC.Located (GHC.HsExpr GHC.Name)) -> RefactGhc (GHC.Located (GHC.HsExpr GHC.Name))

         inExp exp1@(GHC.L _ (GHC.HsIf _ _ _ _))
           | sameOccurrence expr exp1
           = do
               newExp <- ifToCaseTransform exp1
               -- _ <- update exp1 newExp exp1
               updateToks exp1 newExp prettyprint True
               return newExp

         inExp e = return e

-- TODO: rearrange the structure and preserve the comments in the original, e.g. in e1,e2,e3
ifToCaseTransform :: GHC.Located (GHC.HsExpr GHC.Name) -> RefactGhc (GHC.Located (GHC.HsExpr GHC.Name))
ifToCaseTransform (GHC.L l (GHC.HsIf _se e1 e2 e3)) = do
  trueName  <- mkNewGhcName "True"
  falseName <- mkNewGhcName "False"
  let ret = GHC.L l (GHC.HsCase e1
             (GHC.MatchGroup
              [
                (GHC.noLoc $ GHC.Match
                 [
                   GHC.noLoc $ GHC.ConPatIn (GHC.noLoc trueName) (GHC.PrefixCon [])
                 ]
                 Nothing
                 ((GHC.GRHSs
                   [
                     GHC.noLoc $ GHC.GRHS [] e2
                   ] GHC.EmptyLocalBinds))
                )
              , (GHC.noLoc $ GHC.Match
                 [
                   GHC.noLoc $ GHC.ConPatIn (GHC.noLoc falseName) (GHC.PrefixCon [])
                 ]
                 Nothing
                 ((GHC.GRHSs
                   [
                     GHC.noLoc $ GHC.GRHS [] e3
                   ] GHC.EmptyLocalBinds))
                )
              ] undefined))
  return ret
ifToCaseTransform x = return x

-- ---------------------------------------------------------------------

-- EOF



