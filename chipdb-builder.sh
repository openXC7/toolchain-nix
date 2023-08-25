#!/bin/bash

set -e
unset PATH
for p in $buildInputs; do
  export PATH=$p/bin${PATH:+:}$PATH
done

buildInputsArray=($buildInputs)
NEXTPNR_DIR=${buildInputsArray[1]}
mkdir $out

find $srcs/ -type d -name "*-*" -mindepth 1 -maxdepth 2 | tee $out/footprints
sed -i -e 's,.*/\(.*\)-.*$,\1,g' -e 's,\./,,g' $out/footprints
sort $out/footprints -o $out/footprints
uniq $out/footprints > $out/footprints.txt
rm $out/footprints

for i in `cat $out/footprints.txt`
do
    if   [[ $i = xc7a* ]]; then ARCH=artix7 
    elif [[ $i = xc7k* ]]; then ARCH=kintex7
    elif [[ $i = xc7s* ]]; then ARCH=spartan7
    elif [[ $i = xc7z* ]]; then ARCH=zynq7
    else 
      echo "unsupported architecture for footprint $i"
      exit 1
    fi
    FOOTPRINT_DIR=`ls -d $srcs/$ARCH/$i-* | sort -n | head -1`
    pypy3.9 $NEXTPNR_DIR/usr/share/nextpnr/python/bbaexport.py --device `echo $FOOTPRINT_DIR | tr '/' '\n' | tail -1` --bba $i.bba 2>&1
    bbasm -l $i.bba $out/$i.bin
done