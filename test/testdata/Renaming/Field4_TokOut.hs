module Field4 where

--Rename field name 'value1' to 'value2' should success.

data Vtree a = Vleaf {value2::a} | 
               Vnode {value2::a, left,right ::Vtree a}

fringe :: Vtree a -> [a]
fringe t@(Vleaf _ ) = [value2 t]
fringe t@(Vnode _  _ _) =fringe (left t) ++ fringe (right t)

