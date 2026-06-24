{
  config,
  lib,
  pkgs,
  local,
  ...
}:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
    };

    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "zsh-autosuggestions.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "zsh-syntax-highlighting.zsh";
      }
    ];

    shellAliases = {
      c = "clear";
      ls = "eza -lh --icons=auto";
      ll = "eza -lha --icons=auto --sort=name --group-directories-first";
      ld = "eza -lhD --icons=auto";
      lt = "eza --icons=auto --tree";
      vc = "cursor";

      up = "sudo nixos-rebuild switch --flake ~/.config#${local.flakeHost}";
      up-test = "sudo nixos-rebuild test --flake ~/.config#${local.flakeHost}";
      pl = "nix profile list";
      pa = "nix search nixpkgs";
      pc = "nix-collect-garbage -d";
      po = "nix-collect-garbage -d && nix store optimise";
    };

    initContent = lib.mkAfter ''
      eval "$(${pkgs.starship}/bin/starship init zsh)"

      export NVM_DIR="''${NVM_DIR:-$HOME/.nvm}"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

      if [[ -d "$HOME/Android/Sdk" ]]; then
        export ANDROID_HOME="$HOME/Android/Sdk"
        path+=(
          "$ANDROID_HOME/platform-tools"
          "$ANDROID_HOME/emulator"
        )
        [[ -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]] && path+=("$ANDROID_HOME/cmdline-tools/latest/bin")
      fi

      export UNITY_PATH="$HOME/Unity/Hub/Editor/6000.4.8f1/Editor/Unity"

      function command_not_found_handler {
        local cmd="$1"
        printf 'zsh: command not found: %s\n' "$cmd"
        if command -v nix-index >/dev/null 2>&1; then
          printf 'Try: nix-locate --top-level --no-flake --packages --whole-name %s\n' "$cmd"
        else
          printf 'Try: nix search nixpkgs %s\n' "$cmd"
        fi
        return 127
      }
    '';
  };

  programs.fzf.enable = true;
}
