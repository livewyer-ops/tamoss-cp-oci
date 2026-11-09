# Deployment release artifacts

[Getting started](../../docs/getting-started.md) | [GitOps](../gitops/README.md) | [Operations](../../docs/operations.md)

CI packages the [deployment charts](charts.yaml) as Helm OCI artifacts and assembles
an OCI manifest bundle from the [allowlisted paths](paths.txt), unchanged
TAMOSS/TADOSS assets and pinned dependencies. `dependencies.yaml` selects the
bundle digest; its `release.yaml` records each chart's URL and digest.

`mise run up` downloads the selected bundle for the local seed. Flux in Kind and
OKE reads the public registry directly through digest-pinned `OCIRepository`
resources. HelmReleases reference the packaged charts through `chartRef`.
No deployment asset bucket, reader identity or registry credential is required.
Crossplane and External Secrets use their existing upstream Helm repositories.

## Release contents

The bundle contains both applications' assets, even when TADOSS is disabled, and
the matching TAMOSS source archive for qualification. `build.yaml` records
provenance, `SHA256SUMS` covers the files, and `release.yaml` records the manifest
hash and chart digests. `operator-source.tar.gz` preserves matching tooling.
Private working files, credentials and kubeconfigs are excluded.

Upstream sources remain read-only. CI packages copies of their charts and builds
local chart dependencies with Helm. All published chart packages must allow
anonymous pulls. CI verifies each chart by pulling its digest without credentials
and comparing the archive before publishing the manifest bundle.

## Selection and recovery

`assets.lock.yaml` records the bundle and chart digests, manifest hash and dependency
pins. Handover exports this ConfigMap beside the operational `values.yaml` in the
environment repository. Enabling TADOSS changes its existing value and needs no
new release publication.

Flux restores its source cache from the selected registry digests. Handover and
qualification download that bundle and verify its manifest before using it.
Keep published artifacts available for the deployment's lifetime and recovery.
To recover matching tooling, verify the selected bundle and extract
`operator-source.tar.gz` into an empty directory. This restores source files only;
it cannot restore a lost Kind cluster, deployment identity or credentials.

Fresh deployments require a bundle built with this chart-reference contract.
Existing bucket-based deployments must retain their original tooling and records
for teardown. There is no in-place migration. Release upgrades and database
migration rollback remain unqualified.
