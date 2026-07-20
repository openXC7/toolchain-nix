{ stdenv, lib, fetchFromGitHub, cmake, git, python312Packages, eigen, python312
, ... }:
stdenv.mkDerivation rec {
  pname = "prjxray";
  version = "c9f02d8576042325425824647ab5555b1bc77833";

  src = fetchFromGitHub {
    owner = "f4pga";
    repo = "prjxray";
    rev = "c9f02d8576042325425824647ab5555b1bc77833";
    hash = "sha256-QuYgd1HTOPTr+0YhTCfDd6+o1p9H56nnF77CIM6svok=";
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
    sed -i 's/VERSION 3.0.2/VERSION 3.14.0/g' third_party/gflags/CMakeLists.txt
    sed -i 's/VERSION 2.8.12/VERSION 3.14.0/g' third_party/cctz/CMakeLists.txt
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
