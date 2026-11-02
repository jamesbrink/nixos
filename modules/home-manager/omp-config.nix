# Links OMP's config files to a live checkout of the omp-config repo, so edits
# apply without a deploy and OMP can write to config.yml. See that repo's README.
{ config, lib, ... }:
let
  cfg = config.local.ompConfig;
  repo = "${config.home.homeDirectory}/Projects/jamesbrink/omp-config";
  link = path: {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/${path}";
    force = true;
  };
in
{
  options.local.ompConfig.host = lib.mkOption {
    type = lib.types.str;
    description = "Host name selecting config.<host>.yml in the omp-config repo";
  };

  config = {
    home.file = {
      ".omp/agent/agents" = link "agents";
      ".omp/agent/config.yml" = link "config.${cfg.host}.yml";
      ".omp/agent/extensions" = link "extensions";
      ".omp/agent/models.yml" = link "models.yml";
    };

    home.activation.ompConfigCheck = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "${repo}/.git" ]; then
        warnEcho "omp-config checkout missing at ${repo}; clone git@github.com:jamesbrink/omp-config.git"
      fi
    '';
  };
}
