{ stdenv
, lib
, fetchFromGitHub
, cmake
, pkg-config
, python3
, python3Packages
, eigen
, llvmPackages
, ...
}:

# The himbaechel Xilinx uarch: the successor of nextpnr-xilinx, developed in
# openXC7's fork of upstream nextpnr under himbaechel/uarch/xilinx.
#
# The chipdbs are generated from an external prjxray-db checkout (not from a
# copy vendored in this repository) by the in-tree gen/xilinx_gen.py, and are
# installed under share/nextpnr/chipdb/.  Only a minimal device set is built
# here; nix/nextpnr-chipdb.nix generates the per-footprint chipdbs that the
# demos and the regression cases consume.
#
# The CLI differs from the legacy fork (-o xdc=/-o fasm= instead of
# --xdc/--fasm), so bin/nextpnr-xilinx is the shim from .github/scripts/:
# openXC7's demos, its regression harness and the xc7-bitstream-tools
# Makefile all invoke a binary of that name with the fork's flags.
stdenv.mkDerivation rec {
  pname = "nextpnr";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "openXC7";
    repo = "nextpnr";
    rev = "152860f87c46220decab2420a80c2d25e99a14f6";
    hash = "sha256-zt7iGjEPHl/Nvnm0af3YUEUpMcCJxo10xIcVGTvI1p8=";
    fetchSubmodules = true;
  };

  prjxray-db = fetchFromGitHub {
    owner = "openXC7";
    repo = "prjxray-db";
    rev = "ab1fc60c38a0dc1bc1d3d495f3189b25ae971e04";
    hash = "sha256-x8o8kMyu4PSTLosvwcS3OZGOu23Ti86mTEHtKM/A8rg=";
  };

  nativeBuildInputs = [ cmake pkg-config python3 ];

  buildInputs = [ python3Packages.boost python3 eigen ]
    ++ lib.optional stdenv.cc.isClang llvmPackages.openmp;

  cmakeFlags = [
    "-DCURRENT_GIT_VERSION=${version}"
    "-DARCH=himbaechel"
    "-DHIMBAECHEL_UARCH=xilinx"
    # A minimal set: the chipdb is loaded at runtime from the file named by
    # --chipdb, and the per-footprint chipdbs come from nix/nextpnr-chipdb.nix.
    "-DHIMBAECHEL_XILINX_DEVICES=xc7a50t"
    "-DHIMBAECHEL_PRJXRAY_DB=${prjxray-db}"
    "-DBUILD_GUI=OFF"
    # ddr3-test-arty-s7 drives --pre-place/--pre-route, which need the bindings
    "-DBUILD_PYTHON=ON"
    "-DUSE_OPENMP=ON"
  ];

  postInstall = ''
    mkdir -p $out/bin $out/share/nextpnr/chipdb
    cp nextpnr-himbaechel $out/bin/
    cp bba/bbasm $out/bin/
    cp ${src}/.github/scripts/nextpnr-xilinx-shim.sh $out/bin/nextpnr-xilinx
    chmod +x $out/bin/nextpnr-xilinx
    cp himbaechel/uarch/xilinx/chipdb-*.bin $out/share/nextpnr/chipdb/ || true
  '';

  # The chipdb derivation (nix/nextpnr-chipdb.nix) generates its per-footprint
  # chipdbs from this exact source tree (for gen/xilinx_gen.py) and prjxray-db
  # checkout, and the devShell repoints PRJXRAY_DB_DIR at the latter.  Expose
  # both so those consumers share one fetch instead of re-fetching (and risk
  # the two copies drifting apart).
  passthru = {
    inherit src prjxray-db;
  };

  meta = with lib; {
    description = "Place and route tool for Xilinx 7-series FPGAs (himbaechel uarch)";
    homepage = "https://github.com/openXC7/nextpnr";
    license = licenses.isc;
    mainProgram = "nextpnr-himbaechel";
    platforms = platforms.unix;
  };
}
