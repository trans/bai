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
    crystal run src/main.cr -- {{args}}

install: build
    install -d {{bindir}}
    install -m 0755 bin/bai {{bindir}}/bai
    @echo "installed: {{bindir}}/bai"

uninstall:
    rm -f {{bindir}}/bai
    @echo "removed: {{bindir}}/bai"

clean:
    rm -rf bin lib .crystal

fmt:
    crystal tool format

check:
    crystal tool format --check
    crystal spec
