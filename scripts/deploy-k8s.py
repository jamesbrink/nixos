#!/usr/bin/env python3
"""
Deploy Kubernetes manifests and Helm charts with secret injection.

This script handles deploying k8s resources while automatically injecting
secrets from agenix, so secrets never need to be committed to git.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, Optional

try:
    import yaml
except ImportError:
    print(
        "Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr
    )
    sys.exit(1)


class SecretManager:
    """Manages secret retrieval from agenix."""

    def __init__(self, project_root: Path):
        self.project_root = project_root

    def get_secret(self, secret_path: str) -> str:
        """
        Retrieve a secret using secrets-print command.

        Args:
            secret_path: Path to secret (e.g., 'jamesbrink/github/quantierra-runner-token')

        Returns:
            Secret value as string
        """
        try:
            result = subprocess.run(
                ["secrets-print", secret_path],
                capture_output=True,
                text=True,
                check=True,
                cwd=self.project_root,
            )

            # Parse output - format is "GITHUB_TOKEN=value"
            for line in result.stdout.strip().split("\n"):
                if "=" in line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    if key.strip() == "GITHUB_TOKEN":
                        return value.strip()

            raise ValueError(f"Could not parse GITHUB_TOKEN from secret: {secret_path}")

        except subprocess.CalledProcessError as e:
            print(f"Error retrieving secret {secret_path}: {e.stderr}", file=sys.stderr)
            raise
        except FileNotFoundError:
            print(
                "Error: secrets-print command not found. Make sure you're in the nix dev shell.",
                file=sys.stderr,
            )
            sys.exit(1)


class HelmDeployer:
    """Handles Helm chart deployments."""

    def __init__(
        self, project_root: Path, secret_manager: SecretManager, dry_run: bool = False
    ):
        self.project_root = project_root
        self.secret_manager = secret_manager
        self.dry_run = dry_run

    def inject_secrets(self, values: Dict, secret_mappings: Dict[str, str]) -> Dict:
        """
        Inject secrets into values dictionary.

        Args:
            values: Helm values dictionary
            secret_mappings: Map of secret paths to value paths
                            e.g., {'jamesbrink/github/token': 'githubConfigSecret.github_token'}

        Returns:
            Values dictionary with secrets injected
        """
        result = values.copy()

        for secret_path, value_path in secret_mappings.items():
            secret = self.secret_manager.get_secret(secret_path)

            # Navigate nested dictionary path and set value
            keys = value_path.split(".")
            current = result
            for key in keys[:-1]:
                if key not in current:
                    current[key] = {}
                current = current[key]
            current[keys[-1]] = secret

        return result

    def deploy_chart(
        self,
        release_name: str,
        chart: str,
        namespace: str,
        values_file: Optional[Path] = None,
        values_dict: Optional[Dict] = None,
        version: Optional[str] = None,
        wait: bool = True,
        timeout: str = "10m",
        create_namespace: bool = True,
    ) -> bool:
        """
        Deploy a Helm chart.

        Args:
            release_name: Name of the Helm release
            chart: Chart reference (e.g., 'oci://ghcr.io/...' or 'repo/chart')
            namespace: Kubernetes namespace
            values_file: Optional path to base values file
            values_dict: Optional values dictionary (overrides values_file)
            version: Chart version
            wait: Wait for deployment to complete
            timeout: Timeout for wait
            create_namespace: Create namespace if it doesn't exist

        Returns:
            True if successful
        """
        cmd = [
            "helm",
            "upgrade",
            "--install",
            release_name,
            chart,
            "--namespace",
            namespace,
        ]

        if create_namespace:
            cmd.append("--create-namespace")

        if version:
            cmd.extend(["--version", version])

        if wait:
            cmd.extend(["--wait", "--timeout", timeout])

        # Handle values
        temp_file = None
        try:
            if values_dict:
                # Write values to temp file
                temp_file = tempfile.NamedTemporaryFile(
                    mode="w", suffix=".yaml", delete=False
                )
                yaml.dump(values_dict, temp_file, default_flow_style=False)
                temp_file.close()
                cmd.extend(["--values", temp_file.name])
            elif values_file:
                cmd.extend(["--values", str(values_file)])

            if self.dry_run:
                print(f"[DRY RUN] Would execute: {' '.join(cmd)}")
                if values_dict:
                    print(
                        f"[DRY RUN] Values:\n{yaml.dump(values_dict, default_flow_style=False)}"
                    )
                return True

            print(f"Deploying {release_name} to namespace {namespace}...")
            subprocess.run(cmd, check=True, text=True)
            print(f"✓ Successfully deployed {release_name}")
            return True

        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to deploy {release_name}: {e}", file=sys.stderr)
            return False

        finally:
            if temp_file and os.path.exists(temp_file.name):
                os.unlink(temp_file.name)


class GitHubRunnersDeployer:
    """Specialized deployer for GitHub Actions runners."""

    CHART = (
        "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
    )
    VERSION = "0.13.0"
    NAMESPACE = "github-runners"
    SECRET_PATH = "jamesbrink/github/quantierra-runner-token"

    TIERS = {
        "xl": {"release": "arc-runner-set-xl", "values_file": "values-xl.yaml"},
        "l": {"release": "arc-runner-set-l", "values_file": "values-l.yaml"},
        "m": {"release": "arc-runner-set-m", "values_file": "values-m.yaml"},
        "s": {"release": "arc-runner-set-s", "values_file": "values-s.yaml"},
    }

    def __init__(self, project_root: Path, helm_deployer: HelmDeployer):
        self.project_root = project_root
        self.helm_deployer = helm_deployer
        self.runners_dir = project_root / "k8s" / "quantierra-github-runners"

    def deploy_tier(self, tier: str) -> bool:
        """Deploy a specific runner tier."""
        if tier not in self.TIERS:
            print(
                f"Error: Unknown tier '{tier}'. Valid tiers: {', '.join(self.TIERS.keys())}",
                file=sys.stderr,
            )
            return False

        tier_config = self.TIERS[tier]
        values_file = self.runners_dir / tier_config["values_file"]

        if not values_file.exists():
            print(f"Error: Values file not found: {values_file}", file=sys.stderr)
            return False

        # Load base values
        with open(values_file) as f:
            values = yaml.safe_load(f)

        # Inject GitHub token
        values_with_secrets = self.helm_deployer.inject_secrets(
            values, {self.SECRET_PATH: "githubConfigSecret.github_token"}
        )

        # Deploy
        return self.helm_deployer.deploy_chart(
            release_name=tier_config["release"],
            chart=self.CHART,
            namespace=self.NAMESPACE,
            values_dict=values_with_secrets,
            version=self.VERSION,
            wait=True,
            timeout="5m",
        )

    def deploy_all(self) -> bool:
        """Deploy all runner tiers."""
        success = True
        for tier in self.TIERS.keys():
            if not self.deploy_tier(tier):
                success = False
        return success


def main():
    parser = argparse.ArgumentParser(
        description="Deploy Kubernetes manifests and Helm charts with secret injection"
    )

    subparsers = parser.add_subparsers(dest="command", help="Deployment command")

    # GitHub runners command
    runners_parser = subparsers.add_parser(
        "github-runners", help="Deploy GitHub Actions runners"
    )
    runners_parser.add_argument(
        "--tier",
        choices=["xl", "l", "m", "s", "all"],
        default="all",
        help="Runner tier to deploy (default: all)",
    )

    # Helm command
    helm_parser = subparsers.add_parser("helm", help="Deploy a generic Helm chart")
    helm_parser.add_argument("release", help="Release name")
    helm_parser.add_argument("chart", help="Chart reference")
    helm_parser.add_argument("--namespace", "-n", required=True, help="Namespace")
    helm_parser.add_argument("--values", "-f", help="Values file")
    helm_parser.add_argument("--version", help="Chart version")
    helm_parser.add_argument(
        "--inject-secret",
        action="append",
        metavar="SECRET_PATH:VALUE_PATH",
        help="Inject secret (e.g., 'jamesbrink/github/token:github.token')",
    )

    # Global options
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be deployed without deploying",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        help="Project root directory (default: auto-detect)",
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # Determine project root
    if args.project_root:
        project_root = args.project_root
    else:
        script_dir = Path(__file__).parent
        project_root = script_dir.parent

    if not project_root.exists():
        print(f"Error: Project root not found: {project_root}", file=sys.stderr)
        return 1

    # Initialize managers
    secret_manager = SecretManager(project_root)
    helm_deployer = HelmDeployer(project_root, secret_manager, dry_run=args.dry_run)

    # Execute command
    if args.command == "github-runners":
        runners_deployer = GitHubRunnersDeployer(project_root, helm_deployer)

        if args.tier == "all":
            success = runners_deployer.deploy_all()
        else:
            success = runners_deployer.deploy_tier(args.tier)

        return 0 if success else 1

    elif args.command == "helm":
        # Parse secret injections
        secret_mappings = {}
        if args.inject_secret:
            for mapping in args.inject_secret:
                try:
                    secret_path, value_path = mapping.split(":", 1)
                    secret_mappings[secret_path] = value_path
                except ValueError:
                    print(f"Error: Invalid secret mapping: {mapping}", file=sys.stderr)
                    return 1

        # Load values if provided
        values_dict = None
        if args.values:
            values_file = Path(args.values)
            if not values_file.exists():
                print(f"Error: Values file not found: {values_file}", file=sys.stderr)
                return 1

            with open(values_file) as f:
                values_dict = yaml.safe_load(f)

            # Inject secrets if requested
            if secret_mappings:
                values_dict = helm_deployer.inject_secrets(values_dict, secret_mappings)

        success = helm_deployer.deploy_chart(
            release_name=args.release,
            chart=args.chart,
            namespace=args.namespace,
            values_dict=values_dict,
            version=args.version,
        )

        return 0 if success else 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
