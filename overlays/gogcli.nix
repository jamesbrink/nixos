# gogcli overlay
# Google Workspace CLI (Gmail, Calendar, Drive, Contacts)
final: prev: {
  gogcli = final.callPackage ../pkgs/gogcli { };
}
