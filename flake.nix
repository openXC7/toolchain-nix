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

          # override yosys with version suitable for ingest by nextpnr-xilinx.
          yosys = (pkgs.yosys.overrideAttrs (prev: rec {
            version = "0.17";

            src = fetchFromGitHub {
              owner = "yosyshq";
              repo = "yosys";
              rev = "${prev.pname}-${version}";
              hash = "sha256-IjT+G3figWe32tTkIzv/RFjy0GBaNaZMQ1GA8mRHkio=";
            };

            doCheck = true;

            passthru = {
              inherit (prev) withPlugins;
              allPlugins = { ghdl = yosys-ghdl; };
            };
          })).override { inherit abc-verifier; };

          nextpnr-xilinx = callPackage ./nix/nextpnr-xilinx.nix { };

          prjxray = callPackage ./nix/prjxray.nix { };

          fasm = with pkgs;
            with python3Packages;
            callPackage ./nix/fasm {
              # NOTE(jleightcap): calling this package here is clucky.
              # contorted structure here to make the `nix/fasm` directory be
              # drop-in to upstream python-modules in nixpkgs.
              inherit buildPythonPackage pythonOlder textx cython fetchpatch;
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
          };
        });

      # contains a mutually consistent set of packages for a full toolchain using nextpnr-xilinx.
      devShell = forAllSystems (system:
        nixpkgsFor.${system}.mkShell {
          buildInputs = with self.packages.${system}; [
            yosys
            ghdl
            yosys-ghdl
            prjxray
            nextpnr-xilinx
            fasm
          ];
        });
    };
}
