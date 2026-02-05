{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

let
  unstable = pkgs.unstablePkgs;

  # Python 3.13 with essential packages
  python313WithPackages = pkgs.python313.withPackages (
    ps: with ps; [
      # Core development tools
      pip
      setuptools
      wheel
      virtualenv

      # Modern Python tools
      ruff # Fast linter and formatter
      uv # Fast package installer

      # Scientific computing
      numpy
      scipy
      pandas
      matplotlib

      # Data manipulation and analysis
      openpyxl # Excel file support
      xlrd # Excel reader
      h5py # HDF5 support

      # Development utilities
      ipython
      jupyter
      notebook
      black # Code formatter
      mypy # Type checker
      pytest # Testing framework
      pytest-cov # Coverage plugin
      tox # Testing automation

      # Web and API development
      requests
      httpx
      fastapi
      uvicorn
      pydantic

      # Database
      sqlalchemy
      psycopg2

      # Async programming
      aiohttp

      # Utilities
      rich # Beautiful terminal formatting
      click # CLI creation
      tqdm # Progress bars
      python-dotenv # Environment variables
      pyyaml # YAML support
      toml # TOML support

      # System and automation
      boto3 # AWS SDK (keeping from original)
      paramiko # SSH
      fabric # Remote execution

      # Documentation
      sphinx
      mkdocs

      # MCP Tools (some deps for omnara)
      typer # CLI framework for MCP tools
      shellingham # Shell detection for typer
      authlib # Authentication library
      pydantic-settings # Settings management

      # Existing packages from default.nix
      pynvim # Neovim support (keeping from original)
    ]
  );
in
{
  environment.systemPackages =
    with pkgs;
    [
      # Base Python installation
      python313 # Python 3.13 (python313Full has been removed from nixpkgs)

      # Python 3.13 with bundled packages
      python313WithPackages

      # Standalone Python tools (better as separate packages)
      python313Packages.ruff
      python313Packages.uv
      pyright # Language server (keeping from original)
      # poetry removed - rapidfuzz build fails on Darwin (libatomic issue), use: pipx install poetry
      python313Packages.pipx # Install Python apps in isolated environments

      # Individual packages that were in original (for direct access)
      python313Packages.boto3 # AWS SDK (keeping from original)
      python313Packages.pip # Package installer (keeping from original)
      python313Packages.pynvim # Neovim support (keeping from original)

      # ML/AI packages (conditional for Linux due to heavy dependencies)
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # GUI support (tkinter causes zig-hook issues on Darwin)
      python313Packages.tkinter

      # Original ML packages
      python313Packages.torch # (keeping from original)
      python313Packages.torchvision # (keeping from original)
      python313Packages.torchaudio # (keeping from original)
      python313Packages.huggingface-hub # (keeping from original)
      python313Packages.llvmlite # (keeping from original)
      python313Packages.numba # (keeping from original)

      # Additional ML packages
      python313Packages.transformers
      python313Packages.scikit-learn

      # Note: TensorFlow doesn't support Python 3.13 yet (keeping from original)
      python312Packages.tensorflow
    ];
}
