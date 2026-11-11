# TAMOSS integration

[Overview](../../README.md) | [Architecture](../../docs/architecture.md) | [Operations](../../docs/operations.md)

TAMOSS is an external, read-only dependency. `release.yaml` selects an immutable
release record and matching source archive. `tasks.toml` verifies and prepares
them using the repository's native tools. See the [contributor commands](../../CONTRIBUTING.md#commands)
and [testing guide](../../docs/testing.md).

| Owner | Assets |
| --- | --- |
| TAMOSS release | Operator manifest, compatibility metadata, dependency manifest and runtime catalogue |
| Matching TAMOSS source archive | Platform Helmfile and charts, multi-server instance base, browser tests and media fixture |
| This directory and `charts/gitops` | Operator/instance overlays, shared HA and OCI platform values, external database bootstrap chart, secret references, IngestRun and browser container configuration |
| Infrastructure configuration | Kind, Crossplane, OCI provisioning, observed runtime inputs, resource identities and cloud teardown |

Local checks cache verified upstream files under `.local/tmp/tamoss/<release-record-sha256>/`.
Flux uses the checked-in files described under [source delivery](#source-delivery).
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
requirements, then run `mise run check`. Upstream interface changes may require local
overlay or test-selection changes. Verified database TLS remains mandatory.

Initial deployment retains the selected Git revision and records its TAMOSS pin
in `tamoss-release.yaml`. `qualify` restores that selection from the retained
revision. This bookkeeping alone does not qualify an upgrade or establish that
database migrations can be reversed.

Preserve the release records and original Kind cluster through teardown. `down`
removes workloads and infrastructure through Kind.
See [Contributing](../../CONTRIBUTING.md#release-selection) and
[deployment from Git](../gitops/README.md#demo-inputs-and-source-changes)
for release selection, verification and lifecycle instructions.

## Source delivery

Flux in Kind consumes the operator's pinned upstream OCI bundle directly.
Unchanged platform helper charts, defaults and instance manifests from the
selected TAMOSS source release are checked in under `upstream/` directories.
`mise run check` compares them with the verified release and checks `pins.yaml`.
This repository's overlays remain separate from those upstream files.

Flux packages local chart directories from the pinned Git commit. The demo has
no custom deployment bundle or chart publication prerequisite. See
[deployment from Git](../gitops/README.md).
