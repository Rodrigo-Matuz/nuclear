{
  description = "Nuclear music player — Linux binary package and Home Manager module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux"; # Upstream publishes an amd64 .deb, not an ARM .deb.
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      version = "1.51.1";
      releaseTag = "player@${version}";
      # Repackage the published native .deb rather than rebuilding the pnpm
      # monorepo and Tauri/Rust backend. Use Nixpkgs' GTK/WebKitGTK libraries
      # instead of relying on a bundled AppImage runtime. For a new release,
      # update version, the literal release tag/asset name, and verified hash.
      deb = pkgs.fetchurl {
        url = "https://github.com/nukeop/nuclear/releases/download/${releaseTag}/Nuclear_${version}_amd64.deb";
        hash = "sha256-LEggg42LCs+qycE1jgOHNlMFUHRtXppL3cLy94BHmBg=";
      };
      package = pkgs.stdenv.mkDerivation {
        pname = "nuclear-music-player";
        inherit version;
        src = deb;
        nativeBuildInputs = with pkgs; [ dpkg autoPatchelfHook wrapGAppsHook3 ];
        buildInputs = with pkgs; [
          gtk3 webkitgtk_4_1 libsoup_3 gdk-pixbuf cairo glib glib-networking
          librsvg libayatana-appindicator
        ];
        unpackPhase = ''
          runHook preUnpack
          dpkg-deb -x "$src" .
          runHook postUnpack
        '';
        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;
        installPhase = ''
          runHook preInstall
          install -Dm755 usr/bin/nuclear-music-player "$out/bin/nuclear-music-player"
          mkdir -p "$out/share"
          cp -r usr/share/. "$out/share/"
          runHook postInstall
        '';
        preFixup = ''
          # WebKitGTK uses GStreamer for streamed audio and video.
          gappsWrapperArgs+=(--prefix GST_PLUGIN_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" (with pkgs.gst_all_1; [ gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav ])}")
        '';
        meta = {
          description = "Free, open-source music player without ads or tracking";
          homepage = "https://github.com/nukeop/nuclear";
          license = lib.licenses.agpl3Only;
          mainProgram = "nuclear-music-player";
          platforms = [ system ];
        };
      };
    in
    {
      packages.${system} = {
        default = package;
        nuclear-music-player = package;
      };

      homeManagerModules.default = { config, pkgs, lib, ... }:
        let
          cfg = config.programs.nuclear-music-player;
        in
        {
          options.programs.nuclear-music-player = {
            enable = lib.mkEnableOption "Nuclear music player";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              description = "Nuclear package to install.";
            };
          };
          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
          };
        };

      nixosModules.default = { config, pkgs, lib, ... }: {
        options.programs.nuclear-music-player.enable =
          lib.mkEnableOption "Nuclear music player system-wide";
        config = lib.mkIf config.programs.nuclear-music-player.enable {
          environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        };
      };
    };
}
