# Starship prompt configuration for all users
{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;

    settings = {
      # Two-line minimal prompt format
      format = "$username$hostname$directory$git_branch$git_status$nix_shell$aws\n$character";
      
      # Use single line prompt
      add_newline = false;

      # Username configuration
      username = {
        show_always = true;
        style_user = "green bold";
        style_root = "red bold";
        format = "[$user]($style) ";
      };

      # Hostname configuration
      hostname = {
        ssh_only = false;
        style = "dimmed green";
        format = "@ [$hostname]($style) ";
      };

      # Directory configuration
      directory = {
        style = "cyan bold";
        format = "[$path]($style) ";
        truncation_length = 3;
        truncate_to_repo = false;
      };

      # Git branch
      git_branch = {
        style = "purple bold";
        format = "[$symbol$branch]($style) ";
      };

      # Git status
      git_status = {
        style = "red bold";
        format = "[$all_status$ahead_behind]($style) ";
      };

      # AWS profile
      aws = {
        style = "yellow bold";
        format = " (\\($region\\)) ";
        symbol = "";
      };

      # Character (prompt symbol)
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      # Disable modules that might add extra lines
      line_break = {
        disabled = false;
      };

      cmd_duration = {
        disabled = true;
      };

      jobs = {
        disabled = true;
      };

      # Language/tool version modules (enabled but concise)
      nodejs = {
        format = "via [⬢ $version](bold green) ";
        detect_extensions = [
          "js"
          "mjs"
          "cjs"
          "ts"
          "mts"
          "cts"
        ];
      };

      python = {
        format = "via [🐍 $version](bold yellow) ";
        detect_extensions = [ "py" ];
      };

      rust = {
        format = "via [🦀 $version](bold red) ";
        detect_extensions = [ "rs" ];
      };

      golang = {
        format = "via [🐹 $version](bold cyan) ";
        detect_extensions = [ "go" ];
      };

      terraform = {
        format = "via [💠 $version](bold purple) ";
        detect_extensions = [
          "tf"
          "tfplan"
          "tfstate"
        ];
      };

      docker_context = {
        format = "via [🐋 $context](blue bold) ";
        only_with_files = true;
      };

      kubernetes = {
        format = "on [⛵ $context\\($namespace\\)](cyan bold) ";
        disabled = true;
      };

      nix_shell = {
        format = "via [❄️ $state( \\($name\\))](bold blue) ";
        impure_msg = "[impure](bold red)";
        pure_msg = "[pure](bold green)";
      };
    };
  };
}
