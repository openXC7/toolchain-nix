{ stdenv, lib, fetchFromGitHub, cmake, git, python310Packages, eigen, python310
, ... }:
stdenv.mkDerivation rec {
  pname = "prjxray";
  version = "76401bd93e493fd5ff4c2af4751d12105b0f4f6d";

  src = fetchFromGitHub {
    owner = "f4pga";
    repo = "prjxray";
    rev = "76401bd93e493fd5ff4c2af4751d12105b0f4f6d";
    fetchSubmodules = true;
    hash = "sha256-+k9Em+xX1rWPs3oATy3g1U0O6y3CATT9P42p0YCafxM=";
  };

  nativeBuildInputs = [ cmake git ];
  buildInputs = [ python310Packages.boost python310 eigen ];

  installPhase = ''
    mkdir -p $out/bin
    cp -v tools/xc7frames2bit tools/xc7patch $out/bin
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
