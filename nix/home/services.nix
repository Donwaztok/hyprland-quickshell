{
  config,
  lib,
  pkgs,
  ...
}:
{
  systemd.user.services = {
    ydotool = {
      Unit.Description = "ydotool user daemon";
      Service = {
        ExecStart = "${lib.getExe pkgs.ydotool}d";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };

    polkit-gnome = {
      Unit.Description = "Polkit authentication agent";
      Service = {
        ExecStart = lib.getExe' pkgs.polkit_gnome "polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
