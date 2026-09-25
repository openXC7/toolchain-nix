# Chip databases for openXC7/nextpnr's himbaechel xilinx uarch.
#
# The generator takes a *die* (himbaechel/uarch/xilinx/gen/xilinx_gen.py
# --device xc7a50t) and one database serves every package of that die, so the
# work is per-die.  demo-projects' openXC7.mk asks for
# ${CHIPDB}/${DBPART}.bin with the speedgrade stripped, and nextpnr's device
# parser resolves the part-form name itself, so each package also gets a
# relative symlink to its die's database under its own name -- the die
# databases themselves are the only files the derivation stores.
#
# The die list is ALL_HIMBAECHEL_XILINX_DEVICES from the uarch's CMakeLists,
# grouped by family.
{ lib
, stdenv
, nixpkgs
, backend
, nextpnr
, prjxray-db
, python3
, coreutils
, findutils
, gnused
, gnugrep
}:

let
  dies = {
    artix7 = [ "xc7a100t" "xc7a200t" "xc7a50t" ];
    kintex7 = [ "xc7k70t" "xc7k160t" "xc7k325t" "xc7k420t" "xc7k480t" ];
    spartan7 = [ "xc7s50" ];
    virtex7 = [ "xc7vx485t" ];
    zynq7 = [ "xc7z010" "xc7z020" "xc7z030" "xc7z045" "xc7z100" ];
  }.${backend};
in
stdenv.mkDerivation {
  pname = "nextpnr-xilinx-chipdb";
  version = nextpnr.version;
  inherit backend;

  dontUnpack = true;
  dontInstall = true;

  nativeBuildInputs = [ python3 coreutils findutils gnused gnugrep ];
  buildInputs = [ nextpnr ];

  buildPhase = ''
    runHook preBuild
    mkdir -p $out
    db=${prjxray-db}/${backend}

    for die in ${lib.concatStringsSep " " dies}; do
      echo "building chipdb-$die"
      ${python3}/bin/python3 \
        ${nextpnr}/share/nextpnr/himbaechel/uarch/xilinx/gen/xilinx_gen.py \
        --xray "$db" --device "$die" --bba "$die.bba"
      ${nextpnr}/bin/bbasm -l "$die.bba" "$out/chipdb-$die.bin"
      # The .bba is 100+ MB per die; keep peak disk at one die.
      rm -f "$die.bba"
    done

    # Part names for openXC7.mk.  The fabric prefix is nextpnr's own device
    # class, with its one alias (himbaechel/uarch/xilinx/xilinx.cc maps
    # xc7a35t onto the xc7a50t database).
    for d in "$db"/*-*; do
      fp=$(basename "$d")
      part=$(echo "$fp" | sed -E 's/-[0-9]L?$//')
      fabric=$(echo "$part" | sed -E 's/^(xc7(s[0-9]+t?|a[0-9]+t|k[0-9]+t|z[0-9]+t?|v[xh]?[0-9]+t)).*/\1/')
      if [ "$fabric" = xc7a35t ]; then
        fabric=xc7a50t
      fi
      if [ -f "$out/chipdb-$fabric.bin" ]; then
        # Symlink, not copy: one die's database is 20-75 MB and serves every
        # package of that die, so a copy under each part name inflated a
        # family's artefact severalfold (kintex7: 1.2 GB for 252 MB of data)
        # and made CI pull the copies with it.  Relative, so the store path
        # stays self-contained and relocatable.
        #
        # -f because the speed grades of one footprint collapse onto the same
        # part name (xc7a100tcsg324-1, -2, -2L and -3 all strip to
        # xc7a100tcsg324): every one of them links the same die's database, so
        # the last writer is the right one.  A plain ln -s aborts the build on
        # the second one; the copy this replaced overwrote silently.
        ln -sf "chipdb-$fabric.bin" "$out/$part.bin"
      else
        echo "no chipdb for $part (fabric $fabric) -- skipped"
      fi
    done

    mkdir -p $out/bin
    cat > $out/bin/get_chipdb_${backend}.sh <<EOF
    #!${nixpkgs.runtimeShell}
    echo -n $out
    EOF
    chmod 755 $out/bin/get_chipdb_${backend}.sh

    runHook postBuild
  '';
}
