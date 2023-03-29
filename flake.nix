{
  description = "Open RTL synthesis framework and tools";
  homepage    = "https://yosyshq.net/yosys/";
  license     = licenses.isc;
  platforms   = platforms.all;

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-22.11";

  outputs = { self, nixpkgs }:
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

      # Provides a wrapper for creating a yosys with the specifed plugins preloaded
      #
      # Example:
      #
      #     my_yosys = yosys.withPlugins (with yosys.allPlugins; [
      #        fasm
      #        bluespec
      #     ]);
      withPlugins = plugins:
        let
          paths = lib.closePropagation plugins;
          module_flags = with builtins; concatStringsSep " "
            (map (n: "--add-flags -m --add-flags ${n.plugin}") plugins);
        in lib.appendToName "with-plugins" ( symlinkJoin {
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
        bluespec = yosys-bluespec;
        ghdl     = yosys-ghdl;
      } // (yosys-symbiflow);

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        yosys = with final; stdenv.mkDerivation rec {
          pname   = "yosys";
          version = "0.17";

          src = fetchFromGitHub {
            owner = "YosysHQ";
            repo  = "yosys";
            rev   = "${pname}-${version}";
            hash  = "sha256-mOakdXhSij8k4Eo7RwpKjd59IkNjw31NNFDJtL6Adgo=";
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
          doCheck = true;
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

          setupHook = ./setup-hook.sh;

          passthru = {
            inherit withPlugins allPlugins;
          };

          meta = with lib; {
            description = "Open RTL synthesis framework and tools";
            homepage    = "https://yosyshq.net/yosys/";
            license     = licenses.isc;
            platforms   = platforms.all;
            maintainers = with maintainers; [ shell thoughtpolice emily ];
          };
        }
      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) yosys;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.yosys);
    };
}
