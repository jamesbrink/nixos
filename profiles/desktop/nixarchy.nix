# Omarchy v4 desktop via nixarchy, offered as its own "Omarchy" session next to
# the existing Hyprland session. Omarchy's Quickshell shell brings the bar,
# menus, Wi-Fi/Bluetooth/audio/display panels, agent integration and theming.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Omarchy with two local changes:
  # - its idle screensaver plays the video screensavers (hypr-launch-screensaver,
  #   from modules/home-manager/hyprland) instead of the terminal text effect;
  # - theme switches reload open terminals. Upstream matches `pgrep -x ghostty`,
  #   but nixpkgs' wrappers run as `.ghostty-wrappe` / `.kitty-wrapped`.
  omarchy = (pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      cat > $out/share/omarchy/bin/omarchy-launch-screensaver <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      # omarchy:summary=Launch the video screensaver (nixarchy override).
      exec hypr-launch-screensaver "$@"
      SCRIPT
      chmod +x $out/share/omarchy/bin/omarchy-launch-screensaver

      cat > $out/share/omarchy/bin/omarchy-restart-terminal <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      # omarchy:summary=Reload supported terminal emulators after config changes
      if [[ -f ~/.config/alacritty/alacritty.toml ]]; then
        touch ~/.config/alacritty/alacritty.toml
      fi
      ${pkgs.procps}/bin/pkill -USR1 -x '\.?kitty(-wrapped?)?' || true
      ${pkgs.procps}/bin/pkill -USR2 -x '\.?ghostty(-wrappe(d)?)?' || true
      SCRIPT
      chmod +x $out/share/omarchy/bin/omarchy-restart-terminal
    '';
  });
in
{
  imports = [ inputs.nixarchy.nixosModules.nixarchy ];

  programs.nixarchy = {
    enable = true;
    package = omarchy;
    user = "jamesbrink";
    defaultAgent = "claude";
    # Keep our SDDM (autologin + theme) instead of nixarchy's greeter.
    displayManager = false;
    # Keep the existing boot (no Plymouth splash).
    bootSplash = "off";
  };

  # Autologin straight into the Omarchy session.
  services.displayManager.defaultSession = lib.mkForce "omarchy";

  # nixarchy defaults to linuxPackages_latest; stay on the release kernel so
  # ZFS and the NVIDIA driver keep matching what nixpkgs tests together.
  boot.kernelPackages = pkgs.linuxPackages;

  # Keep the Hyprland the rest of the system already uses (0.55, from nixpkgs).
  programs.hyprland.package = lib.mkForce pkgs.hyprland;
  programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;

  home-manager.users.jamesbrink =
    hm:
    let
      # Themed starship prompt, as themectl rendered it: the static settings from
      # modules/home-manager/shell/starship.nix with the theme's accent color
      # swapped in. Omarchy v4 themes ship no starship.toml, so a theme-set hook
      # renders it from colors.toml.
      starshipConfig = "${hm.config.xdg.stateHome}/omarchy/starship.toml";
      starshipTemplate = (pkgs.formats.toml { }).generate "starship-themed.toml" (
        lib.recursiveUpdate hm.config.programs.starship.settings {
          username.style_user = "@ACCENT@ bold";
          hostname.style = "dimmed @ACCENT@";
          directory.style = "@ACCENT@ bold";
          git_branch.style = "@ACCENT@ bold";
          character.success_symbol = "[❯](bold @ACCENT@)";
          nodejs.format = "via [⬢ $version](bold @ACCENT@) ";
          golang.format = "via [🐹 $version](bold @ACCENT@) ";
          kubernetes.format = "on [⛵ $context\\($namespace\\)](@ACCENT@ bold) ";
          nix_shell = {
            format = "via [❄️ $state( \\($name\\))](@ACCENT@ bold) ";
            pure_msg = "[pure](bold @ACCENT@)";
          };
        }
      );
      renderStarship = pkgs.writeShellScript "omarchy-starship-theme" ''
        colors="${hm.config.xdg.stateHome}/omarchy/current/theme/colors.toml"
        accent=$(${pkgs.gnused}/bin/sed -n 's/^accent *= *"\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$colors" 2>/dev/null)
        mkdir -p "$(dirname ${starshipConfig})"
        ${pkgs.gnused}/bin/sed "s/@ACCENT@/''${accent:-green}/g" ${starshipTemplate} >"${starshipConfig}.tmp"
        mv "${starshipConfig}.tmp" "${starshipConfig}"
      '';
    in
    {
      imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
      programs.nixarchy = {
        enable = true;
        package = omarchy;
      };
      # nixi (guided tour) pulls codex-acp, which fails to link on 26.05.
      services.nixi.enable = false;

      # omarchy-shell replaces the legacy desktop shell from
      # modules/home-manager/hyprland: bar, notifications, OSD, idle/lock.
      programs.waybar.enable = lib.mkForce false;
      services.mako.enable = lib.mkForce false;
      services.hypridle.enable = lib.mkForce false;
      # themectl writes Omarchy-v3 themes into ~/.config/omarchy/themes, which
      # Omarchy v4 reads as user-installed themes. It stays on Darwin.
      programs.themectl.enable = lib.mkForce false;

      # Hide tray apps the shell replaces with its Wi-Fi, Bluetooth and polkit panels.
      xdg.configFile =
        lib.genAttrs
          (map (n: "autostart/${n}.desktop") [
            "blueman"
            "iwgtk-indicator"
            "nm-applet"
            "polkit-gnome-authentication-agent-1"
          ])
          (_: {
            text = "[Desktop Entry]\nType=Application\nHidden=true\n";
          });

      # Default terminal is Ghostty. Seeded rather than linked: Omarchy's
      # "default terminal" menu rewrites this file, which a store symlink blocks.
      home.activation.seedDefaultTerminal = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        list="$HOME/.config/xdg-terminals.list"
        if [[ ! -e $list ]]; then
          $DRY_RUN_CMD printf '%s\n' com.mitchellh.ghostty.desktop >"$list"
        fi
      '';

      home.file.".config/omarchy/hooks/theme-set.d/starship".text = ''
        exec ${renderStarship}
      '';
      home.activation.renderStarshipTheme = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${renderStarship}
      '';
      home.sessionVariables.STARSHIP_CONFIG = lib.mkForce starshipConfig;
      # Also set per shell: sessions started before a rebuild keep a stale value.
      programs.zsh.initContent = ''
        export STARSHIP_CONFIG="${starshipConfig}"
      '';
    };
}
