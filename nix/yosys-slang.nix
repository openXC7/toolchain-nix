{ stdenv
, lib
, fetchFromGitHub
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "yosys-slang";
  plugin = "slang";
  version = "08bb13bd128c73b79455f4ea344a1785e0a342e9"

  src = fetchFromGitHub {
    owner = "povik";
    repo  = "yosys-slang";
    rev   = "${finalAttrs.version}";
    hash  = "sha256-PODeQL8n34Ekq4NQJ5/w9pTkfkBc77osZc7JzEOUk6I=";
    fetchSubmodules = false;
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
  ];

  buildPhase = ''
    runHook preBuild

    make -j $NIX_BUILD_CORES

    runHook postBuild
  '';

  # Check that the plugin can be loaded successfully and parse simple file.
  doCheck = true;
  checkPhase = ''
     runHook preCheck
     # echo "module tester(); endmodule;" > tester.sv
     # yosys -p "plugin -i build/release/systemverilog-plugin/systemverilog.so;\
     #          read_systemverilog tester.sv"
     runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    #mkdir -p $out/share/yosys/plugins
    #cp ./build/release/systemverilog-plugin/systemverilog.so \
    #       $out/share/yosys/plugins/systemverilog.so
    runHook postInstall
  '';

  meta = with lib; {
    description = "SystemVerilog frontend for Yosys";
    homepage    = "https://github.com/povik/yosys-slang";
    license     = licenses.isc;
    maintainers = with maintainers; [ gitRaiku ];
    platforms   = platforms.all;
  };
})

