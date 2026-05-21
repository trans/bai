prefix := env_var_or_default("PREFIX", "/usr/local")
bindir := prefix / "bin"

default:
    @just --list

build:
    shards build --release

build-debug:
    shards build

test:
    crystal spec

run *args:
    crystal run src/sai.cr -- {{args}}

install: build
    install -d {{bindir}}
    install -m 0755 bin/sai {{bindir}}/sai
    @echo "installed: {{bindir}}/sai"

uninstall:
    rm -f {{bindir}}/sai
    @echo "removed: {{bindir}}/sai"

clean:
    rm -rf bin lib .crystal

fmt:
    crystal tool format

check:
    crystal tool format --check
    crystal spec
