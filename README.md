# vimtips

An oh-my-zsh plugin that shows a vim tip matched to your skill level every time
you open a new shell, plus a `vimtips` command with subcommands to set that
skill level and control how often a tip shows up at all.

Everything runs with zsh builtins only (`printf`, `read`, `$(<file)`, etc.) —
no external processes are spawned, so it adds no noticeable delay to shell
startup.

## Install

1. Copy this directory into your oh-my-zsh custom plugins folder:

   ```sh
   cp -r vimtips "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/vimtips"
   ```

2. Add `vimtips` to the `plugins=(...)` list in `~/.zshrc`:

   ```sh
   plugins=(... vimtips)
   ```

3. Reload your shell:

   ```sh
   source ~/.zshrc
   ```

## Usage

Every command runs through `vimtips <subcommand>`. Running `vimtips` alone
(no subcommand) prints usage and exits 1; `vimtips help` prints the same
usage but exits 0.

Set your skill level directly:

```sh
vimtips level beginner
vimtips level intermediate
vimtips level expert
```

Or run `vimtips level` with no argument to be prompted for one. The level is
stored in `~/.vimtips`.  Whenever you're ready for the next level, you can upgrade!

If `~/.vimtips` doesn't exist yet (e.g. right after installing), the plugin
defaults to `beginner`, prints a one-line hint to run `vimtips level`, and
writes that default so the hint only shows once.

Set how often a tip shows up with `vimtips frequency`, a number from 0
(never) to 1 (always):

```sh
vimtips frequency .5
```

Or run `vimtips frequency` with no argument to be prompted for one — .1, .5,
and 1 are suggested, but any value in that range works. It's stored in
`~/.vimtips_frequency` and defaults to 1 (always) if unset.

On every new interactive shell, a random tip from the matching
`vim_<level>.txt` file is printed (subject to the frequency check above). It
avoids repeating any of the last 10 tips shown (tracked in
`~/.vimtips_history`), so runs at the same level stay varied.

## Files

- `vimtips.plugin.zsh` — the `vimtips` command (with its `level`,
  `frequency`, and `help` subcommands) and the startup tip display.
- `vim_beginner.txt`, `vim_intermediate.txt`, `vim_expert.txt` — 100 tips
  each, one per line.
