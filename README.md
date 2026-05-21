# bai

A tiny CLI that translates a natural-language request into a shell command.
You stay the approval gate — `bai` only proposes; the shell runs.

```
$ bai list files in cwd sorted by date
ls -lt
```

The command is printed to stdout *and* copied to your clipboard (configurable),
so you can paste, edit, or run it however you like. Or wire up the
[Alt-Enter keybinding](#shell-integration-alt-enter) to have `bai` rewrite
your prompt buffer in place.

## Installation

Requires [Crystal](https://crystal-lang.org/) and [just](https://just.systems/).

```sh
git clone https://github.com/trans/bai
cd bai
just install                 # → /usr/local/bin/bai
PREFIX=~/.local just install # → ~/.local/bin/bai
```

Then either export your Anthropic API key:

```sh
export ANTHROPIC_API_KEY=sk-ant-...
```

Or drop it into your config directory:

```sh
mkdir -p ~/.config/bai
printf '%s\n' 'sk-ant-...' > ~/.config/bai/anthropic_api_key
```

## Usage

```sh
bai <natural language query>
```

Examples:

```sh
bai count lines of Crystal code in src
bai find files modified in the last day
bai rename all jpg files in this folder to lowercase
bai show the largest 10 files under home
```

`bai` prints the proposed command (no trailing newline, so the clipboard
content is ready to paste cleanly) and exits.

### Flags

| Flag             | Effect                                                                      |
| ---------------- | --------------------------------------------------------------------------- |
| `-n, --dry-run`  | Print the model + full prompt that *would* be sent, then exit. No API call. |
| `--copy`         | Force clipboard copy on (overrides `BAI_CLIPBOARD`).                        |
| `--no-copy`      | Force clipboard copy off.                                                   |
| `-h, --help`     | Show help.                                                                  |
| `-v, --version`  | Show version.                                                               |

### Environment variables

| Variable             | Purpose                                                                |
| -------------------- | ---------------------------------------------------------------------- |
| `BAI_PROVIDER`       | Select provider: `anthropic` or `openai` (default: `anthropic`).       |
| `ANTHROPIC_API_KEY`  | Required when `BAI_PROVIDER=anthropic`.                                |
| `OPENAI_API_KEY`     | Required when `BAI_PROVIDER=openai`.                                   |
| `BAI_ANTHROPIC_MODEL`| Preferred Anthropic model override (`claude-haiku-4-5-20251001`).      |
| `BAI_MODEL`          | Legacy alias for `BAI_ANTHROPIC_MODEL`.                                |
| `BAI_OPENAI_MODEL`   | OpenAI model override (default: `gpt-5-mini`).                         |
| `BAI_CLIPBOARD`      | Set to `0`/`off`/`false`/`no` to disable clipboard copy by default.    |
| `BAI_PROMPT_FILE`    | Override the prompt addendum path (default: `~/.config/bai/prompt.md`).|

Environment variables override matching files in `~/.config/bai/`
(or `$XDG_CONFIG_HOME/bai/`, or `$BAI_CONFIG_DIR/` if you set that).
For example:

```text
~/.config/bai/provider
~/.config/bai/anthropic_api_key
~/.config/bai/openai_api_key
~/.config/bai/anthropic_model
~/.config/bai/openai_model
~/.config/bai/clipboard
~/.config/bai/prompt_file
~/.config/bai/prompt.md
```

The mapping rule is simple: lowercase the env var name and drop the `bai_`
prefix when present. So `BAI_PROVIDER` becomes `provider`, and
`ANTHROPIC_API_KEY` becomes `anthropic_api_key`.

`prompt.md` is the one special case: it is the actual prompt-addendum content
file, not a string setting. By contrast, `prompt_file` contains a path if you
want the addendum to live somewhere else.

## Shell integration (Alt-Enter)

The keybinding lets you type a natural-language query straight at your prompt,
hit Alt-Enter, and have it rewritten as the shell command — ready to edit
or run.

**fish** — `~/.config/fish/config.fish`:

```fish
function bai-replace
    set -l query (commandline)
    test -z "$query"; and return
    set -l result (bai -- $query)
    commandline -r -- $result
end
function fish_user_key_bindings
    bind \e\r bai-replace
end
```

**bash** — `~/.bashrc`:

```bash
_bai_replace() {
    [[ -z "$READLINE_LINE" ]] && return
    READLINE_LINE="$(bai -- "$READLINE_LINE")"
    READLINE_POINT=${#READLINE_LINE}
}
bind -x '"\e\r": _bai_replace'
```

**zsh** — `~/.zshrc`:

```zsh
_bai_replace() {
    [[ -z "$BUFFER" ]] && return
    BUFFER="$(bai -- "$BUFFER")"
    CURSOR=${#BUFFER}
}
zle -N _bai_replace
bindkey '^[^M' _bai_replace
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

Inspect exactly what gets sent with `bai --dry-run <query>`.

## Prompt addendum

Drop a file at `~/.config/bai/prompt.md` (or anywhere, pointed to by
`BAI_PROMPT_FILE`) to append your own preferences to the system prompt.
Content is sent verbatim — what you write is what the model sees.

Example:

```
Prefer eza over ls, fd over find, rg over grep, bat over cat.
On this machine, pacman is the package manager.
Avoid sudo unless the request clearly requires it.
```

`bai --dry-run` will show your addendum in the rendered system prompt so
you can verify it's loading.

## Development

```sh
just build       # release binary at bin/bai
just build-debug # debug build
just docs-api    # generate HTML API docs at docs/api
just pkg-src     # snapshot tracked files into pkg/bai-<version>.tar.gz
just pkg-arch    # build an Arch package in pkg/
just pkg-deb     # build Debian package artifacts in pkg/
just release-check # run spec + package checks before tagging a release
just run -- <query>
just test
just fmt
just check       # fmt --check + spec
just clean
```

## License

MIT — see [LICENSE](LICENSE).
