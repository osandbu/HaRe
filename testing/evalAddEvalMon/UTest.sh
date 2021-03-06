#!/bin/sh
#BASH="d:\\cygwin\\bin\\bash.exe"
BASH="bash"
HARE="../../refactorer/pfe"
#HARE="..\\..\\refactorer\\pfe"
#cd ..
ghc --make -i../../../../HUnit-1.0 -o UTest ./UTestCache.hs
rm *.o *.hi
# avoid spurious error reports due to line-ending conventions..
case `uname` in
  CYGWIN*) 
    unix2dos *.hs 
    ;;
esac
# cd ./evalAddMonad
echo "-- testing add to eval Monad"
./UTest $BASH $HARE 2>&1 | tee log.txt
