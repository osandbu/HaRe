module D2 where

{-Rename type constructor `Branch` to `SubTree`.
  This refactoring affects module `D2', 'B2' and 'C2' -}
   
data Tree a = Leaf a | SubTree (Tree a) (Tree a) 

fringe :: Tree a -> [a]
fringe (Leaf x ) = [x]
fringe (SubTree left right) = fringe left ++ fringe right

class SameOrNot a where
   isSame  :: a -> a -> Bool
   isNotSame :: a -> a -> Bool

instance SameOrNot Int where
   isSame a  b = a == b
   isNotSame a b = a /= b

sumSquares (x:xs) = sq x + sumSquares xs
    where sq x = x ^pow 
          pow = 2

sumSquares [] = 0
