# ==============================================================================
# vimtips — prints a vim tip matched to your skill level on every interactive
# shell, and provides the `vimtips` command to configure that. See README.md
# for usage and for the files this reads and writes.
#
# Every line of this file runs on every shell startup, which drives three
# conventions worth knowing before editing it:
#
#   1. Builtins only — printf, read, $(<file), the (f) split flag, arithmetic
#      expansion — never cat/wc/shuf/bc. Each external command is a fork.
#
#   2. Helpers set globals instead of returning values. `result=$(helper)` is
#      also a fork: zsh spawns a subshell for every command substitution
#      except the special `$(<file)` file-read form. So each helper below
#      writes its result into a documented _vimtips_* scratch global.
#
#   3. No `bc` for the frequency maths. zsh's `(( ))` handles floats natively,
#      unlike bash's.
# ==============================================================================

# Directory this file lives in, so vim_<level>.txt can be found next to it.
# This MUST be set here, at the top level, and not inside a function: zsh
# resets $0 to the function's own name while a function is running
# (FUNCTION_ARGZERO is on by default), so ${0:A:h} only resolves to this
# file's directory while the file itself is being sourced.
typeset -g VIMTIPS_PLUGIN_DIR="${0:A:h}"

typeset -g VIMTIPS_LEVEL_FILE="$HOME/.vimtips"
typeset -g VIMTIPS_FREQUENCY_FILE="$HOME/.vimtips_frequency"
typeset -g VIMTIPS_HISTORY_FILE="$HOME/.vimtips_history"
typeset -gi VIMTIPS_HISTORY_SIZE=10

# Scratch globals the helpers below write into instead of `echo`-ing a
# result, so nothing here needs a subshell. Not meant to be read by anything
# outside this file.
typeset -g _vimtips_level
typeset -g _vimtips_frequency
typeset -ga _vimtips_recent
typeset -g _vimtips_chosen

# ------------------------------------------------------------------------------
# vimtips — public entry point, dispatching to the subcommands below. Running
# it with no subcommand (or an unrecognized one) prints help and exits 1;
# `vimtips help` prints the same help but exits 0, since that's a deliberate
# request rather than a usage error.
# ------------------------------------------------------------------------------
vimtips() {
  case "$1" in
    level) shift; _vimtips_cmd_level "$@" ;;
    frequency) shift; _vimtips_cmd_frequency "$@" ;;
    help) _vimtips_cmd_help ;;
    "")
      _vimtips_cmd_help
      return 1
      ;;
    *)
      printf 'vimtips: unknown subcommand: %s\n\n' "$1" >&2
      _vimtips_cmd_help >&2
      return 1
      ;;
  esac
}

_vimtips_cmd_help() {
  printf 'Usage: vimtips <subcommand> [args]\n\n'
  # %-48s left-pads each label to a fixed column so the descriptions line up
  # regardless of label length; printf cycles the two-conversion format
  # across the argument list, one label/description pair at a time.
  printf '  %-48s%s\n' \
    'vimtips level [beginner|intermediate|expert]' 'Set skill level (prompts if omitted)' \
    'vimtips frequency [0-1]' 'Set tip frequency (prompts if omitted)' \
    'vimtips help' 'Show this help'
}

# vimtips level [beginner|intermediate|expert]
#
# With no argument, prompts (re-prompting on invalid input) until a valid
# level is entered. With an argument, validates it directly and errors out
# on anything else. Either way, a valid level is written to
# $VIMTIPS_LEVEL_FILE.
_vimtips_cmd_level() {
  local level="$1"

  if [[ -z "$level" ]]; then
    while true; do
      printf 'Select vim skill level (beginner/intermediate/expert): '
      read level
      case "$level" in
        beginner|intermediate|expert) break ;;
        *) printf 'Invalid level: %s\n' "$level" ;;
      esac
    done
  else
    case "$level" in
      beginner|intermediate|expert) ;;
      *)
        printf 'Usage: vimtips level [beginner|intermediate|expert]\n' >&2
        return 1
        ;;
    esac
  fi

  printf '%s' "$level" > "$VIMTIPS_LEVEL_FILE"
  printf 'vim skill level set to %s\n' "$level"
}

# Checks that $1 is a plain decimal number in the range 0-1, inclusive at both
# ends. The pattern requires at least one digit after any decimal point, so
# ".5", "0.5" and "1" are accepted while "1." and "" are rejected. Used by both
# _vimtips_cmd_frequency and the startup loader.
_vimtips_valid_frequency() {
  local val="$1"
  [[ "$val" =~ ^[0-9]*\.?[0-9]+$ ]] || return 1
  (( val >= 0 && val <= 1 ))
}

# vimtips frequency [0-1]
#
# Sets how often the startup tip appears: 0 never shows one, 1 always shows
# one, and anything in between (e.g. 0.5) shows one that fraction of the
# time. With no argument, prompts (re-prompting on invalid input) until a
# valid number is entered; any value in range is accepted, not just the
# suggested ones. Either way, a valid value is written to
# $VIMTIPS_FREQUENCY_FILE.
_vimtips_cmd_frequency() {
  local freq="$1"

  if [[ -z "$freq" ]]; then
    while true; do
      printf 'Set tip frequency, 0-1, e.g. .1 .5 1 (0 = never, 1 = always): '
      read freq
      _vimtips_valid_frequency "$freq" && break
      printf 'Invalid frequency: %s\n' "$freq"
    done
  else
    if ! _vimtips_valid_frequency "$freq"; then
      printf 'Usage: vimtips frequency [0-1, e.g. .1 .5 1]\n' >&2
      return 1
    fi
  fi

  printf '%s' "$freq" > "$VIMTIPS_FREQUENCY_FILE"
  printf 'vim tip frequency set to %s\n' "$freq"
}

# ------------------------------------------------------------------------------
# Startup tip display, split into small single-purpose helpers rather than
# one large function so each piece (load level, load frequency, load
# history, pick a tip, save history) can be read and changed independently.
# ------------------------------------------------------------------------------

# Sets $_vimtips_level to the stored skill level. Falls back to "beginner"
# and persists that default — with a one-time hint printed to the user — if
# $VIMTIPS_LEVEL_FILE is missing or holds something unrecognized.
_vimtips_load_level() {
  _vimtips_level=""
  [[ -r "$VIMTIPS_LEVEL_FILE" ]] && _vimtips_level="$(<"$VIMTIPS_LEVEL_FILE")"

  case "$_vimtips_level" in
    beginner|intermediate|expert) return ;;
  esac

  _vimtips_level="beginner"
  printf 'vimtips: no skill level set, defaulting to beginner (run `vimtips level` to change it)\n'
  printf '%s' "$_vimtips_level" > "$VIMTIPS_LEVEL_FILE"
}

# Sets $_vimtips_frequency to the stored tip frequency. Falls back to "1"
# (always show a tip) and persists that default — with a one-time hint
# printed to the user — if $VIMTIPS_FREQUENCY_FILE is missing or holds
# something invalid.
_vimtips_load_frequency() {
  _vimtips_frequency=""
  [[ -r "$VIMTIPS_FREQUENCY_FILE" ]] && _vimtips_frequency="$(<"$VIMTIPS_FREQUENCY_FILE")"

  _vimtips_valid_frequency "$_vimtips_frequency" && return

  _vimtips_frequency=1
  printf 'vimtips: no tip frequency set, defaulting to 1/always (run `vimtips frequency` to change it)\n'
  printf '%s' "$_vimtips_frequency" > "$VIMTIPS_FREQUENCY_FILE"
}

# Sets $_vimtips_recent to the tips shown in roughly the last
# $VIMTIPS_HISTORY_SIZE runs, scoped to $1 (the current level). History
# recorded under a different level — i.e. the user just switched levels via
# vimtips level — is discarded, since it's filtering a different pool of tips.
_vimtips_load_history() {
  local level="$1"
  _vimtips_recent=()

  [[ -r "$VIMTIPS_HISTORY_FILE" ]] || return

  # (f) splits the file's contents on newlines, one array element per line.
  local -a lines
  lines=("${(f)"$(<"$VIMTIPS_HISTORY_FILE")"}")

  # Mind the two indexing conventions on the next line: zsh arrays are
  # 1-based, so lines[1] is the level tag written by _vimtips_save_history —
  # but slice offsets are 0-based, so [@]:1 drops that tag and keeps the tips.
  [[ "${lines[1]}" == "$level" ]] && _vimtips_recent=("${lines[@]:1}")
}

# Persists $_vimtips_recent (with $2 prepended, then trimmed to
# $VIMTIPS_HISTORY_SIZE entries) to $VIMTIPS_HISTORY_FILE, tagged with $1
# (the level) as the first line so _vimtips_load_history can validate it.
_vimtips_save_history() {
  local level="$1" tip="$2"

  _vimtips_recent=("$tip" "${_vimtips_recent[@]}")
  if (( ${#_vimtips_recent[@]} > VIMTIPS_HISTORY_SIZE )); then
    # 0-based slice again: start at the newest entry, keep that many.
    # The `$` on the length is required: zsh reads a bare letter after the
    # second `:` as a history modifier, not as an arithmetic expression.
    _vimtips_recent=("${_vimtips_recent[@]:0:$VIMTIPS_HISTORY_SIZE}")
  fi

  {
    printf '%s\n' "$level"
    printf '%s\n' "${_vimtips_recent[@]}"
  } > "$VIMTIPS_HISTORY_FILE"
}

# Picks a random tip out of the full tips list passed as arguments,
# excluding anything in $_vimtips_recent, and sets $_vimtips_chosen. Falls
# back to the full list if every tip has been shown recently — e.g. a tips
# file with fewer than $VIMTIPS_HISTORY_SIZE lines.
_vimtips_pick_tip() {
  local -a tips=("$@")

  # ${array[(Ie)needle]} is zsh's builtin exact-match index lookup: it
  # returns the 1-based index of an exact match, or 0 if there isn't one.
  # The recent-tips array is deliberately NOT named $history — zsh reserves
  # that name for its own command-history parameter, and shadowing it is
  # asking for trouble.
  local -a candidates
  local t
  for t in "${tips[@]}"; do
    (( ${_vimtips_recent[(Ie)$t]} )) || candidates+=("$t")
  done
  (( ${#candidates[@]} == 0 )) && candidates=("${tips[@]}")

  # RANDOM % n gives 0..n-1; the + 1 shifts that onto zsh's 1-based array
  # subscripts. It is not an off-by-one.
  local idx=$(( RANDOM % ${#candidates[@]} + 1 ))
  _vimtips_chosen="${candidates[idx]}"
}

# Entry point: load the level and frequency, roll the frequency dice, and —
# if it hits — load the tip file, pick and print one tip (honoring recent-tip
# history), then update that history for next time.
_vimtips_show() {
  [[ -o interactive ]] || return  # no-op when sourced non-interactively

  _vimtips_load_level
  local level="$_vimtips_level"

  _vimtips_load_frequency
  # RANDOM is 0-32767; dividing by the float literal 32768.0 forces zsh's
  # native floating-point arithmetic, giving a uniform draw in [0, 1). A
  # frequency of 0 can never beat it (never shows a tip); 1 always beats it
  # (always shows one).
  (( (RANDOM / 32768.0) < _vimtips_frequency )) || return

  local tipfile="$VIMTIPS_PLUGIN_DIR/vim_${level}.txt"
  [[ -r "$tipfile" ]] || return

  local -a tips
  tips=("${(f)"$(<"$tipfile")"}")
  (( ${#tips[@]} == 0 )) && return

  _vimtips_load_history "$level"

  _vimtips_pick_tip "${tips[@]}"
  # \033[1;36m = bold cyan, \033[0m = reset. Prints, e.g.:
  #   Vim tip [beginner]: Press i to enter Insert mode before the cursor.
  # with a blank line before and after, and only "Vim tip [beginner]:" colored.
  printf '\n\033[1;36mVim tip [%s]:\033[0m %s\n\n' "$level" "$_vimtips_chosen"

  _vimtips_save_history "$level" "$_vimtips_chosen"
}

_vimtips_show
