module LiftToToplevel.CaseIn1 where

--A definition can be lifted from a where or let to the top level binding group.
--Lifting a definition widens the scope of the definition.

--In this example, lift 'addthree' defined in main

main x y z = case x of
                0 -> addthree x y z
                     where addthree a b c=a+b+c
                1 -> inc y
                     where inc a =a+1
  
