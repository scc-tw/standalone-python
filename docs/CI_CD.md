# CI/CD

The project has two parallel pipelines: GitHub Actions (public releases) and GitLab CI (mirror / internal). Both build the same 6-variant matrix and ship identical artefacts.

## Contents
- [Matrix](#matrix)
- [GitHub Actions](#github-actions)
- [GitLab CI](#gitlab-ci)
- [The release-tar script](#the-release-tar-script)
- [Smoke tests](#smoke-tests)
- [Release flow](#release-flow)
- [Secrets](#secrets)

## Matrix

```
version       = {3.10, 3.11, 3.12}
architecture  = {x86_64, x86}
```

Six jobs per pipeline run, fully parallel.

Each job is self-contained: it builds its Dockerfile from repo root, runs smoke tests inside the final image, extracts `opt/python/`, gzips it, and uploads.

## GitHub Actions

File: `.github/workflows/build.yml`. Triggers on pushes to `release`.

Build step (authoritative source is the workflow file — this is a description):

```yaml
matrix:
  architecture: [x86_64, x86]
  version:     ["3.12", "3.11", "3.10"]

steps:
  - uses: actions/checkout@v4

  - name: Build docker image
    run: |
      docker build \
        -f ./${{ matrix.version }}/${{ matrix.architecture }}/Dockerfile \
        -t release-${{ github.ref_name }}:${{ matrix.version }}-${{ matrix.architecture }} \
        .

  - name: Smoke test python and pip in final image
    run: |
      docker run --rm release-${{ github.ref_name }}:${{ matrix.version }}-${{ matrix.architecture }} \
        /opt/python/bin/python3 -c 'import ssl, sqlite3, ctypes, lzma; print("ok")'
      docker run --rm release-${{ github.ref_name }}:${{ matrix.version }}-${{ matrix.architecture }} \
        /opt/python/bin/pip3 --version

  - name: Save docker image as tar file
    run: |
      docker save release-${{ github.ref_name }}:${{ matrix.version }}-${{ matrix.architecture }} \
        > release-${{ matrix.version }}-${{ matrix.architecture }}.tar

  - name: Extract /opt/python/ into a tarball
    run: ./ci/packing_release_tar.sh release-${{ matrix.version }}-${{ matrix.architecture }}.tar

  - name: Gzip
    run: sudo apt-get install -y gzip && gzip -9 build/release-${{ matrix.version }}-${{ matrix.architecture }}.tar

  - uses: actions/upload-artifact@v4
    with:
      name: release-${{ matrix.version }}-${{ matrix.architecture }}.tar.gz
      path: build/release-${{ matrix.version }}-${{ matrix.architecture }}.tar.gz
```

A follow-up `release` job collects all six artefacts, tags the repo with `release-YYYY-MM-DD`, pushes the tag, and creates a GitHub Release via `ncipollo/release-action`.

## GitLab CI

File: `.gitlab-ci.yml`. Stages: `build → generate_release_tag → upload → generate_release_note → release`.

Build stage (parallel matrix, `shell` runner):

```yaml
build:
  stage: build
  parallel:
    matrix:
      - version: ["3.12", "3.11", "3.10"]
        architecture: [x86_64, x86]
  script:
    - docker build -f ./${version}/${architecture}/Dockerfile
        -t release-${PACKAGE_NAME}:${version}-${architecture} .
        1>${version}-${architecture}.log 2>&1
    - docker run --rm release-${PACKAGE_NAME}:${version}-${architecture}
        /opt/python/bin/python3 -c 'import ssl, sqlite3, ctypes, lzma; print("ok")'
    - docker run --rm release-${PACKAGE_NAME}:${version}-${architecture}
        /opt/python/bin/pip3 --version
    - docker save release-${PACKAGE_NAME}:${version}-${architecture}
        > release-${version}-${architecture}.tar
    - bash ci/packing_release_tar.sh release-${version}-${architecture}.tar
    - gzip -9 build/release-${version}-${architecture}.tar
```

Subsequent stages:

1. `generate_release_tag` — `release-$(date +%Y-%m-%d)` tag pushed back.
2. `upload` — `curl` each tarball to the project's generic package registry.
3. `generate_release_note` — assembles a markdown list of download links from the registry responses.
4. `release` — `release-cli create` with the collected notes.

Runs gated by `$CI_COMMIT_TAG == null` so tag pushes don't loop.

## The release-tar script

`ci/packing_release_tar.sh <image.tar>`:

1. `tar -xf image.tar` into a temp dir — this gives you the docker image's layer tarballs.
2. Walks each `layer.tar` inside, looking for one containing `opt/python/`.
3. Extracts just that subtree into `./build/` with the outer name matching the input (`release-3.12-x86_64.tar`).

Result: a clean tarball containing **only** the shipped Python tree, without any Debian base-image bloat.

## Smoke tests

Both pipelines run these against the built image **before** saving / packaging, so a broken build fails loud instead of shipping:

```bash
docker run --rm <tag> /opt/python/bin/python3 \
    -c 'import ssl, sqlite3, ctypes, lzma; print("ok")'

docker run --rm <tag> /opt/python/bin/pip3 --version
```

These catch the most common failure modes:

- `ssl` — OpenSSL linked correctly, no missing `libssl.so.X`.
- `sqlite3` — `libsqlite3.so.0` loadable.
- `ctypes` — libffi loadable (most pybind11 / cffi modules rely on this).
- `lzma` — both liblzma and the `_lzma` extension built.
- `pip --version` — pip script runs, import machinery works, launcher dispatches correctly.

Consider adding more (e.g. `import readline, bz2`) if you hit a recurring regression.

## Release flow

### GitHub

```
push release → matrix build → per-variant artefacts → release job
  → git tag release-YYYY-MM-DD → GitHub Release with 6 attached tarballs
```

Tag format: `release-YYYY-MM-DD`. One release per day at most.

### GitLab

```
push → matrix build → package registry upload → release-cli
  → GitLab Release with 6 registry links in the description
```

## Secrets

### GitHub Actions

- `GITHUB_TOKEN` — automatic, used by `ncipollo/release-action` to create the release.

No other secrets required.

### GitLab CI

- `GIT_TOKEN` — a personal access token with `write_repository` scope, used to push the date tag back to the repo. Required, otherwise `generate_release_tag` fails.
- `CI_JOB_TOKEN` — automatic, used by the `upload` stage to PUT into the package registry.

Configure via **Settings → CI/CD → Variables** and mark them **masked + protected**.

## Troubleshooting CI

**Build fails at a specific dep stage (e.g. `build_zlib.sh`)** — upstream URL rot. Check the dep's download host is live; see [BUILD.md § Common gotchas](BUILD.md#common-gotchas).

**Smoke test fails `import ssl` but build succeeded** — OpenSSL was built but not linked correctly. Check `rpath-patcher.sh` output in the build log; look for `RPATH` lines on `python3.X-real`.

**Release-tar extraction produces an empty tree** — `ci/packing_release_tar.sh` didn't find `opt/python/` in any layer. Usually means `patch_stage` or `final` renamed something. Debug with `docker save | tar tv` on the image.

**`release-cli` or `actions/upload-artifact` 4xx/5xx** — credentials/permissions. Check token scope.
