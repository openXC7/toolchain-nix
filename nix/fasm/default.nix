# https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/python.section.md

{ lib
, buildPythonPackage
, fetchFromGitHub
, pythonOlder
, cmake
, jre_headless
, antlr4_9
, textx
, cython
, fetchpatch
, python312Packages
}:

buildPythonPackage rec {
  name = "fasm";
  version = "0.0.2.r98.g9a73d70";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    inherit name;
    owner = "openxc7";
    repo = "fasm";
    rev = "2f57ccb1727a120e8cacbb95c578f3c71bdcc95a";
    hash = "sha256-zpH7SnS4nkVfTiIngjJINfKtSIl7ee1YQLkRCucTBwY=";
    fetchSubmodules = true;
    leaveDotGit = true;
    postFetch = ''rm -rf $out/.git'';
  };

  nativeBuildInputs = [
    cmake
    jre_headless
    cython
  ];

  buildInputs = [
    antlr4_9.runtime.cpp
    antlr4_9.runtime.cpp.dev
  ];

  propagatedBuildInputs = [
    textx
  ];

  env.ANTLR4_RUNTIME_INCLUDE = "${antlr4_9.runtime.cpp.dev}/include/antlr4-runtime";

  postPatch = ''
    substituteInPlace setup.py \
      --replace-fail "self.antlr_runtime = 'static'" "self.antlr_runtime = 'shared'"
    substituteInPlace third_party/googletest/CMakeLists.txt \
      --replace-fail "VERSION 2.8.8" "VERSION 4.1.0"
    substituteInPlace third_party/googletest/googletest/CMakeLists.txt \
      --replace-fail "VERSION 2.6.4" "VERSION 4.1.0"
    substituteInPlace third_party/googletest/googlemock/CMakeLists.txt \
      --replace-fail "VERSION 2.6.4" "VERSION 4.1.0"
    substituteInPlace third_party/googletest/googletest/cmake/internal_utils.cmake \
      --replace-fail "find_package(PythonInterp)" "find_package(Python3 COMPONENTS Interpreter)"
    substituteInPlace third_party/googletest/googletest/src/gtest-death-test.cc \
      --replace-fail "#include <utility>" $'#include <utility>\n#include <cstdint>'
    substituteInPlace fasm/parser/__init__.py \
      --replace-fail "from warnings import warn" $'from warnings import warn\nimport pyximport\npyximport.install()'
  '';

  dontUseCmakeConfigure = true;

  # Broken upstream.
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=python-fasm-git#n76
  doCheck = false;

  meta = with lib; {
    changelog = "https://github.com/chipsalliance/fasm/releases/tag/${version}";
    homepage = "https://github.com/chipsalliance/fasm/";
    description = "FPGA Assembly (FASM) Parser and Generator";
    license = licenses.asl20;
    maintainers = with maintainers; [ jleightcap hansfbaier ];
  };
}
