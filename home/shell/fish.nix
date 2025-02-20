# <- Flake inputs

# Making the Fish shell.
# No arguments. <- Module arguments

{ pkgs, ... }: # <- Home Manager `imports = []`

let
  plugin = pkg: { inherit (pkg) name src; };
in
{
  programs = {
    fish = {
      enable = true;

      plugins = with pkgs.fishPlugins; [
        (plugin fzf-fish)
        (plugin tide)
        (plugin puffer)
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
      ];

      functions = {
        _fzf_search_ripgrep = {
          body = ''
            # Copy from '_fzf_search_directory':

            set -f token (commandline --current-token)
            set -f expanded_token (eval echo -- $token)
            set -f unescaped_exp_token (string unescape -- $expanded_token)
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
      };

      shellInitLast = ''
        # what `tide configure` shows:
        tide configure \
          --auto \
          --style=Lean \
          --prompt_colors='True color' \
          --show_time='24-hour format' \
          --lean_prompt_height='Two lines' \
          --prompt_connection=Disconnected \
          --prompt_spacing=Sparse \
          --icons='Few icons' \
          --transient=Yes

        # fzf
        set -g fzf_directory_opts --bind "alt-k:clear-query"
        bind --mode default ';' '_fzf_switch_common ";"' # e.g. f;, h;, ...
        bind --mode default ':' '_fzf_switch_common ":"' # accept previous token as argument

        # https://github.com/kpbaks/autols.fish/issues/3
        ls

        # https://linux.overshoot.tv/wiki/ls
        set -gx LS_COLORS (string replace -a '05;' "" "$LS_COLORS")

        # FIXME: (no) local:
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

    # deps:
    zoxide.enable = true;
    fzf.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
