# TAMOSS integration

TAMOSS is an external, read-only dependency. `release.yaml` selects an immutable
release record and matching source archive. `Taskfile.yaml` verifies and prepares
them using the repository's native tools. The [operating guide](../../README.md)
lists the public commands and named checks.

| Owner | Assets |
| --- | --- |
| TAMOSS release | Operator manifest, compatibility metadata, dependency manifest and runtime catalogue |
| Matching TAMOSS source archive | Platform Helmfile and charts, multi-server instance base, browser tests and media fixture |
| This directory | Operator/instance overlays, HA and OCI platform values, external database bootstrap chart, secret references, IngestRun and browser container configuration |
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

An environment's `tamoss-release.yaml` is retained evidence of its original
selection. Preserve it through teardown. See the [operating guide](../../README.md)
for release selection, verification and lifecycle instructions.
