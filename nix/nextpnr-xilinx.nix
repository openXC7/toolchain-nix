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

stdenv.mkDerivation {
  pname = "nextpnr-xilinx";
  version = "0.9.8";

  src = fetchFromGitHub {
    owner = "openXC7";
    repo = "nextpnr-xilinx";
    rev = "cbabb65139c3d82f0a05b670b5869e1b512b69e8";
    hash = "sha256-HvfMNYKOB77FeH6J4aZq0Mp0y3S4IrCPY9zdgxhtr3Y=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake pkg-config python3 ];

  buildInputs = [ python3Packages.boost python3 eigen ]
    ++ lib.optional stdenv.cc.isClang llvmPackages.openmp;

  cmakeFlags = [
    "-DCURRENT_GIT_VERSION=0.9.8"
    "-DARCH=xilinx"
    "-DBUILD_GUI=OFF"
    "-DBUILD_TESTS=OFF"
    "-DUSE_OPENMP=ON"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp nextpnr-xilinx bbasm $out/bin/

    mkdir -p $out/share/nextpnr/external
    cp -r ../xilinx/external/prjxray-db $out/share/nextpnr/external/
    cp -r ../xilinx/external/nextpnr-xilinx-meta $out/share/nextpnr/external/
    cp -r ../xilinx/python $out/share/nextpnr/
    cp ../xilinx/constids.inc $out/share/nextpnr/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Place and route tool for Xilinx 7-series FPGAs";
    homepage = "https://github.com/openXC7/nextpnr-xilinx";
    changelog = "https://github.com/openXC7/nextpnr-xilinx/releases/tag/0.9.8";
    license = licenses.isc;
    mainProgram = "nextpnr-xilinx";
    platforms = platforms.unix;
  };
}
