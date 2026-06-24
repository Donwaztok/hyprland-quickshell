{
  config,
  lib,
  pkgs,
  dotfiles,
  ...
}:
let
  filter = path: type: true;

  mkConfigDir = name: {
    source = lib.cleanSourceWith {
      src = "${dotfiles}/${name}";
      inherit filter;
    };
    recursive = true;
  };
in
{
  xdg.configFile =
    {
      "hypr" = mkConfigDir "hypr";
      "quickshell" = mkConfigDir "quickshell";
      "kitty" = mkConfigDir "kitty";
      "wlogout" = mkConfigDir "wlogout";
      "fastfetch" = mkConfigDir "fastfetch";
      "mako" = mkConfigDir "mako";
      "btop" = mkConfigDir "btop";
      "fontconfig" = mkConfigDir "fontconfig";
      "fuzzel" = mkConfigDir "fuzzel";
      "foot" = mkConfigDir "foot";
      "xdg-desktop-portal" = mkConfigDir "xdg-desktop-portal";
      "mpv" = mkConfigDir "mpv";
      "donwaztok" = mkConfigDir "donwaztok";
      "systemd/user/hyprland-session.target".source =
        "${dotfiles}/hypr/systemd/user/hyprland-session.target";
    }
    // lib.optionalAttrs (lib.pathExists "${dotfiles}/starship.toml") {
      "starship.toml".source = "${dotfiles}/starship.toml";
    }
    // lib.optionalAttrs (lib.pathExists "${dotfiles}/chrome-flags.conf") {
      "chrome-flags.conf".source = "${dotfiles}/chrome-flags.conf";
    }
    // lib.optionalAttrs (lib.pathExists "${dotfiles}/code-flags.conf") {
      "code-flags.conf".source = "${dotfiles}/code-flags.conf";
    }
    // lib.optionalAttrs (lib.pathExists "${dotfiles}/thorium-flags.conf") {
      "thorium-flags.conf".source = "${dotfiles}/thorium-flags.conf";
    };

  # Custom desktop entries from dotfiles
  xdg.dataFile."applications/cursor.desktop".source =
    "${dotfiles}/hypr/source/cursor.desktop";

  xdg.dataFile."applications/cursor-url-handler.desktop".source =
    "${dotfiles}/hypr/source/cursor-url-handler.desktop";

  xdg.dataFile."applications/vesktop.desktop".source =
    "${dotfiles}/hypr/source/vesktop.desktop";
}
