# NixOS Configuration

This repository contains NixOS configurations for multiple hosts using a flake-based setup.

## Project Structure

The repository is organized as follows:

- flake.nix - Main flake configuration
- hosts/ - Host-specific configurations
- modules/ - Shared modules

## Quick Start

Deploy to n100-01:

```shell
nixos-rebuild switch --fast --flake .#n100-01 --target-host n100-01 --build-host n100-01 --use-remote-sudo
```
