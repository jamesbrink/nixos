{ hotkeysBundle, ... }:
{
  home-manager.extraSpecialArgs = {
    inherit hotkeysBundle;
  };
}
