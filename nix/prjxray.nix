# The frame tools (fasm2frames, xc7frames2bit) the chipdb generator's FASM is
# assembled with, and the `prjxray` Python package fasm2frames imports.
#
# Pinned to the openXC7/prjxray tip.  Since the revision the engine's CI still
# names (54fea88c, PRJXRAY_REV), #34-#56 add fasm2frames and bit2fasm console
# scripts backed by prjxray.fasm2frames/prjxray.bit2fasm, optional pyjson5,
# input validation in bitread/segmatch/frames, sanitizer and CI coverage, and
# the CMake/YAML dependency fixes.  The database format these tools read is
# unchanged.
{ stdenv, lib, fetchFromGitHub, cmake, git, python312Packages, eigen, python312
, ... }:
stdenv.mkDerivation rec {
  pname = "prjxray";
  version = "0.9.2";

  src = fetchFromGitHub {
    owner = "openXC7";
    repo = "prjxray";
    rev = "1cd6ae3e6afff798201259e17aa605afe97b86d6";
    hash = "sha256-H8Nly7A9dd5TsoB6TdZ3EmXxFyxJlAI6qRdSzhS7GIw=";
    fetchSubmodules = true;
    leaveDotGit = true;
    postFetch = ''rm -rf $out/.git'';
  };

  nativeBuildInputs = [ cmake git ];
  buildInputs = [ python312Packages.boost python312 eigen ];

  # Add flags to fix compiling errors from the project being umaintained
  NIX_CFLAGS_COMPILE = "-include stdint.h -Wno-free-nonheap-object";

  patchPhase = ''
    sed -i 's/cmake /cmake -Wno-deprecated /g' Makefile
    sed -i 's/cmake /cmake -Wno-deprecated /g' Makefile
    sed -i 's/VERSION 3.5.0/VERSION 3.14.0/g' CMakeLists.txt
    sed -i '29 itarget_compile_options(libprjxray PUBLIC "-Wno-deprecated")' lib/CMakeLists.txt
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -v tools/xc7frames2bit tools/bitread tools/xc7patch $out/bin
    cp -v $srcs/utils/fasm2frames.py $out/bin/fasm2frames
    chmod 755 $out/bin/fasm2frames
    cp -v $srcs/utils/bit2fasm.py $out/bin/bit2fasm
    chmod 755 $out/bin/bit2fasm
    mkdir -p $out/usr/share/python3/
    cp -rv $srcs/prjxray $out/usr/share/python3/
  '';

  doCheck = false;

  meta = with lib; {
    description = "Xilinx series 7 FPGA bitstream documentation";
    homepage = "https://github.com/f4pga/prjxray";
    license = licenses.isc;
    platforms = platforms.all;
  };
}
