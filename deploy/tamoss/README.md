# TAMOSS integration

[Overview](../../README.md) | [Architecture](../../docs/architecture.md) | [Operations](../../docs/operations.md)

TAMOSS is an external, read-only dependency. `release.yaml` selects an immutable
release record and matching source archive. `tasks.toml` verifies and prepares
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
requirements, then run `mise run check`. Upstream interface changes may require local
overlay or test-selection changes. Verified database TLS remains mandatory.

Initial deployment downloads the pinned deployment bundle.
`qualify` restores the selected release from that bundle, records it in
`tamoss-release.yaml` and
retains the initial lock as `tamoss-release.bootstrap.yaml`. This bookkeeping alone does not qualify an
upgrade or establish that database migrations can be reversed.

Preserve the release records through teardown. `down` returns current Git/live
configuration to Kind for deletion.
See [Operations](../../docs/operations.md#release-selection) and the [GitOps guide](../gitops/README.md#release-changes)
for release selection, verification and lifecycle instructions.

## Public release bundle

The release bundle contains only the checksum-verified published operator assets,
release metadata and a static Kustomize entry point. Upstream bytes are unchanged;
the source checkout, credentials and private working files are excluded.

The [publication workflow](../../.github/workflows/release-bundle.yaml) publishes
from the default branch using `GITHUB_TOKEN`. The package must be public and
associated with this product repository. For a new package, its owner must set
public visibility in GitHub's package settings after the first publication, then
rerun the workflow. The workflow checks anonymous consumption and records the
immutable digest for the release lock.

CI pulls that digest without a registry login when building the
[deployment bundle](../assets/README.md). It copies the matching source's deployment
directory unchanged and resolves Kustomize includes locally. Kind and OKE read the
public OCI registry. Upstream assets and this product's overlays remain separate;
no TAMOSS source or release file is modified.
