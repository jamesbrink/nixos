{
  config,
  lib,
  pkgs,
  ...
}:

let
  deltaBaseConfig = {
    enable = true;
    options = {
      navigate = true;
      light = false;
      line-numbers = true;
      syntax-theme = "gruvbox-dark";
      features = "decorations";
      decorations = {
        commit-decoration-style = "bold yellow box ul";
        file-style = "bold yellow ul";
        file-decoration-style = "none";
      };
    };
  };

  gitAliasConfig = {
    co = "checkout";
    ci = "commit";
    st = "status";
    br = "branch";
    hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
    type = "cat-file -t";
    dump = "cat-file -p";
  };

  gitExtraConfig = {
    init.defaultBranch = "main";
    pull.rebase = true;
    push.autoSetupRemote = true;
    merge.conflictstyle = "diff3";
    diff.colorMoved = "default";
    rerere.enabled = true;
  };

  gitSettingsConfig = {
    alias = gitAliasConfig;
  }
  // gitExtraConfig;
in
{
  home.packages =
    with pkgs;
    [
      eza # ls replacement
      bat # cat replacement with syntax highlighting
      fd # find replacement
      ripgrep # grep replacement
      procs # ps replacement
      sd # sed replacement
      dust # du replacement
      duf # df replacement
      broot # tree replacement with navigation
      pay-respects # thefuck replacement

      fzf # Fuzzy finder
      zoxide # Smart cd replacement
      ranger # Terminal file manager

      git
      delta # Better git diff
      lazygit # Terminal UI for git
      gh # GitHub CLI
      jq # JSON processor
      yq # YAML processor
      difftastic # Syntax-aware diff

      htop
      btop # Better top
      bottom # Another system monitor
      bandwhich # Network utilization monitor

      curl
      wget
      httpie # User-friendly HTTP client
      xh # Faster httpie alternative

      gawk
      gnused
      gnugrep

      unzip
      p7zip

      direnv # Directory-specific environments
      watchexec # Execute commands on file change
      tealdeer # Fast tldr client (provides tldr command)
      choose # Human-friendly cut
      neovim-remote # `nvr` helper for live Neovim automation

      # Disk usage analyzers
      gdu # Fast disk usage analyzer (Go-based)
      dua # Disk usage analyzer (Rust-based, interactive)
      erdtree # File-tree visualizer and disk usage analyzer

    ]
    ++ lib.optionals (!pkgs.stdenv.isx86_64) [
      ncdu # Disk usage analyzer (requires zig-hook which is broken on x86_64-darwin)
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      xclip # Clipboard support on Linux
    ];

  programs = {
    eza = {
      enable = true;
      enableZshIntegration = false; # Using custom aliases in zsh.nix instead
      git = true;
      icons = "auto";
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--inline-info"
        "--color=dark"
        "--color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f"
        "--color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7"
      ];
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetOptions = [
        "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
      ];
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      changeDirWidgetOptions = [
        "--preview 'eza --tree --level=2 --color=always {}'"
      ];
    };

    bat = {
      enable = true;
      config = {
        theme = "gruvbox-dark";
        style = "numbers,changes,header";
        pager = "less -FR";
      };
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv = {
        enable = !pkgs.stdenv.isDarwin;
      };
    };

    git = {
      enable = true;
      settings = gitSettingsConfig;
    };

    delta = deltaBaseConfig // {
      enableGitIntegration = true;
    };
  };

  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };
}
