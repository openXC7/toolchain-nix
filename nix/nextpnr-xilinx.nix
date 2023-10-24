{ stdenv, cmake, git, lib, fetchFromGitHub, python310Packages, python310, eigen
, llvmPackages, ... }:
stdenv.mkDerivation rec {
  pname = "nextpnr-xilinx";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "openXC7";
    repo = "nextpnr-xilinx";
    rev = "df364a2ce85e5aa77925ff8e1636c68333ae47bf";
    hash = "sha256-TAlCrOwDX8/1P+yxZs9AiZtVhMkfO7D8I8Ek0i8NG34=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake git ];
  buildInputs = [ python310Packages.boost python310 eigen ]
    ++ (lib.optional stdenv.cc.isClang [ llvmPackages.openmp ]);

  cmakeFlags = [
    "-DCURRENT_GIT_VERSION=${lib.substring 0 7 src.rev}"
    "-DARCH=xilinx"
    "-DBUILD_GUI=OFF"
    "-DBUILD_TESTS=OFF"
    "-DUSE_OPENMP=ON"
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp nextpnr-xilinx bbasm $out/bin/
    mkdir -p $out/share/nextpnr/external
    cp -rv ../xilinx/external/prjxray-db $out/share/nextpnr/external/
    cp -rv ../xilinx/external/nextpnr-xilinx-meta $out/share/nextpnr/external/
    cp -rv ../xilinx/python/ $out/share/nextpnr/python/
    cp ../xilinx/constids.inc $out/share/nextpnr
  '';

  meta = with lib; {
    description = "Place and route tool for FPGAs";
    homepage = "https://github.com/openXC7/nextpnr-xilinx";
    license = licenses.isc;
    platforms = platforms.all;
  };
}
