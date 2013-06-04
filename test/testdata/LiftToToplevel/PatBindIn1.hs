module LiftToToplevel.PatBindIn1 where

--A definition can be lifted from a where or let into the surrounding binding group.
--Lifting a definition widens the scope of the definition.

--In this example, lift 'tup' defined in 'foo'
--This example aims to test renaming and the lifting of type signatures.

main :: Int
main = foo 3

foo :: Int -> Int
foo x = h + t + (snd tup)
      where
      h :: Int
      t :: Int
      tup :: (Int,Int)
      tup@(h,t) = head $ zip [1..10] [3..15]
