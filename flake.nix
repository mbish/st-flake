{
  description = "My customized st executable";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-colors.url = "github:misterio77/nix-colors";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix-colors,
    flake-utils,
  }: let
    systems = ["x86_64-linux" "armv7l-linux" "aarch64-linux"];
    build = system: let
      fontsize = 18;
      colors = nix-colors.colorSchemes.gruvbox-material-dark-hard;
      templateFile = name: template: data:
        pkgs.stdenv.mkDerivation {
          name = "${name}";

          nativeBuildInpts = [pkgs.mustache-go];

          # Pass Json as file to avoid escaping
          passAsFile = ["jsonData"];
          jsonData = builtins.toJSON data;

          # Disable phases which are not needed. In particular the unpackPhase will
          # fail, if no src attribute is set
          phases = ["buildPhase" "installPhase"];

          buildPhase = ''
            ${pkgs.mustache-go}/bin/mustache $jsonDataPath ${template} > rendered_file
          '';

          installPhase = ''
            cp rendered_file $out
          '';
        };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
        ];
      };
      fontConfig = pkgs.makeFontsConf {
        fontDirectories = [
          (builtins.filter pkgs.lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts))
          "${pkgs.ubuntu_font_family}/share/fonts/ubuntu"
          "${pkgs.terminus_font}/share/fonts/terminus"
        ];
      };
    in {
      packages = rec {
        st = pkgs.st.overrideAttrs (oldAttrs: rec {
          patches = [
          ];
          configFile = templateFile "config.def.h" ./config.h {
            inherit fontsize;
            colors = colors.palette;
          };
          postPatch = "${oldAttrs.postPatch} \n cp ${configFile} config.def.h";
          propegatedBuildInputs = pkgs.terminus_font;
          postInstall = ''
            wrapProgram $out/bin/st \
              --set FONTCONFIG_FILE ${fontConfig}

            cp config.h $out/share
          '';
          nativeBuildInputs =
            oldAttrs.nativeBuildInputs
            ++ [
              pkgs.makeWrapper
            ];
        });
        default = st;
      };
    };
  in
    flake-utils.lib.eachSystem systems build;
}
