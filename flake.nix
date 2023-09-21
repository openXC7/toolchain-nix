{
  description = "Open RTL synthesis framework and tools";
  nixConfig.bash-prompt = "[nix(openXC7)] ";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-22.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils, ... }:
    let

      # to work with older version of flakes
      lastModifiedDate =
        self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in {

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          inherit (pkgs) lib callPackage stdenv fetchgit fetchFromGitHub;
        in rec {
          default = yosys;

          ghdl = pkgs.ghdl;

          abc-verifier = pkgs.abc-verifier.overrideAttrs (_: rec {
            version = "yosys-0.17";
            src = fetchFromGitHub {
              owner = "yosyshq";
              repo = "abc";
              rev = "09a7e6dac739133a927ae7064d319068ab927f90" # == version
              ;
              hash = "sha256-+1UcYjK2mvhlTHl6lVCcj5q+1D8RUTquHaajSl5NuJg=";
            };
            passthru.rev = src.rev;
          });

          yosys-ghdl = pkgs.yosys-ghdl;

          yosys = (pkgs.yosys.overrideAttrs (prev: rec {
            version = "0.17";

            src = fetchFromGitHub {
              owner = "yosyshq";
              repo = "yosys";
              rev = "${prev.pname}-${version}";
              hash = "sha256-IjT+G3figWe32tTkIzv/RFjy0GBaNaZMQ1GA8mRHkio=";
            };

            doCheck = true; # FIXME(ac): can we turn these back on?

            passthru = {
              inherit (prev) withPlugins;
              allPlugins = { ghdl = yosys-ghdl; };
            };
          })).override { inherit abc-verifier; };

          nextpnr-xilinx = stdenv.mkDerivation rec {
            pname = "nextpnr-xilinx";
            version = "0.5.1";

            src = fetchFromGitHub {
              owner = "openXC7";
              repo = "nextpnr-xilinx";
              rev = version;
              hash = "sha256-mDYEmq3MW1kK9HeR4PyGmKQnAzpvlOf+H66o7QTFx3k=";
              fetchSubmodules = true;
            };

            nativeBuildInputs = with pkgs; [ cmake git ];
            buildInputs = with pkgs;
              [ python310Packages.boost python310 eigen ]
              ++ (lib.optional stdenv.cc.isClang [ llvmPackages.openmp ]);

            setupHook = ./nextpnr-setup-hook.sh;

            cmakeFlags = [
              "-DCURRENT_GIT_VERSION=${lib.substring 0 7 src.rev}"
              "-DARCH=xilinx"
              "-DBUILD_GUI=OFF"
              "-DBUILD_TESTS=OFF"
              "-DUSE_OPENMP=ON"
            ];

            installPhase = ''
              mkdir -p $out/bin
              cp nextpnr-xilinx bba/bbasm $out/bin/
              mkdir -p $out/share/nextpnr/external
              cp -rv ../xilinx/external/prjxray-db $out/share/nextpnr/external/
              cp -rv ../xilinx/external/nextpnr-xilinx-meta $out/share/nextpnr/external/
              cp -rv ../xilinx/python/ $out/share/nextpnr/python/
              cp ../xilinx/constids.inc $out/share/nextpnr
            '';

            # FIXME(jl): why are these disabled? if unreasonable, should leave a comment
            doCheck = false;

            meta = with lib; {
              description = "Place and route tool for FPGAs";
              homepage = "https://github.com/openXC7/nextpnr-xilinx";
              license = licenses.isc;
              platforms = platforms.all;
            };
          };

          prjxray = stdenv.mkDerivation rec {
            pname = "prjxray";
            version = "76401bd93e493fd5ff4c2af4751d12105b0f4f6d";

            src = fetchFromGitHub {
              owner = "f4pga";
              repo = "prjxray";
              rev = "76401bd93e493fd5ff4c2af4751d12105b0f4f6d";
              fetchSubmodules = true;
              hash = "sha256-+k9Em+xX1rWPs3oATy3g1U0O6y3CATT9P42p0YCafxM=";
            };

            setupHook = ./prjxray-setup-hook.sh;

            nativeBuildInputs = with pkgs; [ cmake git ];
            buildInputs = with pkgs; [
              python310Packages.boost
              python310
              eigen
            ];

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
          };

        nextpnr-xilinx-chipdb = {
          artix7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix {
            backend = "artix7";
          };
          kintex7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix {
            backend = "kintex7";
          };
          spartan7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix {
            backend = "spartan7";
          };
          zynq7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix {
            backend = "zynq7";
          };
        });

      devShell = forAllSystems (system:
        nixpkgsFor.${system}.mkShell {
          buildInputs = with nixpkgsFor.${system}; [
            yosys
            ghdl
            yosys-ghdl
            prjxray
            nextpnr-xilinx
          ];
        });
    };
}
