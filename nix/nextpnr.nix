# openXC7/nextpnr — the engine the nextpnr-xilinx line continues into.
#
# Only the binary and the tools are built here; the chip databases are their
# own derivations (nix/nextpnr-chipdb.nix) because a family's database is
# minutes of generator time and the devshell needs several families.
#
# The executable the openXC7 makefiles call is `nextpnr-xilinx`: this package
# installs it as the flag-translating shim the repo itself ships in
# .github/scripts/nextpnr-xilinx-shim.sh, next to the real nextpnr-himbaechel.
# Renaming the binary would not work — the makefiles pass --xdc/--fasm, which
# nextpnr-himbaechel does not take — and teaching it the fork's CLI is an
# upstream change to a binary that serves every himbaechel uarch.
{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, python3
, boost
, eigen
, prjxray-db
}:

let
  src = fetchFromGitHub {
    owner = "openXC7";
    repo = "nextpnr";
    rev = "e860c9c8360d8501a1b55df94e58f3dfe7bde958";
    hash = "sha256-1Xo2T7w8FF2NacKLfDDDOxcw2K2tmLAh30hnySOrOz8=";
    fetchSubmodules = true;
  };
in
stdenv.mkDerivation {
  pname = "nextpnr";
  version = "0.11.1-e860c9c8";
  inherit src;

  nativeBuildInputs = [ cmake pkg-config python3 ];

  buildInputs = [ boost eigen ];

  cmakeFlags = [
    "-DARCH=himbaechel"
    "-DHIMBAECHEL_UARCH=xilinx"
    "-DBUILD_GUI=OFF"
    "-DBUILD_PYTHON=OFF"
    "-DBUILD_TESTS=OFF"
    "-DUSE_OPENMP=ON"
    "-DCMAKE_BUILD_TYPE=Release"
    # Configure needs the database even when no chipdb target is built.
    "-DHIMBAECHEL_PRJXRAY_DB=${prjxray-db}"
    # Empty on purpose.  Every device in this list gets a chipdb target, and
    # the `nextpnr-himbaechel` target DEPENDS on it (see the make rules for
    # nextpnr-himbaechel-xilinx-chipdb), so leaving the list at its default --
    # all fifteen dies -- turns what looks like a binary build into fifteen
    # xilinx_gen.py runs under one make -j: 1-2 GB of Python each, which
    # OOMed a 62 GB box.  The databases are their own derivations
    # (nix/nextpnr-chipdb.nix) and reach the binary through --chipdb.
    "-DHIMBAECHEL_XILINX_DEVICES="
  ];

  # Build the two targets the devshell needs, not `all`.
  buildPhase = ''
    runHook preBuild
    cmake --build . --target nextpnr-himbaechel bbasm --parallel $NIX_BUILD_CORES
    runHook postBuild
  '';

  # The cmake hook builds outside the unpacked tree, so every source path here
  # is ${src}-qualified; only the built artefacts are relative to $PWD.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp nextpnr-himbaechel bba/bbasm $out/bin/

    # The compatibility name.  Point BIN at our own binary so the shim works
    # when invoked by absolute path, not only via $out/bin on PATH.
    install -m755 ${src}/.github/scripts/nextpnr-xilinx-shim.sh $out/bin/nextpnr-xilinx
    substituteInPlace $out/bin/nextpnr-xilinx \
      --replace-fail 'BIN="nextpnr-himbaechel"' "BIN=\"$out/bin/nextpnr-himbaechel\""

    # The chipdb generator and everything its imports reach: xilinx_gen.py
    # appends gen/../../.. to sys.path and imports himbaechel_dbgen, computes
    # its default --metadata/--constids paths from its own location, and the
    # site metadata is the openXC7/nextpnr-xilinx-meta submodule.
    mkdir -p $out/share/nextpnr/himbaechel/uarch/xilinx
    cp -r ${src}/himbaechel/uarch/xilinx/gen $out/share/nextpnr/himbaechel/uarch/xilinx/
    cp -r ${src}/himbaechel/uarch/xilinx/meta $out/share/nextpnr/himbaechel/uarch/xilinx/
    cp ${src}/himbaechel/uarch/xilinx/constids.inc $out/share/nextpnr/himbaechel/uarch/xilinx/
    cp -r ${src}/himbaechel/himbaechel_dbgen $out/share/nextpnr/himbaechel/

    # fasm2frames and xc7frames2bit read the database too; keep the devshell's
    # PRJXRAY_DB_DIR pointing at one copy rather than a second fetch.
    mkdir -p $out/share/nextpnr/external
    cp -r ${prjxray-db} $out/share/nextpnr/external/prjxray-db

    runHook postInstall
  '';

  meta = with lib; {
    description = "Portable FPGA place and route tool (himbaechel xilinx uarch)";
    homepage = "https://github.com/openXC7/nextpnr";
    license = licenses.isc;
    mainProgram = "nextpnr-xilinx";
    platforms = platforms.unix;
  };
}
