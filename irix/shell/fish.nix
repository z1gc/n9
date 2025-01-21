{ ... }: # <- Flake inputs

# Making the Fish shell.
# No arguments. <- Module arguments.

{ pkgs, ... }: # <- Nix `imports = []`
{
  home.packages = with pkgs; [
    zoxide
    ripgrep
    fd
    fzf
    sysstat
    lm_sensors
    bcc
    bpftrace
  ];

  programs = {
    bash = {
      enable = true;

      # https://nixos.wiki/wiki/Fish
      bashrcExtra = ''
        case "$(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm)" in
        "fish"|"systemd")
          ;;
        *)
          if [[ -z ''${BASH_EXECUTION_STRING} && ''${SHLVL} == 1 ]]; then
            shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
            exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
          fi ;;
        esac
      '';
    };

    fish = {
      enable = true;

      plugins = [
        {
          name = "autols";
          src = pkgs.fetchFromGitHub {
            owner = "kpbaks";
            repo = "autols.fish";
            rev = "fe2693e80558550e0d995856332b280eb86fde19";
            hash = "sha256-EPgvY8gozMzai0qeDH2dvB4tVvzVqfEtPewgXH6SPGs=";
          };
        }
        {
          name = "upto";
          src = pkgs.fetchFromGitHub {
            owner = "Markcial";
            repo = "upto";
            rev = "2d1f35453fb55747d50da8c1cb1809840f99a646";
            hash = "sha256-Lv2XtP2x9dkIkUUjMBWVpAs/l55Ztu7gIjKYH6ZzK4s=";
          };
        }
        {
          name = "fzf";
          src = pkgs.fishPlugins.fzf-fish.src;
        }
      ];

      functions = {
        _fzf_search_ripgrep = {
          body = ''
            # Copy from '_fzf_search_directory':
            set -f token (commandline --current-token)
            # expand any variables or leading tilde (~) in the token
            set -f expanded_token (eval echo -- $token)
            # unescape token because it's already quoted so backslashes will mess up the path
            set -f unescaped_exp_token (string unescape -- $expanded_token)

            # If token empty, don't fresh the result:
            set -l rg_cmd rg --column --line-number --no-heading --color=always
            if test "$unescaped_exp_token" = ""
              set -f fzf_cmd "cat /dev/null"
            else
              set -f fzf_cmd "$rg_cmd \"$unescaped_exp_token\""
            end

            # https://codeberg.org/tplasdio/rgfzf/src/branch/main/rgfzf
            # TODO: Save queries for both ripgrep and fzf:
            set -f file_paths_selected (FZF_DEFAULT_COMMAND="$fzf_cmd" \
              _fzf_wrapper --multi --ansi --delimiter : --layout=reverse --header-first --marker="*" \
              --query "$unescaped_exp_token" \
              --disabled \
              --bind "alt-k:clear-query" \
              --bind "ctrl-y:unbind(change,ctrl-y)+change-prompt(fzf: )+enable-search+clear-query+rebind(ctrl-r)" \
              --bind "ctrl-r:unbind(ctrl-r)+change-prompt(rg: )+disable-search+clear-query+reload($rg_cmd {q} || true)+rebind(change,ctrl-y)" \
              --bind "change:reload:sleep 0.2; $rg_cmd {q} || true" \
              --prompt "rg: " \
              --header "switch: rg (ctrl+r) / fzf (ctrl+y)" \
              --preview 'bat --color=always {1} --highlight-line {2} --line-range $(math max {2}-15,0):' \
              --preview-window 'down,60%,noborder,+{2}+3/3,-3' | cut -s -d: -f1-3)

            if test $status -eq 0
              commandline --current-token --replace -- (string escape -- $file_paths_selected | string join ' ')
            end

            commandline --function repaint
          '';
        };

        _fzf_switch_common = {
          body = ''
            set -l indicator $argv[1]

            # abbr doesn't play very well with commandline...
            switch (commandline -t)
              case fd
                set -u fzf_fd_opts
                set -f func _fzf_search_directory
              case fa
                set -g fzf_fd_opts --hidden --no-ignore
                set -f func _fzf_search_directory
              case re
                set -f func _fzf_search_ripgrep
              case p
                set -f func _fzf_search_processes
              case gs
                set -f func _fzf_search_git_status
              case gl
                set -f func _fzf_search_git_log
              case '*'
                commandline -i "$indicator"
                return
            end

            if test "$indicator" = ";"
              commandline -rt ""
            else
              # Remove the last token of commandline, TODO: performance?
              set -l tokens (commandline -o)[1..-2]
              commandline -r (string join ' ' $tokens)
            end

            $func
          '';
        };

        fish_prompt = {
          body = ''
            set -g fish_last_status $status
            set -l host ""
            if set -q SSH_TTY
              set host "@"(string split -f1 -m1 ' ' $SSH_CONNECTION)
            end

            printf "\033[K"
            set_color brblack
            echo -n '['(prompt_pwd -d 0)"]$host"
            echo -n (fish_vcs_prompt)
            echo

            if test -n "$IN_NIX_SHELL"
              set_color green
              echo -n "nix-shell "
              set_color brblack
            end

            echo -n (string repeat -n $SHLVL '$')
            echo -n ' '

            set_color normal
          '';
        };

        fish_right_prompt = {
          body = ''
            # https://github.com/fish-shell/fish-shell/issues/1706#issuecomment-2430550184
            tput sc
            tput cuu1
            tput cuf 2

            if test $fish_last_status -ne 0
              set_color red
              echo -n "$fish_last_status"
              set_color brblack
              echo -n " | "
            else
              set_color brblack
            end

            if test $CMD_DURATION -ne 0
              # https://unix.stackexchange.com/a/27014
              set -l d (math -s 0 $CMD_DURATION / 1000 / 60 / 60 / 24)
              set -l h (math -s 0 $CMD_DURATION / 1000 / 60 / 60 % 24)
              set -l m (math -s 0 $CMD_DURATION / 1000 / 60 % 60)
              set -l s (math -s 0 $CMD_DURATION / 1000 % 60)
              set -l ms (math -s 0 $CMD_DURATION % 1000)

              test $d -gt 0 && echo -n "$d""d"
              test $h -gt 0 && echo -n "$h""h"
              test $m -gt 0 && echo -n "$m""m"
              test $s -gt 0 && echo -n "$s""s"
              echo -n "$ms""ms | "
            end
            echo -n (date +"%F%%%T")

            tput rc

            # Can place other info in the second line right prompt :)
            set_color normal
          '';
        };
      };

      shellInitLast = ''
        # Fish style
        set -g __fish_git_prompt_showdirtystate yes
        set -g __fish_git_prompt_showstashstate yes
        set -g __fish_git_prompt_showuntrackedfiles yes
        set -g __fish_git_prompt_showupstream informative
        set -g __fish_git_prompt_describe_style default

        # Z
        zoxide init fish | source

        # fzf
        set -g fzf_directory_opts --bind "alt-k:clear-query"
        bind --mode default ';' '_fzf_switch_common ";"' # e.g. f;, h;, ...
        bind --mode default ':' '_fzf_switch_common ":"' # accept previous token as argument

        # Remove flashing colors, https://linux.overshoot.tv/wiki/ls
        set -gx LS_COLORS (string replace -a '05;' "" "$LS_COLORS")

        # My Local:
        fish_add_path "$HOME/.local/bin"
      '';

      shellAbbrs = {
        hi = "hx .";
        ra = "rg --hidden --no-ignore";
        ff = "fd --type f .";
        up = "upto";
        ze = "zoxide query";
      };
    };

    # TODO: New file:
    git = {
      enable = true;
      userName = "Zigit Zo";
      userEmail = "ptr@ffi.fyi";
    };
  };
}
