{}:

{
  # https://wiki.archlinux.org/title/Fish#Modify_.bashrc_to_drop_into_fish
  bashrcExtra = ''
    if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} && ''${SHLVL} == 1 ]]
    then
      shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
      exec fish $LOGIN_OPTION
    fi
  '';
}
