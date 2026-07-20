{ stdenv
, lib
, fetchFromGitHub
, cmake
, yosys
, python3
, boost
, fmt
, tomlplusplus
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sv-elab";
  version = "3dddccd478618d68f8a5e160fb4b5783c4da35d4";

  src = fetchFromGitHub {
    owner = "povik";
    repo  = "sv-elab";
    rev   = "${finalAttrs.version}";
    hash  = "sha256-9e0FuIAQtexs0nW04aonYh55P8v0/v8LBG2ON7JG9x4=";
    fetchSubmodules = true;
    leaveDotGit = true;
    postFetch = ''rm -rf $out/.git'';
  };

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    yosys
    python3
    boost
    fmt
    tomlplusplus
  ];

  cmakeFlags = [
    (lib.cmakeBool "SLANG_USE_SYSTEM_BOOST" true)
    (lib.cmakeBool "SLANG_USE_SYSTEM_FMT" true)
    (lib.cmakeBool "SLANG_USE_SYSTEM_TOMLPLUSPLUS" true)
  ];

  # This is a hacky way to get around the fact fmt hasn't yet
  # Been updated to 12.2 on nixpkgs.
  patchPhase = ''
    sed -i 's/fmt 12.2 REQUIRED/fmt 12.1 REQUIRED/g' third_party/slang/external/CMakeLists.txt
  '';

  # Check that the plugin can be loaded successfully and parse a simple file.
  doCheck = true;
  checkPhase = ''
     runHook preCheck
     echo "module tester(); endmodule;" > tester.sv
     yosys -p "plugin -i ./slang.so; read_slang tester.sv"
     runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp ./slang.so $out/slang.so

    runHook postInstall
  '';

  meta = with lib; {
    description = "SystemVerilog design elaborator into word-level netlist form";
    homepage    = "https://github.com/povik/sv-elab";
    license     = licenses.isc;
    maintainers = with maintainers; [ gitRaiku ];
    platforms   = platforms.all;
  };
})

