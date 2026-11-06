# TAMOSS integration

[Overview](../../README.md) | [Architecture](../../docs/architecture.md) | [Operations](../../docs/operations.md)

TAMOSS is an external, read-only dependency. `release.yaml` selects an immutable
release record and matching source archive. `Taskfile.yaml` verifies and prepares
them using the repository's native tools. See the [public commands](../../README.md#commands)
and [testing guide](../../docs/testing.md).

| Owner | Assets |
| --- | --- |
| TAMOSS release | Operator manifest, compatibility metadata, dependency manifest and runtime catalogue |
| Matching TAMOSS source archive | Platform Helmfile and charts, multi-server instance base, browser tests and media fixture |
| This directory and `charts/gitops` | Operator/instance overlays, shared HA and OCI platform values, external database bootstrap chart, secret references, IngestRun and browser container configuration |
| Infrastructure configuration | Kind, Crossplane, OCI provisioning, observed runtime inputs, resource identities and cloud teardown |

Verified upstream files stay under `.local/tmp/tamoss/<release-record-sha256>/`.
Local overlays are rendered in separate private directories. The instance overlay
retains the `tamoss` resource name and `tams` namespace while inheriting the
upstream multi-server base. Required anti-affinity, external services and TLS
settings remain explicit because the selected upstream assets do not supply the
complete configuration required by this environment.

The release lock supplies `spec.version`; the operator selects application and
Job images and the schema revision from its published catalogue. External
database TLS uses `spec.backends.db.external.tls.caConfigMap`, shared by the API,
workers and database Jobs. `spec.publicEndpoint.tlsSecretName` selects the shared
API/UI certificate. These native settings replace per-workload patches.

These OKE workers require fully qualified image names. The local overlays specify Docker Hub
repositories for the operator and application workloads while retaining the
release's image digests. The PostgreSQL helper keeps the release's selected
version, and the database bootstrap keeps its pinned digest. Upstream manifests
and the runtime catalogue remain unchanged.

The database chart initialises the application roles and databases; TAMOSS owns
its schema migrations. The browser container runs unchanged upstream tests with
the upstream dependency lock. Its test selection and container recipe are
maintained here, and missing selected tests fail local checks.

## Release selection

The repository lock records the tag and checksums of the release record and
matching source archive. The verified release record supplies the source commit,
image digests and published asset checksums. To select another release, update
`release.yaml` from its published metadata, review compatibility and migration
requirements, then run `task check`. Upstream interface changes may require local
overlay or test-selection changes. Verified database TLS remains mandatory.

Initial deployment verifies the repository lock. Before or after handover, `qualify` verifies
the current environment Git selection, records it in `tamoss-release.yaml` and
retains the initial lock as `tamoss-release.bootstrap.yaml`. Repeat deployment
preserves Git-owned configuration. This bookkeeping alone does not qualify an
upgrade or establish that database migrations can be reversed.

Preserve the release records through teardown. `down` returns current Git/live
configuration to Kind for deletion.
See [Operations](../../docs/operations.md#release-selection) and the [GitOps guide](../gitops/README.md#release-changes)
for release selection, verification and lifecycle instructions.

## Private release bundle

`task check` also prepares an allowlisted OCI bundle under
`.local/tmp/tamoss-bundle`. It contains the unchanged published installation,
compatibility, catalogue and dependency assets, verified release metadata, the
release lock and a static Kustomize entrypoint. Flux builds a reproducible archive;
the source checkout and private working files are excluded.

The manually dispatched [publishing workflow](../../.github/workflows/release-bundle.yaml)
publishes from the default branch with `GITHUB_TOKEN`, checks private package
visibility and repository association, and records the resulting digest. Configure
the repository's `GHCR_READ_TOKEN` Actions secret with a classic PAT limited to
`read:packages`, owned by an account with access to the package. Only the metadata
checks receive this token; Docker publishing uses `GITHUB_TOKEN`. A missing read
token stops the workflow before release checks or publication. Deploy
using that digest recorded in `bundle` in the application's `release.yaml`.
The TAMOSS bundle excludes this publication reference from its embedded lock to
avoid a digest depending on itself. Private runtime pulls require a separate read-only package
credential supplied through Vault/ESO; GitHub App credentials are for Git access.
Private runtime pulls have passed live OCI checks. A supported release upgrade
and package-read credential rotation/revocation remain unqualified; see
[coverage limits](../../docs/testing.md#verified-coverage-and-limits).
