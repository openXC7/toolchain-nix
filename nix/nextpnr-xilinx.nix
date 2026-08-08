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
  version = "0.9.2";

  src = fetchFromGitHub {
    owner = "openXC7";
    repo = "nextpnr-xilinx";
    rev = "7094958155bd9f7d7c0f123fd636e4d78a823aae";
    hash = "sha256-JMQe2gsG1IYkY4aCVdaO2rDjGAL2h5gRjjaa6i8x4Oc=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake pkg-config python3 ];

  buildInputs = [ python3Packages.boost python3 eigen ]
    ++ lib.optional stdenv.cc.isClang llvmPackages.openmp;

  cmakeFlags = [
    "-DCURRENT_GIT_VERSION=0.9.2"
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
    changelog = "https://github.com/openXC7/nextpnr-xilinx/releases/tag/0.9.2";
    license = licenses.isc;
    mainProgram = "nextpnr-xilinx";
    platforms = platforms.unix;
  };
}
