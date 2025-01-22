{ ... }: # <- Flake inputs

# Making the Helix editor.
# No arguments. <- Module arguments

{ pkgs, ... }: # <- Nix `imports = []`

{
  home.packages = with pkgs; [
    nixd
    nixfmt-rfc-style
    clang-tools
    bash-language-server
    shellcheck
  ];

  programs.helix = {
    enable = true;
    defaultEditor = true;

    settings = {
      # Look and feel:
      theme = "papercolor-dark";
      editor = {
        line-number = "relative";
        true-color = true;
        rulers = [
          80
          120
        ];
        auto-format = false;
        color-modes = true;
        cursor-shape = {
          insert = "bar";
        };
        file-picker = {
          hidden = true;
          git-ignore = true;
        };
      };

      # Keys
      keys = {
        normal = {
          G = "goto_last_line"; # or ge
          H = "goto_previous_buffer"; # or gp
          L = "goto_next_buffer"; # or gn
          A-j = [
            "extend_to_line_bounds"
            "delete_selection"
            "paste_after"
          ];
          A-k = [
            "extend_to_line_bounds"
            "delete_selection"
            "move_line_up"
            "paste_before"
          ];
          A-J = [
            "extend_to_line_bounds"
            "yank"
            "paste_after"
          ];
          A-K = [
            "extend_to_line_bounds"
            "yank"
            "paste_before"
          ];
          ";" = "goto_word_definition";
          A-1 = ":focus 1";
          A-2 = ":focus 2";
          A-3 = ":focus 3";
          A-4 = ":focus 4";
          A-5 = ":focus 5";
          A-6 = ":focus 6";
          A-7 = ":focus 7";
          A-8 = ":focus 8";
          A-9 = ":focus 9";
        };

        normal.space = {
          F = "file_picker_in_current_buffer_directory";
        };

        normal.g = {
          R = [
            "goto_prev_function_name"
            "goto_reference"
          ];
          ";" = "goto_word_reference";
        };

        normal."'" = {
          s = ":toggle search.smart-case";
          r = ":toggle search.regex";
          c = ":toggle search.case-sensitive";
          w = ":toggle search.whole-word";
          h = [
            ":toggle file-picker.hidden"
            ":toggle file-picker.git-ignore"
          ];
          a = ":toggle soft-wrap.enable";
          p = ":toggle auto-pairs";
          f = ":toggle auto-format";
          t = ":toggle smart-tab.enable";
          # will reset all configs to config-default
          "'" = ":config-reload";
          m = ":format-write";
        };

        normal."," = {
          "," = "collapse_selection";
          ";" = "flip_selections";
          "." = "keep_primary_selection";
          "/" = "remove_primary_selection";
        };

        insert = {
          "S-tab" = "insert_raw_tab";
          # Emacs navigator
          C-p = "move_line_up";
          C-n = "move_line_down";
          C-b = "move_char_left";
          C-f = "move_char_right";
          A-b = "move_prev_word_start";
          A-f = "move_next_word_end";
          C-a = "goto_line_start";
          C-e = "goto_line_end_newline";
          # Quick commands
          "A-;" = "command_mode";
          A-x = "command_palette";
          A-1 = ":focus_insert 1";
          A-2 = ":focus_insert 2";
          A-3 = ":focus_insert 3";
          A-4 = ":focus_insert 4";
          A-5 = ":focus_insert 5";
          A-6 = ":focus_insert 6";
          A-7 = ":focus_insert 7";
          A-8 = ":focus_insert 8";
          A-9 = ":focus_insert 9";
        };
      };
    };

    languages.language = [
      {
        name = "nix";
        formatter = {
          command = "nixfmt";
        };
      }
    ];
  };
}
