# vimtips

An [Oh My Zsh](https://ohmyz.sh) plugin that prints a vim tip matched to your
skill level every time you open a new interactive shell — and a `vimtips`
command to tune the level and how often tips appear.

```
Vim tip [beginner]: Press i to enter Insert mode before the cursor.
```

The plugin uses zsh builtins exclusively (`printf`, `read`, `$(<file)`,
arithmetic expansion). It forks no external processes, so it adds no
measurable delay to shell startup.

## Install

Clone the repository into your Oh My Zsh custom plugins directory:

```sh
git clone https://github.com/karldreher/omz-vimtips.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/omz-vimtips"
```

Add `omz-vimtips` to the plugin list in `~/.zshrc`:

```sh
plugins=(... omz-vimtips)
```

The plugin is named `omz-vimtips`; the command it provides is `vimtips`.

Then reload your shell:

```sh
source ~/.zshrc
```

## Commands

| Command | Description |
| --- | --- |
| `vimtips level [beginner\|intermediate\|expert]` | Set your skill level. Prompts if the level is omitted. |
| `vimtips frequency [0-1]` | Set how often a tip appears. Prompts if the value is omitted. |
| `vimtips help` | Show usage. |

Running `vimtips` with no subcommand prints the same usage but exits `1`, since
that is a usage error; `vimtips help` exits `0`.

```sh
vimtips level expert     # switch levels whenever you are ready to move up
vimtips frequency .5     # a tip on roughly half of new shells
```

Any value between `0` and `1` is accepted for `frequency` — `0` never shows a
tip, `1` always does, and `.1`/`.5`/`1` are merely the suggested starting
points.

## Configuration

State lives in three plain-text files in `$HOME`. You normally never edit these
by hand; the `vimtips` subcommands write them for you.

| File | Purpose | Default |
| --- | --- | --- |
| `~/.vimtips` | Skill level: `beginner`, `intermediate`, or `expert` | `beginner` |
| `~/.vimtips_frequency` | Probability a tip is shown, `0`–`1` | `1` (always) |
| `~/.vimtips_history` | The last 10 tips shown, tagged with the level they were shown for | — |

If `~/.vimtips` or `~/.vimtips_frequency` is missing or holds an unrecognized
value, the plugin falls back to the default above, prints a one-line hint naming
the command that changes it, and writes the default out — so the hint appears
only once.

## How tips are chosen

On each new interactive shell:

1. **Frequency roll.** A uniform random draw in `[0, 1)` is compared against
   your configured frequency. If it does not pass, nothing is printed and no
   files are touched.
2. **Pick a tip.** A random line is chosen from `vim_<level>.txt`, excluding any
   of the last 10 tips recorded in `~/.vimtips_history`, so consecutive shells
   at the same level stay varied. If every tip has been shown recently, the full
   list is used again.
3. **Record it.** The chosen tip is prepended to the history file, which is
   trimmed back to 10 entries.

History is tagged with the level it was recorded under. Switching levels
discards it, because it filters a different pool of tips.

## Repository layout

| Path | Contents |
| --- | --- |
| `omz-vimtips.plugin.zsh` | The `vimtips` command and the startup tip display |
| `vim_beginner.txt` | 100 beginner tips, one per line |
| `vim_intermediate.txt` | 100 intermediate tips, one per line |
| `vim_expert.txt` | 100 expert tips, one per line |
