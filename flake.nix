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
          prjxray-db = callPackage ./nix/prjxray-db.nix { };

          nextpnr = callPackage ./nix/nextpnr.nix { inherit prjxray-db; };

          prjxray = callPackage ./nix/prjxray.nix { };

          fasm = with pkgs;
            with python312Packages;
            callPackage ./nix/fasm {
              # NOTE(jleightcap): calling this package here is clucky.
              # contorted structure here to make the `nix/fasm` directory be
              # drop-in to upstream python-modules in nixpkgs.
              inherit buildPythonPackage pythonOlder textx cython fetchpatch jre_headless antlr4_9;
            };

          # The attribute keeps the nextpnr-xilinx name: it is the database
          # for the executable of that name in the devshell, and
          # demo-projects' smoke/heavy workflows build this attribute by name.
          nextpnr-xilinx-chipdb = {
            artix7 = callPackage ./nix/nextpnr-chipdb.nix  {
              backend = "artix7";
              nixpkgs = pkgs;
              inherit nextpnr prjxray-db;
            };
            kintex7 = callPackage ./nix/nextpnr-chipdb.nix {
              backend = "kintex7";
              nixpkgs = pkgs;
              inherit nextpnr prjxray-db;
            };
            spartan7 = callPackage ./nix/nextpnr-chipdb.nix  {
              backend = "spartan7";
              nixpkgs = pkgs;
              inherit nextpnr prjxray-db;
            } ;
            virtex7 = callPackage ./nix/nextpnr-chipdb.nix {
              backend = "virtex7";
              nixpkgs = pkgs;
              inherit nextpnr prjxray-db;
            };
            zynq7 = callPackage ./nix/nextpnr-chipdb.nix {
              backend = "zynq7";
              nixpkgs = pkgs;
              inherit nextpnr prjxray-db;
            };
          };

          fpga-assembler = (builtins.getFlake "github:lromor/fpga-assembler/6ff89a2d53edc9d74a402c28096450473b67de13").packages.${system}.default;

          sv-elab = callPackage ./nix/sv-elab.nix { };
        });

      # contains a mutually consistent set of packages for a full toolchain using openXC7/nextpnr.
      devShell = forAllSystems (system:
        nixpkgsFor.${system}.mkShell {
          buildInputs = (with self.packages.${system}; [
            fasm
            fpga-assembler
            nextpnr
            prjxray
            sv-elab
          ]) ++ (with nixpkgsFor.${system}; [
            yosys
            ghdl
            yosys-ghdl
            openfpgaloader
            pypy310
            python312Packages.pyyaml
            python312Packages.textx
            python312Packages.simplejson
            python312Packages.intervaltree
          ]);

          shellHook =
            let mypkgs  = self.packages.${system};
                nixpkgs = nixpkgsFor.${system};
                pyPkgPath = "/lib/python3.12/site-packages/:";
            in nixpkgs.lib.concatStrings [
              "export YOSYS_PLUGIN_PATH=" mypkgs.sv-elab.outPath "\n"
              "export NEXTPNR_XILINX_DIR=" mypkgs.nextpnr.outPath "\n"
              # The port has no bbaexport.py; the chipdbs come prebuilt from
              # nextpnr-xilinx-chipdb, so openXC7.mk's lazy-chipdb rule never
              # fires.  Kept so the exported interface is unchanged.
              "export NEXTPNR_XILINX_PYTHON_DIR=" mypkgs.nextpnr.outPath "/share/nextpnr\n"
              "export PRJXRAY_DB_DIR=" mypkgs.nextpnr.outPath "/share/nextpnr/external/prjxray-db\n"
              "export PRJXRAY_PYTHON_DIR=" mypkgs.prjxray.outPath "/usr/share/python3/\n"
              ''export PYTHONPATH=''$PYTHONPATH:''$PRJXRAY_PYTHON_DIR:'' 
                mypkgs.fasm.outPath pyPkgPath
                nixpkgs.python312Packages.textx.outPath pyPkgPath
                nixpkgs.python312Packages.arpeggio.outPath pyPkgPath
                nixpkgs.python312Packages.pyyaml.outPath pyPkgPath
                nixpkgs.python312Packages.simplejson.outPath pyPkgPath
                nixpkgs.python312Packages.intervaltree.outPath pyPkgPath
                nixpkgs.python312Packages.sortedcontainers.outPath pyPkgPath

                # Needed by fasm to import antlr correctly
                nixpkgs.python312Packages.cython.outPath pyPkgPath
                nixpkgs.python312Packages.distutils.outPath pyPkgPath
                nixpkgs.python312Packages.jaraco-envs.outPath pyPkgPath
                nixpkgs.python312Packages.jaraco-functools.outPath pyPkgPath
                nixpkgs.python312Packages.more-itertools.outPath pyPkgPath
                nixpkgs.python312Packages.packaging.outPath pyPkgPath
                "\n"
              "export PYPY3=" nixpkgs.pypy310.outPath "/bin/pypy3.10"
            ];
        }
      );

      # Minimal shell with the build dependencies of openXC7/nextpnr,
      # used by CI (and developers) to build and run it.
      ci-tests = forAllSystems (system:
        nixpkgsFor.${system}.mkShell {
          buildInputs = with nixpkgsFor.${system}; [
            cmake
            pkg-config
            python3
            python3Packages.boost
            eigen
          ];
        });

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
              python312
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
            "export NEXTPNR_XILINX_PYTHON_DIR=" mypkgs.nextpnr.outPath "/share/nextpnr\n"
            "export PRJXRAY_DB_DIR=" mypkgs.nextpnr.outPath "/share/nextpnr/external/prjxray-db\n"
            "export PRJXRAY_PYTHON_DIR=" mypkgs.prjxray.outPath "/usr/share/python3/\n"
            "export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive"
            ''export PYTHONPATH=\''$PYTHONPATH:\''$PRJXRAY_PYTHON_DIR:''
              pkgs.python312Packages.textx.outPath pyPkgPath
              pkgs.python312Packages.pyyaml.outPath pyPkgPath
              pkgs.python312Packages.simplejson.outPath pyPkgPath
              pkgs.python312Packages.intervaltree.outPath pyPkgPath
              pkgs.python312Packages.arpeggio.outPath pyPkgPath
              pkgs.python312Packages.setuptools.outPath pyPkgPath
              pkgs.python312Packages.future.outPath pyPkgPath
              pkgs.python312Packages.sortedcontainers.outPath pyPkgPath
              mypkgs.fasm.outPath "/lib/python3.12/site-packages/"
              "\n"
            "export NEXTPNR_XILINX_DIR=" mypkgs.nextpnr.outPath "\n"
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
