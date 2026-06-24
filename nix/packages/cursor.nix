# Cursor AppImage — based on https://github.com/jacopone/code-cursor-nix
# Update hash when upstream re-publishes the AppImage:
#   nix-prefetch-url 'https://downloads.cursor.com/production/.../Cursor-<ver>-x86_64.AppImage'
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  undmg,
  google-chrome,
  libxkbfile,
  libsecret,
  libGL,
  libdrm,
  mesa,
  nss,
  nspr,
  at-spi2-atk,
  at-spi2-core,
  libxkbcommon,
  wayland,
  gtk3,
  glib,
  pango,
  cairo,
  gdk-pixbuf,
  libnotify,
  cups,
  libpulseaudio,
  systemd,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
}:

let
  pname = "cursor";
  version = "3.8.23";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://downloads.cursor.com/production/7cf19b7482706625cdb70db3211b7dd035b7aa35/linux/x64/Cursor-${version}-x86_64.AppImage";
      hash = "sha256-ZLocbbOFaKPtBZuOMmuqqRDDe5BMNBNbOBmU8jrHHeI=";
    };
    aarch64-linux = fetchurl {
      url = "https://downloads.cursor.com/production/3a67af7b780e0bfc8d32aefa96b8ff1cb8817f88/linux/arm64/Cursor-${version}-aarch64.AppImage";
      hash = "sha256-kZf4qmOdtp3HFe/L6yehZ0cg5DklJwg+Lmnlhn6KBRM=";
    };
    x86_64-darwin = fetchurl {
      url = "https://downloads.cursor.com/production/3a67af7b780e0bfc8d32aefa96b8ff1cb8817f88/darwin/x64/Cursor-darwin-x64.dmg";
      hash = "sha256-GIBT7DU+J/hQ/qbDUdgRrO24z66JASQlfRpVFBsCiw0=";
    };
    aarch64-darwin = fetchurl {
      url = "https://downloads.cursor.com/production/3a67af7b780e0bfc8d32aefa96b8ff1cb8817f88/darwin/arm64/Cursor-darwin-arm64.dmg";
      hash = "sha256-NouEzXpKO2A3/y8FCNTXspm+Rim6a5Yi1yS1kLeevi8=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  appimageContents = appimageTools.extractType2 {
    inherit pname version;
    src = source;
  };
in
if stdenv.hostPlatform.isLinux then
  appimageTools.wrapType2 {
    inherit pname version;
    src = source;

    extraPkgs = pkgs: [
      google-chrome
      libxkbfile
      libxkbcommon
      libsecret
      nss
      nspr
      libGL
      libdrm
      mesa
      gtk3
      glib
      pango
      cairo
      gdk-pixbuf
      at-spi2-atk
      at-spi2-core
      wayland
      libnotify
      cups
      libpulseaudio
      systemd
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
      libxcb
    ];

    extraBwrapArgs = [
      "--setenv CHROME_BIN ${google-chrome}/bin/google-chrome-stable"
      "--setenv CHROME_PATH ${google-chrome}/bin/google-chrome-stable"
    ];

    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/cursor.desktop -t $out/share/applications
      substituteInPlace $out/share/applications/cursor.desktop \
        --replace-fail 'Exec=cursor' 'Exec=${pname}'

      for size in 16 32 48 64 128 256 512 1024; do
        if [ -f ${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/cursor.png ]; then
          install -Dm444 ${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/cursor.png \
            $out/share/icons/hicolor/''${size}x''${size}/apps/cursor.png
        fi
      done
    '';

    meta = with lib; {
      description = "AI-powered code editor built on VS Code";
      homepage = "https://cursor.com";
      license = licenses.unfree;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mainProgram = "cursor";
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  }
else if stdenv.hostPlatform.isDarwin then
  stdenv.mkDerivation {
    inherit pname version;
    src = source;

    nativeBuildInputs = [ undmg ];

    sourceRoot = "Cursor.app";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications/Cursor.app
      cp -R . $out/Applications/Cursor.app
      runHook postInstall
    '';

    meta = with lib; {
      description = "AI-powered code editor built on VS Code";
      homepage = "https://cursor.com";
      license = licenses.unfree;
      platforms = lib.platforms.darwin;
      mainProgram = "cursor";
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  }
else
  throw "Unsupported platform: ${stdenv.hostPlatform.system}"
