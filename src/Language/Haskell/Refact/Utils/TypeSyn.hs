{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
module Language.Haskell.Refact.Utils.TypeSyn where


-- Modules from GHC
import qualified FastString as GHC
import qualified GHC        as GHC
import qualified GhcMonad   as GHC
import qualified HsExpr     as GHC
import qualified Name       as GHC
import qualified Outputable as GHC
import qualified RdrName    as GHC
import qualified SrcLoc     as GHC



import Data.Generics

{-

data NameSpace = ValueName | ClassName | TypeCon | DataCon | Other  deriving (Eq, Show)

type HsDeclP   =HsDeclI PNT
type HsPatP    =HsPatI PNT
type HsExpP    =HsExpI PNT
-}
type HsExpP    = GHC.HsExpr GHC.RdrName
type HsPatP    = GHC.Pat GHC.RdrName
-- type HsDeclP   = GHC.HsDecl GHC.RdrName
type HsDeclP   = GHC.LHsDecl GHC.RdrName
-- type HsDeclP   = GHC.LHsBind GHC.Name

type HsDeclsP = GHC.HsGroup GHC.Name

{-
type HsMatchP  =HsMatchI PNT (HsExpP) (HsPatP) [HsDeclP]
-- type HsModuleP =HsModuleI (SN HsName.HsName) [HsDeclI PNT]
type HsImportDeclP=HsImportDeclI ModuleName PNT -- (SN HsName.HsName)
type HsExportEntP = HsExportSpecI ModuleName PNT
type RhsP      =HsRhs HsExpP
type GuardP    =(SrcLoc, HsExpP, HsExpP)
type HsAltP    =HsAlt HsExpP HsPatP [HsDeclP]
--type HsConDeclP=HsConDeclI PNT (HsTypeI PNT)
type HsStmtP   =HsStmt HsExpP HsPatP [HsDeclP]
type HsStmtAtomP = HsStmtAtom HsExpP HsPatP [HsDeclP]
type HsFieldP  =HsFieldI PNT HsExpP
type HsTypeP   = HsTypeI PNT
type EntSpecP  = EntSpec PNT
type HsConDeclP = HsConDeclI PNT HsTypeP [HsTypeP]
type HsConDeclP' = HsConDeclI PNT (TI PNT HsTypeP) [TI PNT HsTypeP]
type ENT =Ents.Ent PosName.Id
-}
-- type InScopes=((Relations.Rel Names.QName (Ents.Ent PosName.Id)))
type InScopes = [GHC.Name]

--type Exports =[(PosName.Id, Ent PosName.Id)]

type SimpPos = (Int,Int) -- Line, column

-- Additions for GHC
type PosToken = (GHC.Located GHC.Token, String)
-- type PosToken = (GHC.GenLocated GHC.SrcSpan GHC.Token, String)

data Pos = Pos { char, line, column :: !Int } deriving (Show)
-- it seems that the field char is used to handle special characters including the '\t'


type Export = GHC.LIE GHC.RdrName

-- ---------------------------------------------------------------------
-- From old/tools/base/defs/PNT.hs

-- | HsName is a name as it is found in the source
-- This seems to be quite a close correlation
type HsName = GHC.RdrName

-- |The PN is the name as it occurs to the parser, and
-- corresponds with the GHC.RdrName
-- type PN     = GHC.RdrName
newtype PName = PN HsName deriving (Eq)

instance Show PName where
  show (PN n) = "(PN " ++ (GHC.showRdrName n) ++ ")"

-- | The PNT is the unique name, after GHC renaming. It corresponds to
-- GHC.Name data PNT = PNT GHC.Name deriving (Data,Typeable) -- Note:
-- GHC.Name has SrcLoc in it already
-- ++AZ++ : will run with Located RdrName for now, will see when we need the Unique name
data PNT = PNT (GHC.Located (GHC.RdrName)) deriving (Data,Typeable,Eq)

instance Show PNT where
  show (PNT (GHC.L l name)) = "(PNT " ++ (GHC.showPpr l) ++ " " ++ (GHC.showRdrName name) ++ ")"

instance Show (GHC.GenLocated GHC.SrcSpan GHC.Name) where
  show (GHC.L l name) = "(" ++ (GHC.showPpr l) ++ " " ++ (GHC.showPpr $ GHC.nameUnique name) ++ " " ++ (GHC.showPpr name) ++ ")"

instance Show GHC.NameSpace where
  show ns
    | ns == GHC.tcName = "TcClsName"
    | ns == GHC.dataName = "DataName"
    | ns == GHC.varName = "VarName"
    | ns == GHC.tvName = "TvName"
    | otherwise = "UnknownNamespace"

instance GHC.Outputable GHC.NameSpace where
  ppr x = GHC.text $ show x

-- ---------------------------------------------------------------------

-- type HsModuleP =HsModuleI ModuleName PNT [HsDeclI PNT]
type HsModuleP = GHC.Located (GHC.HsModule GHC.RdrName)



-- ----------------------------------------------------
-- From PNT

-- CMB
-- type PName  = HsName


{-
type PIdent = HsIdentI PName
type PId    = PN Id
-}
--data PNT = PNT PName (IdTy PId) OptSrcLoc deriving (Show,Read, Data, Typeable)

-- CMB
-- data PNT = PNT PName OptSrcLoc deriving (Data, Typeable)

-- CMB
--instance Eq  PNT where PNT i1 _  == PNT i2 _  = i1==i2
--instance Ord PNT where compare (PNT i1 _) (PNT i2 _) = compare i1 i2




-- instance HasOrig PNT where orig (PNT pn _ _)  = orig pn
-- instance HasOrig i => HasOrig (HsIdentI i) where orig = orig . getHSName

-- instance HasIdTy PId PNT where idTy (PNT _ ty _) = ty


--instance HasNameSpace PNT where namespace (PNT _ idty _) = namespace idty
--instance HasNameSpace i => HasNameSpace (HsIdentI i) where
--   namespace = namespace . getHSName

{-
instance QualNames qn m n => QualNames (PN qn) m (PN n) where
    getQualifier                = getQualifier . getBaseName
    getQualified                = fmap getQualified

    mkUnqual                    = fmap mkUnqual
    mkQual m                    = fmap (mkQual m)

instance Printable PNT where
  ppi (PNT i _ _) = ppi i
  wrap  (PNT i _ _) = wrap i

instance PrintableOp PNT where
  isOp (PNT i _ _) = isOp i
  ppiOp (PNT i _ _) = ppiOp i

--instance Unique (PN i) where unique m (PN _ o) = o

instance HasBaseName PNT HsName where
  getBaseName (PNT i _ _) = getBaseName i

instance QualNames PNT ModuleName PNT where
    getQualifier                = getQualifier . getBaseName
    getQualified (PNT i t p)    = PNT (unqual i) t p -- hmm

    mkUnqual                    = id -- hmm
    mkQual m (PNT i t p)        = PNT (mkQual m (getQualified i)) t p

instance HasSrcLoc PNT where
  srcLoc (PNT i _ (N (Just s))) = s
  srcLoc (PNT i _ _) = srcLoc i -- hmm

-}

------------------------------------------------------------------------
-- From UniqueNames

-- type SrcLoc = GHC.SrcSpan

{- newtype OptSrcLoc = N (Maybe GHC.SrcLoc) deriving (Data, Typeable)
noSrcLoc = GHC.noSrcSpan
srcLoc = N . Just
optSrcLoc = N
instance Eq  OptSrcLoc where _ == _ = True
instance Ord OptSrcLoc where compare _ _ = EQ
-}


-- ---------------------------------------------------------------------
-- Putting these here for the time being, to avoid import loops


ghead info []    = error $ "ghead "++info++" []"
ghead info (h:_) = h

glast info []    = error $ "glast " ++ info ++ " []"
glast info h     = last h

gtail info []   = error $ "gtail " ++ info ++ " []"
gtail info h    = tail h

gfromJust info (Just h) = h
gfromJust info Nothing = error $ "gfromJust " ++ info ++ " Nothing"


-- ---------------------------------------------------------------------
