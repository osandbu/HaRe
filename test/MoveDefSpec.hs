module MoveDefSpec (main, spec) where

import           Test.Hspec
import           Test.QuickCheck

import qualified GHC      as GHC
import qualified GhcMonad as GHC
import qualified RdrName  as GHC
import qualified SrcLoc   as GHC

import Exception
import Control.Monad.State
import Language.Haskell.Refact.MoveDef
import Language.Haskell.Refact.Utils
import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.LocUtils

import TestUtils

-- ---------------------------------------------------------------------

main :: IO ()
main = hspec spec

spec :: Spec
spec = do

  -- -------------------------------------------------------------------

  describe "doLiftToTopLevel" $ do
    it "Cannot lift a top level declaration" $ do
     res <- catchException (doLiftToTopLevel ["./test/testdata/MoveDef/Md1.hs","4","1"])
     (show res) `shouldBe` "Just \"\\nThe identifier is not a local function/pattern name!\""

    it "checks for name clashes" $ do
     res <- catchException (doLiftToTopLevel ["./test/testdata/MoveDef/Md1.hs","17","5"])
     (show res) `shouldBe` "Just \"The identifier(s):[ff] will cause name clash/capture or ambiguity occurrence problem after lifting, please do renaming first!\""

    {-
    it "checks for invalid new name" $ do
     res <- catchException (doDuplicateDef ["./test/testdata/DupDef/Dd1.hs","$c","5","1"])
     (show res) `shouldBe` "Just \"Invalid new function name:$c!\""

    it "notifies if no definition selected" $ do
     res <- catchException (doDuplicateDef ["./test/testdata/DupDef/Dd1.hs","ccc","14","13"])
     (show res) `shouldBe` "Just \"The selected identifier is not a function/simple pattern name, or is not defined in this module \""
    -}

    it "lifts a definition to the top level" $ do
     doLiftToTopLevel ["./test/testdata/MoveDef/Md1.hs","24","5"]
     diff <- compareFiles "./test/testdata/MoveDef/Md1.hs.expected"
                          "./test/testdata/MoveDef/Md1.hs.refactored"
     diff `shouldBe` []


  -- -------------------------------------------------------------------

  describe "doDemote" $ do

    it "notifies if no definition selected" $ do
     res <- catchException (doDemote ["./test/testdata/MoveDef/Md1.hs","14","13"])
     (show res) `shouldBe` "Just \"\\nInvalid cursor position!\""

    it "will not demote if nowhere to go" $ do
     res <- catchException (doDemote ["./test/testdata/MoveDef/Md1.hs","8","1"])
     (show res) `shouldBe` "Just \"\\n Nowhere to demote this function!\\n\""

    it "demotes a definition from the top level 1" $ do
     doDemote ["./test/testdata/MoveDef/Demote.hs","7","1"]
     diff <- compareFiles "./test/testdata/MoveDef/Demote.hs.refactored"
                          "./test/testdata/MoveDef/Demote.hs.expected"
     diff `shouldBe` []

    -- -----------------------------------------------------------------

    it "demotes a definition from the top level D1" $ do
     doDemote ["./test/testdata/Demote/D1.hs","9","1"]
     diff <- compareFiles "./test/testdata/Demote/D1.hs.refactored"
                          "./test/testdata/Demote/D1.hs.expected"
     diff `shouldBe` []

    -- -----------------------------------------------------------------

    it "demotes WhereIn1 12 1" $ do
     doDemote ["./test/testdata/Demote/WhereIn1.hs","12","1"]
     diff <- compareFiles "./test/testdata/Demote/WhereIn1.hs.refactored"
                          "./test/testdata/Demote/WhereIn1.hs.expected"
     diff `shouldBe` []

    -- -----------------------------------------------------------------

    it "demotes WhereIn3 14 1" $ do
     doDemote ["./test/testdata/Demote/WhereIn3.hs","14","1"]
     diff <- compareFiles "./test/testdata/Demote/WhereIn3.hs.refactored"
                          "./test/testdata/Demote/WhereIn3.hs.expected"
     diff `shouldBe` []

    -- -----------------------------------------------------------------

    it "demotes WhereIn4 14 1" $ do
     doDemote ["./test/testdata/Demote/WhereIn4.hs","14","1"]
     diff <- compareFiles "./test/testdata/Demote/WhereIn4.hs.refactored"
                          "./test/testdata/Demote/WhereIn4.hs.expected"
     diff `shouldBe` []

    -- -----------------------------------------------------------------

    it "demotes WhereIn5 14 1" $ do
     doDemote ["./test/testdata/Demote/WhereIn5.hs","14","1"]
     diff <- compareFiles "./test/testdata/Demote/WhereIn5.hs.refactored"
                          "./test/testdata/Demote/WhereIn5.hs.expected"
     diff `shouldBe` []

    -- -----------------------------------------------------------------

    it "demotes WhereIn6 13 1" $ do
     -- pending "todo"

     doDemote ["./test/testdata/Demote/WhereIn6.hs","13","1"]
     diff <- compareFiles "./test/testdata/Demote/WhereIn6.hs.refactored"
                          "./test/testdata/Demote/WhereIn6.hs.expected"
     diff `shouldBe` []

    -- -----------------------------------------------------------------

    it "demotes WhereIn7 13 1" $ do
     pending "todo"
{-
     doDemote ["./test/testdata/Demote/WhereIn7.hs","13","1"]
     diff <- compareFiles "./test/testdata/Demote/WhereIn7.hs.refactored"
                          "./test/testdata/Demote/WhereIn7.hs.expected"
     diff `shouldBe` []
-}
    -- -----------------------------------------------------------------

    it "demotes CaseIn1 16 1" $ do
     pending "todo"
{-
     doDemote ["./test/testdata/Demote/CaseIn1.hs","16","1"]
     diff <- compareFiles "./test/testdata/Demote/CaseIn1.hs.refactored"
                          "./test/testdata/Demote/CaseIn1.hs.expected"
     diff `shouldBe` []
-}
    -- -----------------------------------------------------------------

    it "demotes LetIn1 12 22" $ do
     pending "todo"
{-
     doDemote ["./test/testdata/Demote/LetIn1.hs","12","22"]
     diff <- compareFiles "./test/testdata/Demote/LetIn1.hs.refactored"
                          "./test/testdata/Demote/LetIn1.hs.expected"
     diff `shouldBe` []
-}
    -- -----------------------------------------------------------------

    it "demotes PatBindIn1 19 1" $ do
       pending "todo"
{-
   doDemote ["./test/testdata/Demote/PatBindIn1.hs","19","1"]
     diff <- compareFiles "./test/testdata/Demote/PatBindIn1.hs.refactored"
                          "./test/testdata/Demote/PatBindIn1.hs.expected"
     diff `shouldBe` []
-}
    -- -----------------------------------------------------------------

    it "fails WhereIn2 14 1" $ do
       pending "todo"
{-
   res <- catchException (doDemote ["./test/testdata/Demote/WhereIn2.hs","14","1"])
     (show res) `shouldBe` "Just \"\\n Nowhere to demote this function!\\n\""
-}
    -- -----------------------------------------------------------------

    it "fails LetIn2 11 22" $ do
     pending "todo"
{-
     res <- catchException (doDemote ["./test/testdata/Demote/LetIn2.hs","11","22"])
     (show res) `shouldBe` "Just \"This function can not be demoted as it is used in current level!\\n\""
-}
    -- -----------------------------------------------------------------

    it "fails PatBindIn4 18 1" $ do
     pending "todo"
{-
     res <- catchException (doDemote ["./test/testdata/Demote/PatBindIn4.hs","18","1"])
     (show res) `shouldBe` "Just \"\\n Nowhere to demote this function!\\n\""
-}
    -- -----------------------------------------------------------------

    it "fails WhereIn8 16 1" $ do
     pending "todo"
{-
     res <- catchException (doDemote ["./test/testdata/Demote/WhereIn8.hs","16","1"])
     (show res) `shouldBe` "Just \"\\n Nowhere to demote this function!\\n\""
-}
    -- -----------------------------------------------------------------

    it "fails D2 5 1" $ do
     pending "todo"
{-
     res <- catchException (doDemote ["./test/testdata/Demote/D2.hs","5","1"])
     (show res) `shouldBe` "Just \"\\n Nowhere to demote this function!\\n\""
-}
    -- -----------------------------------------------------------------

    it "fails D3 5 1" $ do
     pending "todo"
{-
     res <- catchException (doDemote ["./test/testdata/Demote/D3.hs","5","1"])
     (show res) `shouldBe` "Just \"This definition can not be demoted, as it is explicitly exported by the current module!\""
-}


{- Original test cases. These files are now in testdata/Demote

-- TODO: reinstate these tests

TestCases{refactorCmd="demote",
positive=[(["D1.hs","C1.hs","A1.hs"],["9","1"]),
          (["WhereIn1.hs"],["12","1"]),
          (["WhereIn3.hs"],["14","1"]),
          (["WhereIn4.hs"],["14","1"]),
          (["WhereIn5.hs"],["14","1"]),
          (["WhereIn6.hs"],["13","1"]),
          (["WhereIn7.hs"],["13","1"]),
          (["CaseIn1.hs"],["16","1"]),
          (["LetIn1.hs"],["12","22"]),
          (["PatBindIn1.hs"],["19","1"])],
negative=[(["WhereIn2.hs"],["14","1"]),
          (["LetIn2.hs"],["11","22"]),
          (["PatBindIn4.hs"],["18","1"]),
          (["WhereIn8.hs"],["16","1"]),
          (["D2.hs","C2.hs","A2.hs"],["5","1"]),
          (["D3.hs"],["5","1"])]
}
-}

-- ---------------------------------------------------------------------
-- Helper functions

