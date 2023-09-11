{
  description = "Open RTL synthesis framework and tools";
  nixConfig.bash-prompt = "[nix(openXC7)] ";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url     = "nixpkgs/nixos-22.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

      lib = nixpkgs.lib;

    in
    {
      # A Nixpkgs overlay.
      overlay = final: prev: rec {
        ghdl = with final; stdenv.mkDerivation rec {
          backend = "mcode";
          pname = "ghdl-${backend}";
          version = "2.0.0";

          src = fetchFromGitHub {
            owner  = "ghdl";
            repo   = "ghdl";
            rev    = "v${version}";
            sha256 = "sha256-B/G3FGRzYy4Y9VNNB8yM3FohiIjPJhYSVbqsTN3cL5k=";
          };

          patches = [
            # https://github.com/ghdl/ghdl/issues/2056
            (fetchpatch {
              name = "fix-build-gcc-12.patch";
              url = "https://github.com/ghdl/ghdl/commit/f8b87697e8b893b6293ebbfc34670c32bfb49397.patch";
              hash = "sha256-tVbMm8veFkNPs6WFBHvaic5Jkp1niyg0LfFufa+hT/E=";
            })
          ];

          LIBRARY_PATH = "${stdenv.cc.libc}/lib";

          nativeBuildInputs = [
            gnat
          ];
          buildInputs = [
            zlib
          ] ++ lib.optionals (backend == "llvm") [
            llvm
          ];
          propagatedBuildInputs = [
          ] ++ lib.optionals (backend == "llvm") [
            zlib
          ];

          preConfigure = ''
            # If llvm 7.0 works, 7.x releases should work too.
            sed -i 's/check_version  7.0/check_version  7/g' configure
          '';

          configureFlags = [
            # See https://github.com/ghdl/ghdl/pull/2058
            "--disable-werror"
            "--enable-synth"
          ] ++ lib.optionals (backend == "llvm") [
            "--with-llvm-config=${llvm.dev}/bin/llvm-config"
          ];

          hardeningDisable = [ "format" ];

          enableParallelBuilding = true;

          passthru = {
            # run with either of
            # nix-build -A ghdl-mcode.passthru.tests
            # nix-build -A ghdl-llvm.passthru.tests
            tests = {
              simple = callPackage ./test-simple.nix { inherit backend; };
            };
          };

          meta = with lib; {
            homepage = "https://github.com/ghdl/ghdl";
            description = "VHDL 2008/93/87 simulator";
            maintainers = with maintainers; [ lucus16 thoughtpolice ];
            platforms = platforms.linux;
            license = licenses.gpl2;
          };
        };

        abc-verifier = with final; stdenv.mkDerivation rec {
          pname   = "abc-verifier";
          version = "for-yosys-0.17";

          src = fetchFromGitHub {
            owner = "yosyshq";
            repo  = "abc";
            rev   = "09a7e6d";
            hash  = "sha256-+1UcYjK2mvhlTHl6lVCcj5q+1D8RUTquHaajSl5NuJg=";
          };

          nativeBuildInputs = [ cmake ];
          buildInputs = [ readline ];

          installPhase = "mkdir -p $out/bin && mv abc $out/bin";

          # needed by yosys
          passthru.rev = src.rev;

          meta = with lib; {
            description = "A tool for squential logic synthesis and formal verification";
            homepage    = "https://people.eecs.berkeley.edu/~alanmi/abc";
            license     = licenses.mit;
            maintainers = with maintainers; [ thoughtpolice ];
            mainProgram = "abc";
            platforms   = platforms.unix;
          };
        };

        yosys-ghdl = with final; stdenv.mkDerivation {
          pname = "yosys-ghdl";
          # This is not the latest commit, but it's the latest that builds with current stable ghdl 2.0.0
          version = "2022.01.11";

          src = fetchFromGitHub {
            owner  = "ghdl";
            repo   = "ghdl-yosys-plugin";
            rev    = "c9b05e481423c55ffcbb856fd5296701f670808c";
            sha256 = "sha256-tT2+DXUtbJIBzBUBcyG2sz+3G+dTkciLVIczcRPr0Jw=";
          };

          buildInputs = [
            yosys
            readline
            zlib
            ghdl
          ];
          nativeBuildInputs = [
            pkg-config
          ];

          doCheck = true;
          installPhase = ''
            mkdir -p $out/share/yosys/plugins
            cp ghdl.so $out/share/yosys/plugins/ghdl.so
          '';

          meta = with lib; {
            description = "GHDL plugin for Yosys";
            homepage    = "https://github.com/ghdl/ghdl-yosys-plugin";
            license     = licenses.isc;
            platforms   = platforms.all;
            maintainers = with maintainers; [ thoughtpolice ];
          };
        };

        yosys = with final; stdenv.mkDerivation rec {
          pname   = "yosys";
          version = "0.17";

          src = fetchFromGitHub {
            owner = "YosysHQ";
            repo  = "yosys";
            rev   = "${pname}-${version}";
            hash  = "sha256-IjT+G3figWe32tTkIzv/RFjy0GBaNaZMQ1GA8mRHkio=";
          };

          enableParallelBuilding = true;
          nativeBuildInputs = [ pkg-config bison flex ];
          buildInputs = [
            tcl
            readline
            libffi
            zlib
            (python3.withPackages (pp: with pp; [
              click
            ]))
          ];

          makeFlags = [ "PREFIX=${placeholder "out"}"];

          patches = [
            ./plugin-search-dirs.patch
            ./fix-clang-build.patch # see https://github.com/YosysHQ/yosys/issues/2011
          ];

          postPatch = ''
            substituteInPlace ./Makefile \
              --replace 'echo UNKNOWN' 'echo ${builtins.substring 0 10 src.rev}'

            chmod +x ./misc/yosys-config.in
            patchShebangs tests ./misc/yosys-config.in
          '';

          preBuild = let
            shortAbcRev = builtins.substring 0 7 abc-verifier.rev;
          in ''
            chmod -R u+w .
            make config-${if stdenv.cc.isClang or false then "clang" else "gcc"}
            echo 'ABCEXTERNAL = ${abc-verifier}/bin/abc' >> Makefile.conf

            cat Makefile

            if ! grep -q "ABCREV = ${shortAbcRev}" Makefile; then
              echo "ERROR: yosys isn't compatible with the provided abc (${shortAbcRev}), failing."
              exit 1
            fi

            if ! grep -q "YOSYS_VER := $version" Makefile; then
              echo "ERROR: yosys version in Makefile isn't equivalent to version of the nix package (allegedly ${version}), failing."
              exit 1
            fi
          '';

          checkTarget = "test";
          doCheck = false;
          checkInputs = [ verilog ];

          # Internally, yosys knows to use the specified hardcoded ABCEXTERNAL binary.
          # But other tools (like mcy or symbiyosys) can't know how yosys was built, so
          # they just assume that 'yosys-abc' is available -- but it's not installed
          # when using ABCEXTERNAL
          #
          # add a symlink to fake things so that both variants work the same way. this
          # is also needed at build time for the test suite.
          postBuild   = "ln -sfv ${abc-verifier}/bin/abc ./yosys-abc";
          postInstall = "ln -sfv ${abc-verifier}/bin/abc $out/bin/yosys-abc";

          setupHook = ./yosys-setup-hook.sh;

          passthru =
            let
              withPlugins = plugins:
                  let
                    paths = lib.closePropagation plugins;
                    module_flags = with builtins; concatStringsSep " "
                      (map (n: "--add-flags -m --add-flags ${n.plugin}") plugins);
                  in lib.appendToName "with-plugins" ( lib.symlinkJoin {
                    inherit (yosys) name;
                    paths = paths ++ [ yosys ] ;
                    nativeBuildInputs = [ makeWrapper ];
                    postBuild = ''
                      wrapProgram $out/bin/yosys \
                        --set NIX_YOSYS_PLUGIN_DIRS $out/share/yosys/plugins \
                        ${module_flags}
                    '';
                  });

              allPlugins = {
                ghdl = yosys-ghdl;
              };
            in {
              inherit withPlugins allPlugins;
            };

          meta = with lib; {
            description = "Open RTL synthesis framework and tools";
            homepage    = "https://yosyshq.net/yosys/";
            license     = licenses.isc;
            platforms   = platforms.all;
            maintainers = with maintainers; [ thoughtpolice ];
          };
        };

        
        nextpnr-xilinx = with final; stdenv.mkDerivation rec {
          pname = "nextpnr-xilinx";
          version = "0.5.0";

          srcs = [
            (fetchgit {
            url = "https://github.com/openXC7/nextpnr-xilinx";
              rev = version;
              fetchSubmodules = true;
              deepClone = false;
              hash = "sha256-mDYEmq3MW1kK9HeR4PyGmKQnAzpvlOf+H66o7QTFx3k=";
              leaveDotGit = false;
            })
          ];

          sourceRoot = "nextpnr-xilinx";

          nativeBuildInputs
            = [ cmake git ];
          buildInputs
            = [ python310Packages.boost python310 eigen ]
            ++ (lib.optional stdenv.cc.isClang llvmPackages.openmp);

          setupHook = ./nextpnr-setup-hook.sh;

          cmakeFlags =
            [ "-DCURRENT_GIT_VERSION=${lib.substring 0 7 (lib.elemAt srcs 0).rev}"
              "-DARCH=xilinx"
              "-DBUILD_GUI=OFF"
              "-DBUILD_TESTS=OFF"
              "-DUSE_OPENMP=ON"
            ];

          installPhase = ''
            mkdir -p $out/bin
            cp nextpnr-xilinx bba/bbasm $out/bin/
            mkdir -p $out/usr/share/nextpnr/external
            cp -rv ../xilinx/external/prjxray-db $out/usr/share/nextpnr/external/
            cp -rv ../xilinx/external/nextpnr-xilinx-meta $out/usr/share/nextpnr/external/
            cp -rv ../xilinx/python/ $out/usr/share/nextpnr/python/
            cp ../xilinx/constids.inc $out/usr/share/nextpnr
          '';

          doCheck = false;

          meta = with lib; {
            description = "Place and route tool for FPGAs";
            homepage    = "https://github.com/openXC7/nextpnr-xilinx";
            license     = licenses.isc;
            platforms   = platforms.all;
            maintainers = with maintainers; [ thoughtpolice ];
          };
        };

        prjxray = with final; stdenv.mkDerivation rec {
          pname   = "prjxray";
          version = "76401bd93e493fd5ff4c2af4751d12105b0f4f6d";

          srcs = [
            (fetchgit {
              url = "https://github.com/f4pga/prjxray";
              rev = "76401bd93e493fd5ff4c2af4751d12105b0f4f6d";
              fetchSubmodules = true;
              deepClone = false;
              hash = "sha256-+k9Em+xX1rWPs3oATy3g1U0O6y3CATT9P42p0YCafxM=";
              leaveDotGit = false;
            })
          ];

          setupHook = ./prjxray-setup-hook.sh;

          nativeBuildInputs
            = [ cmake git ];
          buildInputs
            = [ python310Packages.boost python310 eigen ];

          installPhase = ''
            mkdir -p $out/bin
            cp -v tools/xc7frames2bit tools/xc7patch $out/bin
            mkdir -p $out/usr/share/python3/
            cp -rv $srcs/prjxray $out/usr/share/python3/
          '';

          doCheck = false;

          meta = with lib; {
            description = "Xilinx series 7 FPGA bitstream documentation";
            homepage    = "https://github.com/f4pga/prjxray";
            license     = licenses.isc;
            platforms   = platforms.all;
            maintainers = with maintainers; [ thoughtpolice ];
          };
        };

        nextpnr-xilinx-chipdb = {
          artix7   = prev.callPackage ./nix/nextpnr-xilinx-chipdb.nix { backend = "artix7";   };
          kintex7  = prev.callPackage ./nix/nextpnr-xilinx-chipdb.nix { backend = "kintex7";  };
          spartan7 = prev.callPackage ./nix/nextpnr-xilinx-chipdb.nix { backend = "spartan7"; };
          zynq7    = prev.callPackage ./nix/nextpnr-xilinx-chipdb.nix { backend = "zynq7";    };
        };
      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) yosys ghdl yosys-ghdl prjxray nextpnr-xilinx nextpnr-xilinx-chipdb;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.yosys);

      devShell = forAllSystems (system:
          nixpkgsFor.${system}.mkShell {
            buildInputs = with nixpkgsFor.${system}; [ yosys ghdl yosys-ghdl prjxray nextpnr-xilinx ];
          }
      );
    };
}
