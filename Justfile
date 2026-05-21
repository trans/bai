prefix := env_var_or_default("PREFIX", "/usr/local")
bindir := prefix / "bin"
version := `sed -n 's/^version: //p' shard.yml`

default:
    @just --list

build:
    shards build --release

build-debug:
    shards build

test:
    crystal spec

docs-api:
    crystal docs --project-name bai --project-version {{version}} --output docs/api

pkg-src:
    mkdir -p pkg
    git ls-files -z --cached --others --exclude-standard | tar --null -T - --transform "s,^,bai-{{version}}/," -czf "pkg/bai-{{version}}.tar.gz"

pkg-arch: pkg-src
    cd pkg && makepkg -f

pkg-deb:
    rm -rf "pkg/build/bai-{{version}}"
    mkdir -p "pkg/build/bai-{{version}}"
    git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - | tar -C "pkg/build/bai-{{version}}" -xf -
    cp -a "pkg/build/bai-{{version}}/pkg/debian" "pkg/build/bai-{{version}}/debian"
    cd "pkg/build/bai-{{version}}" && dpkg-buildpackage -us -uc -b
    mv pkg/build/*.deb pkg/build/*.buildinfo pkg/build/*.changes pkg/ 2>/dev/null || true

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
    rm -rf bin lib .crystal docs/api pkg/build pkg/pkg pkg/src pkg/*.tar.gz pkg/*.deb pkg/*.buildinfo pkg/*.changes pkg/*.dsc pkg/*.build

fmt:
    crystal tool format

check:
    crystal tool format --check
    crystal spec
