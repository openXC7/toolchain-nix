{ lib
, stdenv
, fetchzip
, substituteAll
, cmake
, python3
, gtest
}:

stdenv.mkDerivation rec {
  pname = "libantlr4cpp";
  version = "4.13.1";
  src = fetchzip {
    url = "https://www.antlr.org/download/antlr4-cpp-runtime-${version}-source.zip";
    sha256 ="sha256-w95wxbC2X4zDewt/HqRaEXsADUhwQepi8S2MwVa9m0k=";
    stripRoot = false;
  };

  patches = [
    (substituteAll {
      src = ./dont_fetch_dependencies.patch;
      gtest_src = gtest.src;
    })
  ];

  nativeBuildInputs = [
    cmake
    python3
  ];

  # FIXME(jleightcap): validate cross-compilation to i686
  /*
  configureFlags = lib.optional stdenv.is64bit "--enable-64bit"
    # libantlr3c wrongly emits the abi flags -m64 and -m32 which imply x86 archs
    # https://github.com/antlr/antlr3/issues/205
    ++ lib.optional (!stdenv.hostPlatform.isx86) "--disable-abiflags";
  */

  meta = with lib; {
    description = "C++ runtime libraries of ANTLR v4";
    homepage = "https://www.antlr.org/";
    license = licenses.bsd3;
    platforms = platforms.unix;
    # FIXME(jleightcap): add https://github.com/antlr/antlr4/releases/tag/4.13.1 changelog
    maintainers = with maintainers; [ jleightcap ];
  };
}
