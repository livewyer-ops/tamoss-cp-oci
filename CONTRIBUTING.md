# Contributing

[Overview](README.md) | [Testing](docs/testing.md) | [Architecture](docs/architecture.md)

Deploying needs only the [end-user steps](docs/getting-started.md). This page
covers changing the repository and testing those changes.

## Workstation

In addition to the [deployment prerequisites](docs/getting-started.md#1-prepare-the-workstation):

| Requirement | Used by |
| --- | --- |
| Docker Compose plugin | `check` database and TLS fixtures |
| `sshd` on the host and free port 22422 | `check:management` local Git fixture |
| Internet access | Pinned upstream releases, charts and images |

## Commands

| Command | Purpose | Needs |
| --- | --- | --- |
| `mise run check` | Validate releases, rendering, TLS and local contracts | Docker; no OCI credentials |
| `mise run check:management` | `check`, then controller reconciliation in disposable Kind clusters | Docker; no OCI credentials |
| `mise run check:storage` | Create and remove a real OCI bucket | A separately authorised compartment and spending allowance |
| `mise run check:storage:cleanup` | Finish an interrupted storage check | The same OCI identity |
| `mise run qualify` | Test ingest, access, network isolation and a worker drain on a running deployment | A dedicated deployment; changes its data |

`mise tasks` lists `setup`, `up`, `down`, the commands marked "Contributor" and
the two account commands marked "Administrator".
The storage checks are hidden from that list and run by name.

A GitHub workflow runs `mise run check` on pull requests and on `main`. Run
`check:management` on a quiet host before merging a change to tasks, charts or
compositions; do not run other checks beside it. [Testing](docs/testing.md)
describes the coverage of each command, the effects of `qualify` and the
[verified OCI coverage](docs/testing.md#verified-coverage-and-limits). TADOSS
has its own [qualification sequence](deploy/tadoss/README.md#verification-and-removal).

## Changes

Flux deploys the commit that is checked out and pushed, so commit and push
before a fresh deployment. Use [Conventional Commits](https://www.conventionalcommits.org/)
and mark breaking changes with `!`. Record command and compatibility changes in
the [changelog](CHANGELOG.md). Keep credentials and deployment directories out
of Git; `.local/` is private.

## Release selection

Deployment records the repository commit in `source.json`; `pins.yaml` at that
commit selects the upstream dependencies. Keep the matching source checkout for
operations and teardown. [TAMOSS integration](deploy/tamoss/README.md#release-selection)
and [TADOSS integration](deploy/tadoss/README.md) describe how to select another
upstream release. Upgrades of an existing deployment remain unqualified.
