# GitOps integration

[TADOSS](../tadoss/README.md) can be enabled in the environment repository after
bootstrap. Its credentials and permissions are prepared before Kind stops; it
then uses the existing platform services. Linked-media and persistence checks
passed with Kind stopped and unchanged OCI resource IDs; see the
[qualification limits](../../docs/testing.md#verified-coverage-and-limits).

[Overview](../../README.md) | [Architecture](../../docs/architecture.md) | [Operations](../../docs/operations.md) | [Testing](../../docs/testing.md)

Kind creates the environment and its retained OCI Vault/key. Flux, Crossplane
and External Secrets on OKE then take responsibility for ongoing operations.
The original Kind is stopped after ownership transfer and retained for teardown.
TAMOSS source, charts, profiles and release assets remain read-only.

Live OCI checks passed bootstrap/repeat, workload authentication, persisted secret
delivery, private Git/GHCR pulls, ownership transfer in both directions, Kind-off
application operation and interrupted/resumed teardown. A supported TAMOSS upgrade
and package-read credential rotation/revocation remain unqualified. See
[verified coverage and limits](../../docs/testing.md#verified-coverage-and-limits).
The internal `bootstrap`, `gitops` and `transfer` Task namespaces are not public
entry points. The root `up`, `qualify` and `down` commands retain the previously
tested Kind-owned lifecycle until the replacement is qualified.

## Repository contents

The operator clones this product and prepares a separate private environment
repository. Initial export writes one cluster directory containing:

| File | Responsibility |
| --- | --- |
| `values.yaml` | Non-secret environment outputs, settings, dependency pins and TAMOSS release hashes/OCI digest |
| `sources.yaml` | Exact product and TAMOSS source commits |
| `infrastructure/environment.yaml` | Observe-only environment declaration with all exact provider bindings and the original creation identity |
| `infrastructure/kustomization.yaml` | Infrastructure entry point |
| `releases.yaml` | Integration HelmRelease and infrastructure readiness dependencies |
| `namespaces.yaml` | Runtime namespaces |
| `flux.yaml` | Controller installation exported by the pinned Flux CLI |
| `sync.yaml` | Environment Git source and root reconciliation |
| `kustomization.yaml` | Root entry point and watched settings ConfigMap |

Export validates the checkout's origin, branch, path and deployment identity.
It writes this directory once and preserves subsequent user changes. Incomplete
existing configuration and missing provider bindings stop export. It does not
commit or push. Secrets, Kubernetes status, kubeconfigs and owner references are
excluded; non-secret cloud identifiers belong in the private environment repo.

Flux fetches reusable integration charts from the pinned product commit and
upstream platform charts from the release's recorded TAMOSS commit. Git source
includes make the upstream instance profile and platform defaults available in
the product's source artefact. The defaults become a watched ConfigMap consumed
through `valuesFrom`, so changing the TAMOSS source can update values independently
of the product chart. The environment repo contains neither source tree.

The operator installation comes from an immutable private GHCR bundle. The
[bundle workflow](../tamoss/README.md#private-release-bundle) verifies published
assets, packages an explicit allowlist and preserves upstream bytes. Flux applies
local HA patches. The root configuration owns runtime namespaces; the operator
overlay excludes its bundled Namespace to avoid a second owner.

## Inputs and secret delivery

Start with the [private environment, settings and bounded cost inputs](../../docs/getting-started.md#environment-inputs), plus
[`foundation.yaml`](../../environments/example/foundation.yaml) and
[`gitops.yaml`](../../environments/example/gitops.yaml). Select an existing
environment checkout, published product commit and private bundle digest.
The GitHub App needs read access to both Git sources that use it. GHCR uses a
separate package-read credential.

The bootstrap OCI principal also needs scoped access to create/read the vault and
key, persist/read/retire its secrets, and manage the runtime IAM policies in the
dedicated compartment. The original infrastructure grants alone are insufficient.
Keep these grants and the foundation owner available through retirement; a
retained vault/key prevents treating the compartment as empty after teardown.
Foundation inputs are immutable. Crossplane creates, observes and retains the
vault/key without updating them; later maintenance belongs to their recorded
owner. Bootstrap requires both resources to be Ready and Synced before secret
delivery. This also avoids the pinned OCI provider's replacement difference on
unused external-key fields.

Bootstrap reads these owner-only files under the private environment's `secrets/`:

- `github-app-id`, `github-app-installation-id`, `github-app-private-key`;
- `ghcr-dockerconfigjson`, containing the Docker registry authentication document;
- `s3-access-key` and `s3-secret-key`, containing exact credential bytes.

Supply the two GitHub App IDs as decimal digits without a trailing line ending.
PEM and Docker JSON files retain their native formats.

Kind's ESO uses the configured OCI user principal. Password generators and
`PushSecret` with `IfNotExists` persist initial credentials; all consumers use
ExternalSecret readback. After readback succeeds, bootstrap removes creation
resources and imported Kubernetes staging Secrets. Missing established Vault
secrets fail visibly. Original local input files remain under the operator's
control.

OKE receives namespace-scoped SecretStores using workload identity. The local
OCI signing key stays out of OKE. Separate IAM grants identify the exact cluster,
namespace and service account. The database adapter can only read connection
details in the dedicated compartment; Kubernetes limits it to patching its named
ConfigMap. Flux waits for the current Job and matching connection data before
delivering the CA to consumers. PostgreSQL connections retain `verify-full` TLS.
The database's initial administrator credentials use Crossplane `initProvider`;
late initialisation is disabled for that resource so adoption cannot turn them
into enforced updates. The composition retains the database's external name from
its existing annotation or observed ID because the pinned provider otherwise
does not persist that annotation without late initialisation. Ownership comparison
verifies the observed administrator and initial credential references without
comparing OCI's creation-only state.

The pinned OCI provider applied a backup-retention change but then reported an
empty `PatchDbSystem` request. Observation recovered automatically after the
five-minute check timed out. Treat this as a transient provider limitation:
verify the actual OCI setting and require `Synced=True` before ownership changes.

## Lifecycle stages

1. Validate bounded inputs; create original Kind, retained foundation and persisted
   credentials; provision the infrastructure and export the environment directory.
2. Review and publish the exported configuration. Install OKE secret delivery and
   Flux, then verify release adoption and observe-only infrastructure reconciliation.
3. Compare exact external names, provider configuration, cloud status and ownership
   tags. Set Kind to observation, wait for operations to finish, pause reconciliation
   and persist its non-writing configuration locally.
4. Prepare the Git promotion, grant runtime provider writes and publish the reviewed
   change. Verify OKE reconciliation and TAMOSS readiness, then stop original Kind.
5. Make operational changes through Git. Qualification uses the running release's
   verified assets and exercises ingest, TLS, external storage, UI and worker drain.
6. For teardown, restart original Kind and verify the current published checkout.
   Suspend Flux reconciliation, quiesce OKE's provider resources and revoke its write
   grants. Refresh Kind's controllers/API from the current product and Git selections,
   retaining Kind's API-key authentication. Return current configuration to Kind in observe-only mode; compare both
   inventories before granting deletion authority.
7. Finalise TAMOSS while its operator is available. Keep parent reconciliation
   suspended and resume each application declaration for deletion. Remove releases and
   the load balancer, then delete infrastructure. Confirm direct OCI inventory,
   remove runtime IAM grants and schedule environment-secret deletion before
   removing Kind. Record the retained vault/key, owner and pending secret deletions.

Runtime bootstrap can resume after an interrupted readiness check. Once Flux's
Helm controller is installed, retries leave secret-delivery releases to Flux;
Helmfile no longer upgrades them. Once the environment Kustomization owns Flux's
controller installation, retries also leave those manifests to Flux.
Bootstrap refreshes Kubernetes API discovery after the infrastructure controllers
are ready before checking their resources.

Secret deletion scheduling is asynchronous. If OCI still reports
`SCHEDULING_DELETION`, retain Kind and rerun teardown after scheduling completes.
Removal requires `PENDING_DELETION` or `DELETED` for every environment secret.

The transfer uses the same deployment ID and original cloud ownership tags, with
separate Kubernetes composite UIDs for Kind and OKE. It requires the original
Kind state; it does not restore a lost management cluster. A failed gate retains
state for diagnosis and retry.

### Adoption controls

The [environment API](../../charts/environment/definition.yaml) permits full
management (`['*']`), observation (`[Observe]`) or deletion without updates
(`[Observe, Delete]`) through `spec.managementPolicies`. Adoption starts in
observation and requires the existing deployment ID, original composite UID and
all 23 exact provider external names in `spec.adoption`. Bindings are immutable.
A bucket external name is `n/<namespace>/b/<bucket>`, not its OCID. The composition
preserves original cloud ownership tags when the Kubernetes composite UID changes.

Transfer gates compare both inventories, provider configuration, cloud status and
tags before changing the writer. Ordinary `up` and `down` reject an adopted or
observe-only environment.

The [provider package chart](../../charts/packages/) accepts
`okeWorkloadIdentity.region`. It gives each OCI service provider a distinct stable
service account and namespace-scoped ProviderConfig. Its authentication Secret
contains only the method and region. IAM grants name the exact OKE cluster,
namespace and service account; the Kind API signing key is not copied to OKE.

## Release changes

Prepare and verify the next published TAMOSS release, publish its allowlisted
bundle and review its compatibility metadata. Update the matching source commit
in `sources.yaml`, bundle digest, release checksums, image and dependency selections
in `values.yaml` together. Keep the product integration commit unless that release
needs an integration change. Flux reconciles the upstream charts/profile and
operator bundle; the TAMOSS operator owns application images and migrations.

Successful reconciliation and a supported upgrade must be observed before a
release is qualified. Schema or chart incompatibilities may require an integration
change. Teardown uses current Git/live inventory and the recorded installed
release, while preserving the initial release record for audit.

Before an upgrade, record the current Git revision and verify that existing
ingested media can be read. Review the target release's migration and recovery
requirements. After reconciliation, repeat those reads and ingest a new asset
with Kind stopped. A changed source commit, successful render or same-version
reconcile alone does not qualify an upgrade. If rollout fails, preserve the
failure and installed-release evidence; reverting Git requires confirmation that
the target's database migrations permit returning to the previous release.
Check retained media before running qualification again: qualification replaces
its existing test flows before submitting fresh ingest.

## Package-read credential rotation

The foundation owner rotates the existing `<deploymentId>-ghcr` secret in OCI
Vault. Its JSON payload contains a `dockerconfigjson` string holding Docker's
credential document. Use the native OCI CLI with an owner-only JSON input file;
keep credential values out of command arguments and logs. Bootstrap's
`IfNotExists` imports deliberately preserve established values, so changing a
local bootstrap file does not rotate the persisted credential.

ESO periodically updates `flux-system/ghcr`. Its
[manual refresh annotation](https://external-secrets.io/latest/introduction/faq/#can-i-manually-trigger-a-secret-refresh)
can request an immediate readback. Verify a new refresh and the delivered value
without printing it, then reconcile `OCIRepository/tamoss-release`. Test a fresh,
temporary OCIRepository against the same private digest and delivered Secret to
verify registry access independently of the existing source's cached artefact.

Move every consumer, including any Actions secret using the old token, before
revocation. After revoking the old token at GitHub, a separate temporary source
using that token must report `Ready=False` with an authentication-related fetch
failure. The replacement must still fetch successfully. An arbitrary fetch error
does not establish revoked-access rejection. Keep failure probes separate from
the application source, remove them and their temporary Secrets afterwards, and
retain only redacted evidence. This procedure still requires live qualification.
