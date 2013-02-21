{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- Sample refactoring based on ifToCase
import Bag
import Bag(Bag,bagToList)
import Data.Generics
import FastString(FastString)
import GHC.Paths ( libdir )
import GHC.SYB.Utils
import RdrName
import OccName
import qualified OccName(occNameString)


-----------------
import Language.Haskell.Refact.Utils.GhcUtils as SYB

import qualified Data.Generics.Schemes as SYB
import qualified Data.Generics.Aliases as SYB
import qualified GHC.SYB.Utils         as SYB

import Var
import qualified CoreFVs               as GHC
import qualified CoreSyn               as GHC
import qualified DynFlags              as GHC
import qualified FastString            as GHC
import qualified GHC                   as GHC
import qualified HscTypes              as GHC
import qualified MonadUtils            as GHC
import qualified Outputable            as GHC
import qualified SrcLoc                as GHC
import qualified StringBuffer          as GHC

import GHC.Paths ( libdir )
 
-----------------

import Language.Haskell.Refact.Utils
import Language.Haskell.Refact.Utils.LocUtils
import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.TokenUtils
import Language.Haskell.Refact.Utils.TypeUtils
import qualified Language.Haskell.Refact.Case as GhcRefacCase
import qualified Language.Haskell.Refact.SwapArgs as GhcSwapArgs
import qualified Language.Haskell.Refact.Rename as GhcRefacRename

import Control.Monad.State

import Control.Lens
import Control.Applicative
import Control.Lens
import Control.Lens.Plated
import Data.Data
import Data.Data.Lens(uniplate,biplate,template,tinplate)

import Language.Haskell.Refact.Utils.GhcUtils

-- targetFile = "./refactorer/" ++ targetMod ++ ".hs"

-- targetFile = "./test/testdata/" ++ targetMod ++ ".hs"
-- targetMod = "FreeAndDeclared/Declare"

--targetFile = "../test/testdata/" ++ targetMod ++ ".hs"

targetFile = "./test/testdata/TypeUtils/" ++ targetMod ++ ".hs"
--targetFile = "./" ++ targetMod ++ ".hs"
-- targetMod = "SwapArgs/B"
-- targetMod = "Ole"
targetMod = "Empty"

{- main = t1 -}

t1 = GhcRefacCase.ifToCase ["../old/refactorer/B.hs","4","7","4","43"]
t2 = GhcRefacCase.ifToCase ["./old/B.hs","4","7","4","43"]

s1 = GhcSwapArgs.swapArgs ["../test/testdata/SwapArgs/B.hs","10","1"]

{-
s1 = GhcSwapArgs.swapArgs ["../old/refactorer/B.hs","6","1"]
s2 = GhcSwapArgs.swapArgs ["./old/refactorer/B.hs","6","1"]
-}

-- added by Chris for renaming
r1 = GhcRefacRename.rename ["./Ole.hs", "Cas", "18", "1"]  -- lambda
r2 = GhcRefacRename.rename ["./Ole.hs", "j", "21", "1"] -- case of
r3 = GhcRefacRename.rename ["./Ole.hs", "x", "26", "19"] -- if else / par
r4 = GhcRefacRename.rename ["./Ole.hs", "kkk", "30", "1"] -- pattern binding
r5 = GhcRefacRename.rename ["./Ole.hs", "bob", "14", "15"] -- let
r6 = GhcRefacRename.rename ["./Ole.hs", "a", "33", "1"] -- where clause
r7 = GhcRefacRename.rename ["./Ole.hs", "newBlah", "38", "6"] -- data declaration

p1 = 
  do
    toks <- lexStringToRichTokens (GHC.mkRealSrcLoc (GHC.mkFastString "foo") 0 0) "if (1) then x else y"
    putStrLn $ showToks toks



-- import RefacUtils 
{-
ifToCase args  
  = do let fileName = args!!0              
           beginPos = (read (args!!1), read (args!!2))::(Int,Int)
           endPos   = (read (args!!3), read (args!!4))::(Int,Int)
       modInfo@(_, _, mod, toks) <- parseSourceFile fileName 
       let exp = locToExp beginPos endPos toks mod
       case exp of 
           (Exp (HsIf _ _ _))   
                -> do refactoredMod <- applyRefac (ifToCase exp) (Just modInfo) fileName          
                      writeRefactoredFiles False [refactoredMod]
           _   -> error "You haven't selected an if-then-else  expression!"
    where 

     ifToCase exp (_, _, mod)= applyTP (once_buTP (failTP `adhocTP` inExp)) mod
       where 
         inExp exp1@((Exp (HsIf  e e1 e2))::HsExpP)
           | sameOccurrence exp exp1       
           = let newExp =Exp (HsCase e [HsAlt loc0 (nameToPat "True") (HsBody e1) [],
                                        HsAlt loc0 (nameToPat "False")(HsBody e2) []])
             in update exp1 newExp exp1
         inExp _ = mzero
-}

-- data HsExpr id
--   ...
--   HsIf (Maybe (SyntaxExpr id)) (LHsExpr id) (LHsExpr id) (LHsExpr id)
--                                  ^1            ^2           ^3
--   ...
--  HsCase (LHsExpr id) (MatchGroup id)
--            ^1

-- data MatchGroup id
--   MatchGroup [LMatch id] PostTcType	
-- type LMatch id = Located (Match id)
-- data Match id 
--   Match [LPat id] (Maybe (LHsType id)) (GRHSs id)	 

getStuff =
    GHC.defaultErrorHandler GHC.defaultLogAction $ do
      GHC.runGhc (Just libdir) $ do
        dflags <- GHC.getSessionDynFlags
        let dflags' = foldl GHC.xopt_set dflags
                            [GHC.Opt_Cpp, GHC.Opt_ImplicitPrelude, GHC.Opt_MagicHash]

            dflags'' = dflags' { GHC.importPaths = ["./test/testdata/","../test/testdata/"] }

            dflags''' = dflags'' { GHC.hscTarget = GHC.HscInterpreted,
                                   GHC.ghcLink =  GHC.LinkInMemory }
 
        GHC.setSessionDynFlags dflags'''

        target <- GHC.guessTarget targetFile Nothing
        GHC.setTargets [target]
        GHC.load GHC.LoadAllTargets -- Loads and compiles, much as calling make
        -- modSum <- GHC.getModSummary $ GHC.mkModuleName "B"
        -- modSum <- GHC.getModSummary $ GHC.mkModuleName "FreeAndDeclared.Declare"
        -- modSum <- GHC.getModSummary $ GHC.mkModuleName "SwapArgs.B"
        -- modSum <- GHC.getModSummary $ GHC.mkModuleName "Ole"
        modSum <- GHC.getModSummary $ GHC.mkModuleName targetMod
        p <- GHC.parseModule modSum

        t <- GHC.typecheckModule p
        d <- GHC.desugarModule t
        l <- GHC.loadModule d
        n <- GHC.getNamesInScope
        -- c <- return $ GHC.coreModule d
        c <- return $ GHC.coreModule d

        GHC.setContext [GHC.IIModule (GHC.ms_mod modSum)]
        inscopes <- GHC.getNamesInScope
        

        g <- GHC.getModuleGraph
        gs <- mapM GHC.showModule g
        -- GHC.liftIO (putStrLn $ "modulegraph=" ++ (show gs))
        -- return $ (parsedSource d,"/n-----/n",  typecheckedSource d, "/n-=-=-=-=-=-=-/n", modInfoTyThings $ moduleInfo t)
        -- return $ (parsedSource d,"/n-----/n",  typecheckedSource d, "/n-=-=-=-=-=-=-/n")
        -- return $ (typecheckedSource d)
        
        -- res <- getRichTokenStream (ms_mod modSum)
        -- return $ showRichTokenStream res

        {-
        let ps = convertSource $ pm_parsed_source p
        let res = showData Parser 4 ps
        -- let res = showPpr ps
        return res
        -}
        -- let p' = processParsedMod ifToCase t
        -- GHC.liftIO (putStrLn . showParsedModule $ t)
        -- GHC.liftIO (putStrLn . showParsedModule $ p')
        -- GHC.liftIO (putStrLn $ GHC.showPpr $ GHC.tm_typechecked_source p')

        let ps  = GHC.pm_parsed_source p
        -- GHC.liftIO (putStrLn $ SYB.showData SYB.Parser 0 ps)
        -- GHC.liftIO (putStrLn $ show (modIsExported ps))
        -- _ <- processVarUniques t

        -- Tokens ------------------------------------------------------
        rts <- GHC.getRichTokenStream (GHC.ms_mod modSum)
        -- GHC.liftIO (putStrLn $ "tokens=" ++ (showRichTokenStream rts))
        -- GHC.liftIO (putStrLn $ "tokens=" ++ (show $ tokenLocs rts))
        -- GHC.liftIO (putStrLn $ "tokens=" ++ (show $ map (\(GHC.L _ tok,s) -> (tok,s)) rts)) 
        -- GHC.liftIO (putStrLn $ "tokens=" ++ (showToks rts))

        -- addSourceToTokens :: RealSrcLoc -> StringBuffer -> [Located Token] -> [(Located Token, String)]
        -- let tt = GHC.addSourceToTokens (GHC.mkRealSrcLoc (GHC.mkFastString "f") 1 1) (GHC.stringToStringBuffer "hiding (a,b)") []
        -- GHC.liftIO (putStrLn $ "new tokens=" ++ (showToks tt))
  

        -- GHC.liftIO (putStrLn $ "ghcSrcLocs=" ++ (show $ ghcSrcLocs ps))
        -- GHC.liftIO (putStrLn $ "srcLocs=" ++ (show $ srcLocs ps))

        -- GHC.liftIO (putStrLn $ "locToExp=" ++ (showPpr $ locToExp (4,12) (4,16) rts ps))
        -- GHC.liftIO (putStrLn $ "locToExp=" ++ (SYB.showData SYB.Parser 0 $ locToExp (4,12) (4,16) rts ps))
        -- GHC.liftIO (putStrLn $ "locToExp1=" ++ (SYB.showData SYB.Parser 0 $ locToExp (4,8) (4,43) rts ps))
        -- GHC.liftIO (putStrLn $ "locToExp2=" ++ (SYB.showData SYB.Parser 0 $ locToExp (4,8) (4,40) rts ps))


        -- Inscopes ----------------------------------------------------
        -- GHC.liftIO (putStrLn $ "\ninscopes(showData)=" ++ (SYB.showData SYB.Parser 0 $ inscopes))
        -- names <- GHC.parseName "G.mkT"
        -- GHC.liftIO (putStrLn $ "\nparseName=" ++ (GHC.showPpr $ names))


        -- ParsedSource -----------------------------------------------
        -- GHC.liftIO (putStrLn $ "parsedSource(Ppr)=" ++ (GHC.showPpr $ GHC.pm_parsed_source p))
        -- GHC.liftIO (putStrLn $ "\nparsedSource(showData)=" ++ (SYB.showData SYB.Parser 0 $ GHC.pm_parsed_source p))

        -- RenamedSource -----------------------------------------------
        GHC.liftIO (putStrLn $ "renamedSource(Ppr)=" ++ (GHC.showPpr $ GHC.tm_renamed_source t))
        GHC.liftIO (putStrLn $ "\nrenamedSource(showData)=" ++ (SYB.showData SYB.Renamer 0 $ GHC.tm_renamed_source t))

        -- GHC.liftIO (putStrLn $ "typeCheckedSource=" ++ (GHC.showPpr $ GHC.tm_typechecked_source t))
        -- GHC.liftIO (putStrLn $ "typeCheckedSource=" ++ (SYB.showData SYB.TypeChecker 0 $ GHC.tm_typechecked_source t))

        -- ModuleInfo ----------------------------------------------------------------
        -- GHC.liftIO (putStrLn $ "moduleInfo.TyThings=" ++ (SYB.showData SYB.Parser 0 $ GHC.modInfoTyThings $ GHC.tm_checked_module_info t))
        -- GHC.liftIO (putStrLn $ "moduleInfo.TyThings=" ++ (GHC.showPpr $ GHC.modInfoTyThings $ GHC.tm_checked_module_info t))
        -- GHC.liftIO (putStrLn $ "moduleInfo.TopLevelScope=" ++ (GHC.showPpr $ GHC.modInfoTopLevelScope $ GHC.tm_checked_module_info t))


        -- Investigating TypeCheckedModule, in t
        --GHC.liftIO (putStrLn $ "TypecheckedModule : tm_renamed_source(Ppr)=" ++ (GHC.showPpr $ GHC.tm_renamed_source t))
        --GHC.liftIO (putStrLn $ "TypecheckedModule : tm_renamed_source(showData)=" ++ (SYB.showData SYB.Parser 0 $ GHC.tm_renamed_source t))

        -- GHC.liftIO (putStrLn $ "TypecheckedModule : tm_typechecked_source(Ppr)=" ++ (GHC.showPpr $ GHC.tm_typechecked_source t))
        -- GHC.liftIO (putStrLn $ "TypecheckedModule : tm_typechecked_source(showData)=" ++ (SYB.showData SYB.Parser 0 $ GHC.tm_typechecked_source t))


        -- Core module -------------------------------------------------
        -- GHC.liftIO (putStrLn $ "TypecheckedModuleCoreModule : cm_binds(showData)=" ++ (SYB.showData SYB.TypeChecker 0 $ GHC.mg_binds c))

        -- GHC.liftIO (putStrLn $ "TypecheckedModuleCoreModule : cm_binds(showData)=" ++ (SYB.showData SYB.TypeChecker 0 $ GHC.exprsFreeVars $ getBinds $ GHC.mg_binds c))
        -- GHC.liftIO (putStrLn $ "TypecheckedModuleCoreModule : exprFreeVars cm_binds(showData)=" ++ (GHC.showPpr $ GHC.exprsFreeVars $ getBinds $ GHC.mg_binds c))
        -- GHC.liftIO (putStrLn $ "TypecheckedModuleCoreModule : exprFreeIds cm_binds(showPpr)=" ++ (GHC.showPpr $ map GHC.exprFreeIds $ getBinds $ GHC.mg_binds c))

        -- GHC.liftIO (putStrLn $ "TypecheckedModuleCoreModule : bindFreeVars cm_binds(showPpr)=" ++ (GHC.showPpr $ map GHC.bindFreeVars $ GHC.mg_binds c))


        return ()

-- processVarUniques :: (SYB.Data a) => a -> IO a
processVarUniques t = SYB.everywhereMStaged SYB.TypeChecker (SYB.mkM showUnique) t
    where
        showUnique (var :: Var)
           = do GHC.liftIO $ putStrLn (GHC.showPpr (varUnique var))
                return var
        showUnique x = return x


tokenLocs toks = map (\(GHC.L l _, s) -> (l,s)) toks

getBinds :: [GHC.CoreBind] -> [GHC.CoreExpr]
getBinds xs = map (\(_,x) -> x) $ concatMap getBind xs
  where
    getBind (GHC.NonRec b e) = [(b,e)]
    getBind (GHC.Rec bs) = bs


instance (Show GHC.TyThing) where
  show (GHC.AnId anId) = "(AnId " ++ (show anId) ++ ")"
  show _               = "(Another TyThing)"

-- instance (Show GHC.Name) where

convertSource ps =1
  ps

ifToCase :: GHC.HsExpr GHC.RdrName -> GHC.HsExpr GHC.RdrName
--  HsIf (Maybe (SyntaxExpr id)) (LHsExpr id) (LHsExpr id) (LHsExpr id)
ifToCase (GHC.HsIf _se e1 e2 e3)
  = GHC.HsCase e1 (GHC.MatchGroup
                   [
                     (GHC.noLoc $ GHC.Match
                      [
                        GHC.noLoc $ GHC.ConPatIn (GHC.noLoc $ mkRdrUnqual $ mkVarOcc "True") (GHC.PrefixCon [])
                      ]
                      Nothing
                       ((GHC.GRHSs
                         [
                           GHC.noLoc $ GHC.GRHS [] e2
                         ] GHC.EmptyLocalBinds))
                      )
                   , (GHC.noLoc $ GHC.Match
                      [
                        GHC.noLoc $ GHC.ConPatIn (GHC.noLoc $ mkRdrUnqual $ mkVarOcc "False") (GHC.PrefixCon [])
                      ]
                      Nothing
                       ((GHC.GRHSs
                         [
                           GHC.noLoc $ GHC.GRHS [] e3
                         ] GHC.EmptyLocalBinds))
                      )
                   ] undefined)
ifToCase x                          = x

-- -----------------------------------------------------------------------------------------

-- Playing with Lens

-- 1. Investigate foldMapOf :: Getter a c -> (c ->r) -> a -> r

data Foo = Foo { fa:: Bar String }  deriving (Data,Typeable,Show)

data Bar a = Bar { ba :: Maybe a
                 , bb :: Baz a
                 , bc :: [Baz a]
                 , dc :: a
                 } deriving (Data,Typeable,Show)

data Baz a = Baz a deriving (Data,Typeable,Show)

td = Foo (Bar Nothing (Baz "Mary") [Baz "a",Baz "b",Baz "c"] "d")

getBaz (Baz b) = [Baz b]

qq :: (Data a) => a -> [Baz String]
qq = foldMapOf template getBaz

gg = qq td


-- filtered :: (Gettable f, Applicative f) => (c -> Bool) -> LensLike f a b c d -> LensLike f a b c d
-- hh = filtered isBaz foo

-- ii :: (Data a) => a -> [Baz String]
-- ii = foldMapOf hh getBaz

-- template :: (Data a, Typeable b) => Simple Traversal a b
foo :: (Data a, Typeable a) => Simple Traversal a a
foo = template

isBaz (Baz a) = True
isBaz _ = False



-- -----------------------------------------------------------------------------------------
-- From http://hpaste.org/65775
{-
   1. install first: ghc-paths, ghc-syb-utils
   2. make a file Test1.hs in this dir with what you want to parse/transform
   3 .run with: ghci -package ghc
-}

-- module Main where

 
-- main = example

example :: IO ()
example =
   GHC.runGhc (Just libdir) $ do
        dflags <- GHC.getSessionDynFlags
        let dflags' = foldl GHC.xopt_set dflags
                            [GHC.Opt_Cpp, GHC.Opt_ImplicitPrelude, GHC.Opt_MagicHash]
        _ <- GHC.setSessionDynFlags dflags'
        -- target <- GHC.guessTarget (targetMod ++ ".hs") Nothing
        target <- GHC.guessTarget targetFile Nothing
        GHC.setTargets [target]
        _ <- GHC.load GHC.LoadAllTargets
        modSum <- GHC.getModSummary $ GHC.mkModuleName targetMod
        p' <- GHC.parseModule modSum
        p <- GHC.typecheckModule p'
        let p' = processParsedMod shortenLists p
        -- GHC.liftIO (putStrLn . showParsedModule $ p)
        -- GHC.liftIO (putStrLn . showParsedModule $ p')
        GHC.liftIO (putStrLn $ GHC.showPpr $ GHC.tm_typechecked_source p')

showParsedModule p = SYB.showData SYB.TypeChecker 0 (GHC.tm_typechecked_source p)

processParsedMod f pm = pm { GHC.tm_typechecked_source = ps' }
  where
   ps  = GHC.tm_typechecked_source pm
   -- ps' = SYB.everythingStaged SYB.Parser (SYB.mkT f) -- does not work yet
   -- everythingStaged :: Stage -> (r -> r -> r) -> r -> GenericQ r -> GenericQ r
   
   ps' :: GHC.TypecheckedSource
   ps' = SYB.everywhere (SYB.mkT f) ps -- exception
   -- ps' = everywhereStaged SYB.Parser (SYB.mkT f) ps 


shortenLists :: GHC.HsExpr GHC.RdrName -> GHC.HsExpr GHC.RdrName
shortenLists (GHC.ExplicitList t exprs) = GHC.ExplicitList t []
shortenLists x                          = x

--
-- ---------------------------------------------------------------------
-- Test drive the RefactGhc monad transformer stack
{-
runR :: IO ()
runR = do
  let
   -- initialState = ReplState { repl_inputState = initInputState }
   initialState = RefSt 
	{ rsSettings = RefSet ["."]
        , rsUniqState = 1
        , rsTokenStream = [] -- :: [PosToken]
	, rsStreamModified = False -- :: Bool
	-- , rsPosition = (-1,-1) -- :: (Int,Int)
        }
  (_,s) <- runRefactGhc comp initialState
  -- putStrLn $ show (rsPosition s)
  return ()

comp :: RefactGhc ()
comp = do
    s <- get
    modInfo@((_, _, mod), toks) <- parseSourceFileGhc "./old/refactorer/B.hs"
    -- -- gs <- mapM GHC.showModule mod
    g <- GHC.getModuleGraph
    gs <- mapM GHC.showModule g
    GHC.liftIO (putStrLn $ "modulegraph=" ++ (show gs))
    -- put (s {rsPosition = (123,456)})
    return ()
-}

-- ---------------------------------------------------------------------
{-
module B where
foo x = if (odd x) then \"Odd\" else \"Even\"
foo' x
  = case (odd x) of {
      True -> \"Odd\"
      False -> \"Even\" }
main = do { putStrLn $ show $ foo 5 }
mary = [1, 2, 3]"
*Main> :load "/home/alanz/mysrc/github/alanz/HaRe/refactorer/AzGhcPlay.hs"
[1 of 1] Compiling Main             ( /home/alanz/mysrc/github/alanz/HaRe/refactorer/AzGhcPlay.hs, interpreted )
Ok, modules loaded: Main.
*Main> 
*Main> 
*Main> 
*Main> getStuff
"
    (L {refactorer/B.hs:1:1} 
     (HsModule 
      (Just 
       (L {refactorer/B.hs:1:8} {ModuleName: B})) 
      (Nothing) 
      [] 
      [
       (L {refactorer/B.hs:4:1-41} 
        (ValD 
         (FunBind 
          (L {refactorer/B.hs:4:1-3} 
           (Unqual {OccName: foo})) 
          (False) 
          (MatchGroup 
           [
            (L {refactorer/B.hs:4:1-41} 
             (Match 
              [
               (L {refactorer/B.hs:4:5} 
                (VarPat 
                 (Unqual {OccName: x})))] 
              (Nothing) 
              (GRHSs 
               [
                (L {refactorer/B.hs:4:9-41} 
                 (GRHS 
                  [] 
                  (L {refactorer/B.hs:4:9-41} 
                   (HsIf 
                    (Just 
                     (HsLit 
                      (HsString {FastString: \"noSyntaxExpr\"}))) 
                    (L {refactorer/B.hs:4:12-18} 
                     (HsPar 
                      (L {refactorer/B.hs:4:13-17} 
                       (HsApp 
                        (L {refactorer/B.hs:4:13-15} 
                         (HsVar 
                          (Unqual {OccName: odd}))) 
                        (L {refactorer/B.hs:4:17} 
                         (HsVar 
                          (Unqual {OccName: x}))))))) 
                    (L {refactorer/B.hs:4:25-29} 
                     (HsLit 
                      (HsString {FastString: \"Odd\"}))) 
                    (L {refactorer/B.hs:4:36-41} 
                     (HsLit 
                      (HsString {FastString: \"Even\"})))))))] 
               (EmptyLocalBinds))))] {!type placeholder here?!}) 
          (WpHole) {!NameSet placeholder here!} 
          (Nothing)))),
       (L {refactorer/B.hs:(6,1)-(8,17)} 
        (ValD 
         (FunBind 
          (L {refactorer/B.hs:6:1-4} 
           (Unqual {OccName: foo'})) 
          (False) 
          (MatchGroup 
           [
            (L {refactorer/B.hs:(6,1)-(8,17)} 
             (Match 
              [
               (L {refactorer/B.hs:6:6} 
                (VarPat 
                 (Unqual {OccName: x})))] 
              (Nothing) 
              (GRHSs 
               [
                (L {refactorer/B.hs:(6,10)-(8,17)} 
                 (GRHS 
                  [] 
                  (L {refactorer/B.hs:(6,10)-(8,17)} 
                   (HsCase 
                    (L {refactorer/B.hs:6:15-21} 
                     (HsPar 
                      (L {refactorer/B.hs:6:16-20} 
                       (HsApp 
                        (L {refactorer/B.hs:6:16-18} 
                         (HsVar 
                          (Unqual {OccName: odd}))) 
                        (L {refactorer/B.hs:6:20} 
                         (HsVar 
                          (Unqual {OccName: x}))))))) 
                    (MatchGroup 
                     [
                      (L {refactorer/B.hs:7:3-15} 
                       (Match 
                        [
                         (L {refactorer/B.hs:7:3-6} 
                          (ConPatIn 
                           (L {refactorer/B.hs:7:3-6} 
                            (Unqual {OccName: True})) 
                           (PrefixCon 
                            [])))] 
                        (Nothing) 
                        (GRHSs 
                         [
                          (L {refactorer/B.hs:7:11-15} 
                           (GRHS 
                            [] 
                            (L {refactorer/B.hs:7:11-15} 
                             (HsLit 
                              (HsString {FastString: \"Odd\"})))))] 
                         (EmptyLocalBinds)))),
                      (L {refactorer/B.hs:8:3-17} 
                       (Match 
                        [
                         (L {refactorer/B.hs:8:3-7} 
                          (ConPatIn 
                           (L {refactorer/B.hs:8:3-7} 
                            (Unqual {OccName: False})) 
                           (PrefixCon 
                            [])))] 
                        (Nothing) 
                        (GRHSs 
                         [
                          (L {refactorer/B.hs:8:12-17} 
                           (GRHS 
                            [] 
                            (L {refactorer/B.hs:8:12-17} 
                             (HsLit 
                              (HsString {FastString: \"Even\"})))))] 
                         (EmptyLocalBinds))))] {!type placeholder here?!})))))] 
               (EmptyLocalBinds))))] {!type placeholder here?!}) 
          (WpHole) {!NameSet placeholder here!} 
          (Nothing)))),
       (L {refactorer/B.hs:(10,1)-(11,25)} 
        (ValD 
         (FunBind 
          (L {refactorer/B.hs:10:1-4} 
           (Unqual {OccName: main})) 
          (False) 
          (MatchGroup 
           [
            (L {refactorer/B.hs:(10,1)-(11,25)} 
             (Match 
              [] 
              (Nothing) 
              (GRHSs 
               [
                (L {refactorer/B.hs:(10,8)-(11,25)} 
                 (GRHS 
                  [] 
                  (L {refactorer/B.hs:(10,8)-(11,25)} 
                   (HsDo 
                    (DoExpr) 
                    [
                     (L {refactorer/B.hs:11:3-25} 
                      (ExprStmt 
                       (L {refactorer/B.hs:11:3-25} 
                        (OpApp 
                         (L {refactorer/B.hs:11:3-17} 
                          (OpApp 
                           (L {refactorer/B.hs:11:3-10} 
                            (HsVar 
                             (Unqual {OccName: putStrLn}))) 
                           (L {refactorer/B.hs:11:12} 
                            (HsVar 
                             (Unqual {OccName: $}))) {!fixity placeholder here?!} 
                           (L {refactorer/B.hs:11:14-17} 
                            (HsVar 
                             (Unqual {OccName: show}))))) 
                         (L {refactorer/B.hs:11:19} 
                          (HsVar 
                           (Unqual {OccName: $}))) {!fixity placeholder here?!} 
                         (L {refactorer/B.hs:11:21-25} 
                          (HsApp 
                           (L {refactorer/B.hs:11:21-23} 
                            (HsVar 
                             (Unqual {OccName: foo}))) 
                           (L {refactorer/B.hs:11:25} 
                            (HsOverLit 
                             (OverLit 
                              (HsIntegral 
                               (5)) 
                              (*** Exception: noRebindableInfo
   -}

