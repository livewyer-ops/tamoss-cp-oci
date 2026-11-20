# Contributing

Use the [workstation setup](docs/getting-started.md#prepare-the-workstation) and install Docker Compose for the test fixtures.

- Run [local checks](docs/testing.md#local-checks) before opening a pull request.
- For changes to deployment tasks, charts or compositions, run `mise run check:management` on a quiet host with `sshd` available. It includes the local checks.
- For changes that need OCI to verify, use a dedicated deployment and review the [effects of qualification](docs/testing.md#deployed-qualification).

Keep credentials, kubeconfigs and deployment records outside Git. Use Conventional Commit subjects and document changes to commands or compatibility in the [changelog](CHANGELOG.md). For upstream version changes, follow [release selection](deploy/tamoss/README.md#release-selection).
