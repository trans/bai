# sai

A tiny CLI that translates a natural-language request into a shell command.
You stay the approval gate — `sai` only proposes; the shell runs.

```
$ sai list files in cwd sorted by date
ls -lt
```

The command is printed to stdout *and* copied to your clipboard (configurable),
so you can paste, edit, or run it however you like. Or wire up the
[Alt-Enter keybinding](#shell-integration-alt-enter) to have `sai` rewrite
your prompt buffer in place.

## Installation

Requires [Crystal](https://crystal-lang.org/) and [just](https://just.systems/).

```sh
git clone https://github.com/trans/sai
cd sai
just install                 # → /usr/local/bin/sai
PREFIX=~/.local just install # → ~/.local/bin/sai
```

Then export your Anthropic API key:

```sh
export ANTHROPIC_API_KEY=sk-ant-...
```

## Usage

```sh
sai <natural language query>
```

Examples:

```sh
sai count lines of Crystal code in src
sai find files modified in the last day
sai rename all jpg files in this folder to lowercase
sai show the largest 10 files under home
```

`sai` prints the proposed command (no trailing newline, so the clipboard
content is ready to paste cleanly) and exits.

### Flags

| Flag             | Effect                                                                      |
| ---------------- | --------------------------------------------------------------------------- |
| `-n, --dry-run`  | Print the model + full prompt that *would* be sent, then exit. No API call. |
| `--copy`         | Force clipboard copy on (overrides `SAI_CLIPBOARD`).                        |
| `--no-copy`      | Force clipboard copy off.                                                   |
| `-h, --help`     | Show help.                                                                  |
| `-v, --version`  | Show version.                                                               |

### Environment variables

| Variable             | Purpose                                                                |
| -------------------- | ---------------------------------------------------------------------- |
| `ANTHROPIC_API_KEY`  | Required.                                                              |
| `SAI_MODEL`          | Override the default model (`claude-haiku-4-5-20251001`).              |
| `SAI_CLIPBOARD`      | Set to `0`/`off`/`false`/`no` to disable clipboard copy by default.    |
| `SAI_PROMPT_FILE`    | Override the prompt addendum path (default: `~/.config/sai/prompt.md`).|

## Shell integration (Alt-Enter)

The keybinding lets you type a natural-language query straight at your prompt,
hit Alt-Enter, and have it rewritten as the shell command — ready to edit
or run.

**fish** — `~/.config/fish/config.fish`:

```fish
function sai-replace
    set -l query (commandline)
    test -z "$query"; and return
    set -l result (sai -- $query)
    commandline -r -- $result
end
function fish_user_key_bindings
    bind \e\r sai-replace
end
```

**bash** — `~/.bashrc`:

```bash
_sai_replace() {
    [[ -z "$READLINE_LINE" ]] && return
    READLINE_LINE="$(sai -- "$READLINE_LINE")"
    READLINE_POINT=${#READLINE_LINE}
}
bind -x '"\e\r": _sai_replace'
```

**zsh** — `~/.zshrc`:

```zsh
_sai_replace() {
    [[ -z "$BUFFER" ]] && return
    BUFFER="$(sai -- "$BUFFER")"
    CURSOR=${#BUFFER}
}
zle -N _sai_replace
bindkey '^[^M' _sai_replace
```

If Alt-Enter is already taken by your terminal or another binding, change
the key sequence to taste (`\cg`, `\e;`, `^[^M`, etc.).

## Context sent to the model

Every call includes lightweight environment context so suggestions match
your system:

```
OS: CachyOS
Kernel: 6.19.12-1-cachyos
Arch: x86_64
Shell: fish
CWD: /home/you/Projects/foo
HOME: /home/you
Editor: nvim
```

Inspect exactly what gets sent with `sai --dry-run <query>`.

## Prompt addendum

Drop a file at `~/.config/sai/prompt.md` (or anywhere, pointed to by
`SAI_PROMPT_FILE`) to append your own preferences to the system prompt.
Content is sent verbatim — what you write is what the model sees.

Example:

```
Prefer eza over ls, fd over find, rg over grep, bat over cat.
On this machine, pacman is the package manager.
Avoid sudo unless the request clearly requires it.
```

`sai --dry-run` will show your addendum in the rendered system prompt so
you can verify it's loading.

## Development

```sh
just build       # release binary at bin/sai
just build-debug # debug build
just run -- <query>
just test
just fmt
just check       # fmt --check + spec
just clean
```

## License

MIT — see [LICENSE](LICENSE).
