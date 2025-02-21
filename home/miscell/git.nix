{
  programs.git = {
    enable = true;
    userName = "Zigit Zo";
    userEmail = "repl@z.xas.is";
    signing.format = "ssh";
    extraConfig = {
      user.useConfigOnly = true;
      init.defaultBranch = "main";
    };
  };
}
