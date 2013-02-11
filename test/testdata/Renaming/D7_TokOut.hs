module D7 where

{- Rename 'fringe' to 'myFringe'. 
   This affects module 'D7' and 'C7'
-}
data Tree a = Leaf a | Branch (Tree a) (Tree a) 

myFringe  :: Tree a -> [a]
myFringe (Leaf x ) = [x]
myFringe (Branch left right) = myFringe left ++ myFringe right
