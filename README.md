# bai

*A small AI shell-command helper. The name comes from the Chinese `bai`,
associated with clarity and understanding.*

A tiny CLI that translates a natural-language request into a shell command.
You stay the approval gate — `bai` only proposes; the shell runs.

[Landing page](https://trans.github.io/bai/) · [API docs](https://trans.github.io/bai/api/index.html)

```
$ bai list files in cwd sorted by date
ls -lt
```

The command is printed to stdout *and* copied to your clipboard (configurable),
so you can paste, edit, or run it however you like. Or wire up the
[Alt-Enter keybinding](#shell-integration-alt-enter) to have `bai` rewrite
your prompt buffer in place.

## Installation

### Arch Linux

Download the `.pkg.tar.zst` asset from the latest GitHub release, then install:

```sh
sudo pacman -U ./bai-*.pkg.tar.zst
```

### Debian / Ubuntu

Download the `.deb` asset from the latest GitHub release, then install:

```sh
sudo dpkg -i ./bai_*.deb
```

If `dpkg` reports missing dependencies, finish with:

```sh
sudo apt-get install -f
```

### Fedora / RPM

Download the `.rpm` asset from the latest GitHub release, then install:

```sh
sudo dnf install ./bai-*.rpm
```

On openSUSE, local unsigned RPMs need an explicit allowance:

```sh
sudo zypper install --allow-unsigned-rpm ./bai-*.rpm
```

### macOS

Install from the tap:

```sh
brew tap trans/tap
brew install bai
```

Or build from source with Homebrew-provided Crystal and `just`:

```sh
brew install crystal just
git clone https://github.com/trans/bai
cd bai
just install
```

Clipboard copy uses the built-in `pbcopy` command on macOS.

### From Source

Requires [Crystal](https://crystal-lang.org/) and [just](https://just.systems/).

```sh
git clone https://github.com/trans/bai
cd bai
just install                 # → /usr/local/bin/bai
PREFIX=~/.local just install # → ~/.local/bin/bai
```

Then either export an API key:

```sh
export ANTHROPIC_API_KEY=sk-ant-...
# or:
export OPENAI_API_KEY=sk-...
```

Or drop it into your config directory:

```sh
mkdir -p ~/.config/bai
printf '%s\n' 'sk-ant-...' > ~/.config/bai/anthropic_api_key
```

For OpenAI-compatible local servers such as Ollama, set the provider, base URL,
and model explicitly:

```sh
export BAI_PROVIDER=local
export BAI_BASE_URL=http://localhost:11434/v1
export BAI_MODEL=qwen2.5-coder:7b
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
| `--explain`      | Print a brief explanation to stderr while keeping the command on stdout.    |
| `--json`         | Print machine-readable JSON to stdout.                                       |
| `--strict`       | Refuse ambiguous or unsafe requests instead of guessing.                    |
| `--show-config`  | Print effective config values (with secrets redacted), then exit.            |
| `--shell <name>` | Override detected shell context for command generation.                       |
| `--copy`         | Force clipboard copy on (overrides `BAI_CLIPBOARD`).                        |
| `--no-copy`      | Force clipboard copy off.                                                   |
| `-h, --help`     | Show help.                                                                  |
| `-v, --version`  | Show version.                                                               |

### Environment variables

| Variable            | Purpose                                                                 |
| ------------------- | ----------------------------------------------------------------------- |
| `BAI_PROVIDER`      | Select provider defaults: `anthropic`, `openai`, or `local`.            |
| `BAI_API_TYPE`      | Wire API override: `anthropic`, `openai_responses`, or `openai_chat`.   |
| `BAI_BASE_URL`      | API base URL; provider defaults are used when unset.                    |
| `BAI_API_KEY`       | API key override for the selected provider.                             |
| `BAI_MODEL`         | Model name for the selected provider/API.                               |
| `ANTHROPIC_API_KEY` | Fallback key when `BAI_PROVIDER=anthropic`.                             |
| `OPENAI_API_KEY`    | Fallback key when `BAI_PROVIDER=openai`.                                |
| `BAI_SHELL`         | Override detected shell context (`fish`, `bash`, `zsh`, `nu`, etc.).   |
| `BAI_CLIPBOARD`     | Set to `0`/`off`/`false`/`no` to disable clipboard copy by default.     |
| `BAI_PROMPT_FILE`   | Override the prompt addendum path (default: `~/.config/bai/prompt.md`). |

Provider defaults:

| Provider | Default API type    | Default base URL             | Default model                  |
| -------- | ------------------- | ---------------------------- | ------------------------------ |
| `anthropic` | `anthropic`      | `https://api.anthropic.com`  | `claude-haiku-4-5-20251001`    |
| `openai`    | `openai_responses` | `https://api.openai.com`   | `gpt-5-mini`                   |
| `local`     | `openai_chat`    | `http://localhost:11434`     | Requires `BAI_MODEL`           |

Environment variables override matching files in `~/.config/bai/`
(or `$XDG_CONFIG_HOME/bai/`, or `$BAI_CONFIG_DIR/` if you set that).
For example:

```text
~/.config/bai/provider
~/.config/bai/api_type
~/.config/bai/base_url
~/.config/bai/api_key
~/.config/bai/model
~/.config/bai/anthropic_api_key
~/.config/bai/openai_api_key
~/.config/bai/shell
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

Older provider-specific model/base settings such as `BAI_ANTHROPIC_MODEL`,
`BAI_OPENAI_MODEL`, `anthropic_model`, and `openai_model` are rejected with a
clear error. Use the generic `BAI_MODEL` / `model` and `BAI_BASE_URL` /
`base_url` settings instead.

### Local LLMs

`BAI_PROVIDER=local` uses an OpenAI-compatible Chat Completions endpoint. This
works with local servers that expose `/v1/chat/completions`, including Ollama's
OpenAI-compatible API.

```sh
export BAI_PROVIDER=local
export BAI_BASE_URL=http://localhost:11434/v1
export BAI_MODEL=qwen2.5-coder:7b

bai list files changed today
```

If your local server requires a bearer token, set `BAI_API_KEY`. Otherwise
`bai` sends a harmless placeholder key.

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

If parent-shell detection is wrong because you are calling `bai` from an editor,
launcher, or wrapper, force it explicitly:

```sh
bai --shell zsh list files modified today
```

Or set it persistently with `BAI_SHELL` / `~/.config/bai/shell`.

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

## Packaging

Local package build helpers:

```sh
just pkg-arch
just pkg-deb
just pkg-rpm
```

## Strict and explain modes

Use `--explain` when you want a short reason for the generated command without
breaking shell pipelines or command substitution:

```sh
bai --explain find large files
```

The command still goes to stdout. The explanation is printed to stderr.

Use `--strict` when you would rather have `bai` refuse an ambiguous request
than guess:

```sh
bai --strict find the latest logs
```

In strict mode, `bai` exits with an error if the model cannot infer a safe,
specific command confidently enough.

## JSON output

Use `--json` when you want machine-readable output for wrappers, editors, or
shell integration:

```sh
bai --json find large files
```

The JSON includes:

```json
{
  "command": "find . -type f",
  "explanation": "Searches recursively for regular files.",
  "provider": "anthropic",
  "shell": "zsh",
  "strict": false
}
```

If you combine `--json` with `--explain`, the explanation stays in the JSON
payload instead of being printed separately to stderr.

## Development

```sh
just build       # release binary at bin/bai
just build-debug # debug build
just docs-api    # generate HTML API docs at docs/api
just pkg-src     # snapshot tracked files into pkg/bai-<version>.tar.gz
just pkg-arch    # build an Arch package in pkg/
just pkg-deb     # build Debian package artifacts in pkg/
just pkg-rpm     # build Fedora/RPM package artifacts in pkg/
just sync-homebrew-tap # copy pkg/homebrew/bai.rb into ../homebrew-tap
just release-check # run spec + package checks before tagging a release
just run -- <query>
just test
just fmt
just check       # fmt --check + spec
just clean
```

## License

MIT — see [LICENSE](LICENSE).
