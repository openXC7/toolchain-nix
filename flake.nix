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
          yosys-version = "0.42";
        in rec {
          ghdl = pkgs.ghdl;

          abc-verifier = pkgs.abc-verifier.overrideAttrs (_: rec {
            version = "yosys-${yosys-version}";
            src = fetchFromGitHub {
              owner = "yosyshq";
              repo = "abc";
              rev = "237d81397fcc85dd3894bf1a449d2955cd3df02d";
              hash = "sha256-t3wdt/jGyF3Ysd0rzDYvPzECgOAL87/IJlHh3FGaF1k=";
            };
            passthru.rev = src.rev;
          });

          yosys-ghdl = pkgs.yosys-ghdl;

          # override yosys with version suitable for ingest by nextpnr-xilinx.
          yosys = (pkgs.yosys.overrideAttrs (prev: rec {
            version = yosys-version;

            src = fetchFromGitHub {
              owner = "yosyshq";
              repo = "yosys";
              rev = "${prev.pname}-${version}";
              hash = "sha256-dkZ3k2yPRmnQsbWNIUY9CbkzS2yvEyssLrqp6Z28cQY=";
            };

            patches = [
              ./plugin-search-dirs.patch
              # This patch does not apply in 0.42
              # ./fix-clang-build.patch # see https://github.com/YosysHQ/yosys/issues/2011
            ];

            postPatch = ''
              substituteInPlace ./Makefile \
                --replace-fail 'echo UNKNOWN' 'echo ${builtins.substring 0 10 src.rev}'

              chmod +x ./misc/yosys-config.in
              patchShebangs tests ./misc/yosys-config.in
            '';

            preBuild = ''
              chmod -R u+w .
              make config-${if stdenv.cc.isClang or false then "clang" else "gcc"}
              echo 'ABCEXTERNAL = ${abc-verifier}/bin/abc' >> Makefile.conf

              if ! grep -q "YOSYS_VER := $version" Makefile; then
                echo "ERROR: yosys version in Makefile isn't equivalent to version of the nix package (allegedly ${version}), failing."
                exit 1
              fi

              echo "ENABLE_PYOSYS := 1" >> Makefile.conf
              echo "PYTHON_DESTDIR := $out/${pkgs.python312.sitePackages}" >> Makefile.conf
              echo "BOOST_PYTHON_LIB := -L ${pkgs.python312Packages.boost.outPath}/lib -lboost_python312" >> Makefile.conf
            '';

            # for upstream packaging this should be true, but for the users
            # of this repository, who just want to install the toolchain,
            # it is very redundant to run these checks, which take a long time
            doCheck = false;

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
            yosys
            ghdl
            yosys-ghdl
            fasm
            prjxray
            nextpnr-xilinx
            yosys-synlig
          ]) ++ (with nixpkgsFor.${system}; [
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
            in nixpkgs.lib.concatStrings [
              "export NEXTPNR_XILINX_DIR=" mypkgs.nextpnr-xilinx.outPath "\n"
              "export NEXTPNR_XILINX_PYTHON_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/python/\n"
              "export PRJXRAY_DB_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/external/prjxray-db\n"
              "export PRJXRAY_PYTHON_DIR=" mypkgs.prjxray.outPath "/usr/share/python3/\n"
              ''export PYTHONPATH=''$PYTHONPATH:''$PRJXRAY_PYTHON_DIR:'' mypkgs.fasm.outPath "/lib/python3.11/site-packages/\n"
              "export PYPY3=" nixpkgs.pypy310.outPath "/bin/pypy3.10"
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
            "export NEXTPNR_XILINX_PYTHON_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/python/\n"
            "export PRJXRAY_DB_DIR=" mypkgs.nextpnr-xilinx.outPath "/share/nextpnr/external/prjxray-db\n"
            "export PRJXRAY_PYTHON_DIR=" mypkgs.prjxray.outPath "/usr/share/python3/\n"
            ''export PYTHONPATH=\''$PYTHONPATH:\''$PRJXRAY_PYTHON_DIR:''
              pkgs.python312Packages.textx.outPath pyPkgPath
              pkgs.python312Packages.pyyaml.outPath pyPkgPath
              pkgs.python312Packages.simplejson.outPath pyPkgPath
              pkgs.python312Packages.intervaltree.outPath pyPkgPath
              pkgs.python312Packages.arpeggio.outPath pyPkgPath
              pkgs.python312Packages.setuptools.outPath pyPkgPath
              pkgs.python312Packages.future.outPath pyPkgPath
              pkgs.python312Packages.sortedcontainers.outPath pyPkgPath
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
