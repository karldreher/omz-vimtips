# omz-vimtips

An [Oh My Zsh](https://ohmyz.sh) plugin that prints a vim tip matched to your
skill level every time you open a new interactive shell — and a `vimtips`
command to tune the level and how often tips appear.

```
Vim tip [beginner]: Press i to enter Insert mode before the cursor.
```

It adds no measurable delay to shell startup — everything is written in zsh
builtins, so no external process is ever spawned. Tips appear in interactive
shells only, so scripts, CI jobs and `ssh host command` stay clean.

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

Then reload your shell:

```sh
source ~/.zshrc
```

## Commands

The plugin is named `omz-vimtips`, but the command it gives you is `vimtips`:

| Command | Description |
| --- | --- |
| `vimtips level [beginner\|intermediate\|expert]` | Choose which pool of tips to draw from |
| `vimtips frequency [0-1]` | Choose how often a tip appears |
| `vimtips help` | Show usage |

```sh
vimtips level expert     # switch levels whenever you are ready to move up
vimtips frequency .5     # a tip on roughly half of new shells
```

Frequency is a fraction: `1` shows a tip on every new shell, `0` turns tips
off entirely, and anything between shows one that share of the time. Any value
in the range works, not just the round ones.

Run either command with no argument to be prompted instead.

## Configuration

State lives in three plain-text files in `$HOME`. You normally never edit these
by hand; the `vimtips` subcommands write them for you.

| File | Purpose | Default |
| --- | --- | --- |
| `~/.vimtips` | Skill level: `beginner`, `intermediate`, or `expert` | `beginner` |
| `~/.vimtips_frequency` | How often a tip is shown, `0`–`1` | `1` (always) |
| `~/.vimtips_history` | The last 10 tips shown, tagged with the level they were shown for | — |

If `~/.vimtips` or `~/.vimtips_frequency` is missing or holds an unrecognized
value, the plugin falls back to the default above, prints a one-line hint naming
the command that changes it, and writes the default out — so the hint appears
only once.

## How tips are chosen

On each new interactive shell:

1. **Roll against your frequency.** If the roll fails, nothing is printed and
   no files are touched.
2. **Pick a tip.** A random line from `vim_<level>.txt`, skipping the last 10
   tips recorded in `~/.vimtips_history` so consecutive shells stay varied. If
   every tip has been shown recently, the full list becomes eligible again.
3. **Record it.** The tip is added to the history file, which keeps only the
   10 most recent.

History is tagged with the level it was recorded under. Switching levels
discards it, because it filters a different pool of tips.

## Repository layout

| Path | Contents |
| --- | --- |
| `omz-vimtips.plugin.zsh` | The `vimtips` command and the startup tip display |
| `vim_beginner.txt` | 100 beginner tips, one per line |
| `vim_intermediate.txt` | 100 intermediate tips, one per line |
| `vim_expert.txt` | 100 expert tips, one per line |
