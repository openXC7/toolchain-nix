{
  description = "Open RTL synthesis framework and tools";
  nixConfig.bash-prompt = "[nix(openXC7)] ";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
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
            artix7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix  {
              backend = "artix7";
              nixpkgs = pkgs;
              inherit nextpnr-xilinx;
              inherit prjxray;
            };
            kintex7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix {
              backend = "kintex7";
              nixpkgs = pkgs;
              inherit nextpnr-xilinx;
              inherit prjxray;
            };
            spartan7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix  {
              backend = "spartan7";
              nixpkgs = pkgs;
              inherit nextpnr-xilinx;
              inherit prjxray;
            } ;
            zynq7 = callPackage ./nix/nextpnr-xilinx-chipdb.nix {
              backend = "zynq7";
              nixpkgs = pkgs;
              inherit nextpnr-xilinx;
              inherit prjxray;
            };
          };

          yosys-synlig = callPackage ./nix/yosys-synlig.nix { };
        });

      # contains a mutually consistent set of packages for a full toolchain using nextpnr-xilinx.
      devShell = forAllSystems (system:
        nixpkgsFor.${system}.mkShell {
          buildInputs = (with self.packages.${system}; [
            fasm
            prjxray
            nextpnr-xilinx
            yosys-synlig
          ]) ++ (with nixpkgsFor.${system}; [
            yosys
            ghdl
            yosys-ghdl
            openfpgaloader
            pypy39
            python310Packages.pyyaml
            python310Packages.textx
            python310Packages.simplejson
            python310Packages.intervaltree
          ]);

          shellHook =
            let mypkgs  = self.packages.${system};
                nixpkgs = nixpkgsFor.${system};
            in nixpkgs.lib.concatStrings [
              "export NEXTPNR_XILINX_DIR=" mypkgs.nextpnr-xilinx.outPath "\n"
              "export NEXTPNR_XILINX_PYTHON_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/python/\n"
              "export PRJXRAY_DB_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/external/prjxray-db\n"
              "export PRJXRAY_PYTHON_DIR=" mypkgs.prjxray.outPath "/usr/share/python3/\n"
              ''export PYTHONPATH=''$PYTHONPATH:''$PRJXRAY_PYTHON_DIR:'' mypkgs.fasm.outPath "/lib/python3.11/site-packages/\n"
              "export PYPY3=" nixpkgs.pypy39.outPath "/bin/pypy3.9"
            ];
        }
      );

      dockerImage = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          mypkgs = self.packages.${system};
          chipdb = mypkgs.nextpnr-xilinx-chipdb;
          pyPkgPath = "/lib/python3.10/site-packages/:";
        in
        pkgs.dockerTools.buildImage {
          name = "openxc7-docker";
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = self.devShell.${system}.buildInputs ++ (with pkgs; [
              bashInteractive
              findutils
              gnused
              gnugrep
              coreutils
              gnumake
              python310
            ]) ++ (with chipdb; [
              spartan7
              artix7
              kintex7
              zynq7
            ]);
            pathsToLink = [ "/bin" ] ++ (with pkgs.dockerTools; [
              usrBinEnv
              binSh
            ]);
          };

          runAsRoot = pkgs.lib.concatStrings [ ''
            #!${pkgs.runtimeShell}
            mkdir -p /work
            cat > /bin/devshell <<EOF
            #!${pkgs.runtimeShell}
            '' self.devShell.${system}.shellHook "\n"
            "export NEXTPNR_XILINX_PYTHON_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/python/\n"
            "export PRJXRAY_DB_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/external/prjxray-db\n"
            "export PRJXRAY_PYTHON_DIR=" mypkgs.prjxray.outPath "/usr/share/python3/\n"
            ''export PYTHONPATH=\''$PYTHONPATH:\''$PRJXRAY_PYTHON_DIR:''
              pkgs.python310Packages.textx.outPath pyPkgPath
              pkgs.python310Packages.pyyaml.outPath pyPkgPath
              pkgs.python310Packages.simplejson.outPath pyPkgPath
              pkgs.python310Packages.intervaltree.outPath pyPkgPath
              pkgs.python310Packages.arpeggio.outPath pyPkgPath
              pkgs.python310Packages.setuptools.outPath pyPkgPath
              pkgs.python310Packages.future.outPath pyPkgPath
              pkgs.python310Packages.sortedcontainers.outPath pyPkgPath
              mypkgs.fasm.outPath "/lib/python3.11/site-packages/"
              "\n"
            "export NEXTPNR_XILINX_DIR=" mypkgs.nextpnr-xilinx.outPath "\n"
            "export SPARTAN7_CHIPDB="    chipdb.spartan7.outPath "\n"
            "export ARTIX7_CHIPDB="      chipdb.artix7.outPath "\n"
            "export KINTEX7_CHIPDB="     chipdb.kintex7.outPath "\n"
            "export ZYNQ7_CHIPDB="       chipdb.zynq7.outPath "\n"
            "\nexec ${pkgs.bashInteractive}/bin/bash\n"
            ''EOF
            chmod 755 /bin/devshell
          ''];

          config = {
            Cmd = [ "/bin/devshell" ];
            WorkingDir = "/work";
            Volumes = { "/work" = { }; };
          };
        }
      );
    };
}
