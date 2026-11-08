# Testing

[Overview](../README.md) | [Getting started](getting-started.md) | [Operations](operations.md) | [Architecture](architecture.md)

Run commands from the repository root through mise. Local checks
need Docker and internet access. They do not require OCI credentials.

## Local checks

```bash
mise run check
```

| Area | Coverage |
| --- | --- |
| TAMOSS release | Published metadata/checksums, matching source, immutable bundle and selected upstream browser-test collection |
| Infrastructure | Initial/partial/ready composition rendering, schema validation, immutable inputs and deletion dependencies |
| Generated state | Complete adoption snapshots, retention through missing status, rejection of changed IDs and mismatched readback; local seed preparation without cloud outputs and identical configuration export |
| Database | SQL repeatability, released migration command and trusted TLS; rejection of untrusted CA, hostname mismatch and plaintext |
| Runtime | External service settings, HA overlays, operation/ownership contracts and release matching |
| Operational Jobs | Shared retry bounds, security, image and temporary-storage contract for the remaining Jobs; rejection of missing deadlines and unsafe container permissions |
| Remote OKE seed | Shared seed/export rendering, Flux distribution component selection and repeated retirement after cluster deletion; two-cluster credential, convergence and retirement checks run in the management suite |
| Handover flow | Public command wiring and production mise sequencing with local substitutes for external actions; deployment without transfer, interrupted IAM/Git/shutdown, pending promotion commits, failed readiness and repeats without restarting Kind |
| TADOSS | Immutable assets, shared platform configuration, separate database and scoped Vault access, PostgreSQL 16 migrations and TLS rejection |

The check builds the container for the selected release's unchanged browser tests.
Only the cases used by this deployment are collected. Downloads/build caches are
private under `.local/tmp/`; reports and browser build logs are under `.local/reports/`.

## Management checks

```bash
mise run check:management
```

This includes `check`, then creates and removes a disposable Kind cluster without
cloud credentials. It tests provider package health, real API admission, required database
CA references, identity/adoption rejection and interrupted cleanup. Cleanup checks
include partial installs and retention of state when the cloud audit fails.
Flux also packages the operational charts from a source archive without generated
dependency packages, verifying that the shared Helm library resolves from source.

The OKE bootstrap test adds a second disposable Kind cluster. The host establishes
a real Kubernetes ServiceAccount token through the production credential tasks.
Kind's Flux installs the pinned distribution on the target and applies the shared
seed after the host process exits. Product source transport is a local fixture;
remote reconciliation and authentication use the real controllers and API servers.
The suite checks identity/TLS rejection, replay, partial-install cleanup and
retirement across controller restart. It waits for a real ten-minute token to
expire before verifying renewal and remote Flux changes after retirement.
Kind's certificate supplies initial administrator access in this fixture; it does
not qualify OCI user authentication, OKE token lifetime or cloud IAM propagation.

Authentik startup checks use the selected release's chart and image with an
external PostgreSQL database and verified TLS. They require bounded OAuth setup
with no server or worker restarts, then first-attempt repeat application and
recovery from an invalid blueprint without pod replacement.

Bootstrap checks use the real Crossplane and ESO controllers with fixture child
compositions that create no cloud resources. They cover dependency readiness,
controller restart with unchanged child identities, rejection of a replaced root,
preservation of current settings after release, teardown retaining Kind ownership
before handover and the pause before deletion.
Flux installs the Kind controller releases from a local chart artefact. Further
checks cover chart failure/recovery, controller-derived secret/IAM releases,
irreversible credential retirement and a suspended instance across controller
restarts and original Kind stop/start. Fixture sources and a Kubernetes secret backend replace GitHub and OCI Vault;
these checks do not qualify those external services.

External Secrets uses a local Kubernetes backend; the database connection Job
uses fixture retrieval. Tests cover persisted-value reuse and refresh, missing
secrets, denied access, stale connection data and release-record handling. Native
Job tests exercise asynchronous secret retirement, deadlines and failed retrieval;
Kind restart checks preserve the kubeconfig and reject a mismatched identity. Git
publication checks cover repeat pushes, interrupted promotion and unrelated edits. These
checks do not establish OCI authentication, real Vault rotation or a TAMOSS upgrade.

S3 checks run the production credential Job with only OCI requests substituted.
They verify empty-input blocking, creation claims, interrupted-response replay
rejection, Vault-style persistence and Helm upgrade retention. Admission checks
reject changed identity domains and the removed manual-user interface. Composition
checks cover generated identities, restricted capabilities, policy drift and immutable ID
records before credential creation. Retirement checks retain unrelated
keys, resume after deletion and reject uncertain creation outcomes. Composition
checks keep bootstrap authority active until the creation Job and its Pods are
gone. These local checks do not establish live OCI IAM propagation or API outcomes.

Binding-delivery checks submit Flux consumers before the snapshot exists, then
observe ESO persistence, delivery and Crossplane convergence without forcing
reconciliation. They reject changed bindings and retain the persisted record when
its PushSecret is removed. Credential tests verify that ESO adopts a seeded Git
Secret without replacing its UID. SSH deploy-key checks also retain the original
bytes when staging input changes and recover the Secret after input retirement.

Readiness checks wait for initial source revisions, reject stale infrastructure/runtime product and chart
observations and old Ready conditions after a values change. Real Flux checks
cover delayed dependencies and recovery without forced reconciliation.
Media-fixture preparation belongs to `qualify`;
`up` does not prepare test media.

## OCI storage check

This creates a real private OCI bucket and a temporary Kind cluster. Prepare a
separately authorised, dated spending allowance, a test compartment and a scoped
[OCI profile](getting-started.md#api-signing-profile). Run local checks explicitly
before paid testing:

```bash
mise run check
OCI_TEST_COMPARTMENT_ID=ocid1.compartment.REPLACE mise run check:storage
```

Expected: repeat bucket apply succeeds, deletion is confirmed directly through
OCI, and Kind is removed. The command prepares separate inputs and does not run
the unrelated local suite. Its default directory is `.local/tmp/storage-check`.

If interrupted or failed, preserve that directory and use the same OCI identity:

```bash
mise run check:storage:cleanup
```

Cleanup verifies the recorded identity, removes the owned Bucket through Crossplane
and checks OCI against the baseline before deleting Kind. It archives records under
`.local/reports/storage/`. Cleanup alone does not record a test pass.

`STORAGE_DIR` selects another private probe directory; pass the same value to both
commands. Failed cleanup retains state and credentials. Missing/incomplete records
stop automatic cleanup. If Kind is already absent, surviving cloud resources need
ownership-verified manual cleanup before the OCI audit can pass.

## Deployed qualification

Requires a running deployment, its original environment directory, credentials
and, after handover, the matching published environment Git checkout:

```bash
ENV_DIR=.local/environment CHECKOUT=.local/gitops mise run qualify
```

**Qualification changes the environment.** It deletes its previous IngestRun and
owned fixture flows, then requires the store to contain no other flows. It uploads
a fresh fixture, creates an operator-owned IngestRun and drains one worker using
`--delete-emptydir-data`. Use a dedicated qualification environment. Check retained
media before rerunning qualification after an upgrade; the old test flows will be removed.

| Area | Expected result |
| --- | --- |
| Ingest | Released tooling prepares the H.264/AAC fixture; a restricted S3 source feeds a successful IngestRun and owned Job |
| API and media | Authenticated access, anonymous rejection, object reads and byte ranges pass |
| Browser | Selected upstream SSO, protected browsing, write rejection and playback tests pass with TLS verification and no skips |
| Placement and network | Certificates Ready; replicas separated across workers; required Console connections allowed and unrelated clients denied |
| Worker drain | API/UI sampling overlaps the drain with no failed requests; the worker is uncordoned and media reads pass afterwards |

Reports are under `ENV_DIR/reports/`, including ingest records, placement/network
reports, `browser.log`, `browser.xml` and availability samples/results. The fixture
remains available afterwards; the next run replaces it and can overwrite reports.
Browser credentials are mounted read-only into the test container and removed
afterwards. The container receives neither OCI credentials nor the Docker socket.

A failed qualification leaves the deployment running for investigation. Preserve
evidence and continue independent checks as appropriate. Follow
[operations](operations.md#retry-a-failed-deployment).

## Verified coverage and limits

The reduced installer consumes a CI deployment bundle, uses Crossplane-owned
credential completion and waits on Flux readiness. Its local render and contract
coverage does not qualify the complete OCI lifecycle. The cloud results below
predate this installer change and must not be treated as proof of it.

Setup contracts exercise private initialisation, preserved edits, deterministic
regional selections, unavailable/ambiguous images, invalid configuration and
refusal of interrupted host preparation. An assisted OCI deployment consumed a
private client-owned snapshot built from a committed, unpushed product revision.
Kind and OKE used that snapshot without product Git access. Native GitHub
bootstrap and Vault-backed SSH handover passed, followed by Git-only TADOSS
enablement and qualification with Kind stopped. Neither application source
nor the selected snapshot changed during enablement.

The run required manual recovery of an OCI policy whose Kubernetes record had
lost its external binding after successful creation. Its underlying cause remains
unresolved. It also exposed a missing report directory, a duplicate Flux namespace
and a field-ownership conflict when returning deletion authority; these product
defects are corrected and covered by local checks. Asset-reader retirement needed
an empty-list handling correction and administrator removal of a membership that
the scoped provisioner could list but could not delete through the legacy IAM API.
A separate live test reproduced that refusal and removed the exact member through
the native Identity Domains group API using the existing scoped permissions.
The corrected reader retirement and its repeat passed without administrator
intervention. An uninterrupted full lifecycle remains unqualified.

Public TLS passed for Authentik, TAMOSS and TADOSS in this run. Native readiness
checks also reject missing, false, unknown and stale certificate observations.
These results do not establish that every cold certificate request will succeed
or that earlier intermittent ACME connection timeouts are resolved.

| Behaviour | Observed status |
| --- | --- |
| Client-owned assets | Private upload/readback, exact object-set verification, repeated publication and denied reader writes passed. Kind and OKE consumed the same snapshot while its product commit remained unpushed. OKE source-controller replacement recovered the identical artifact digest with Kind stopped |
| Automatic storage identity and credentials | Crossplane IAM creation, generated key, exact Vault readback, application storage and native storage IAM retirement passed during the full deployment. Separate isolated checks cover restricted capabilities, denial for another bucket and preservation across provider restarts |
| TAMOSS application | External DB/S3, trusted TLS, ingest, all five selected upstream browser tests, replica placement and network policy passed |
| Worker disruption | All 540 API/login-path requests succeeded across the worker drain; post-drain media reads passed |
| Original Kind interruption | Stop/start preserved identity and resumed reconciliation; service continuity passed |
| Remote bootstrap | The host supplied temporary OKE access to Kind. Native Flux stages installed remote Flux, ESO and asset access before the shared seed. Vault-delivered bindings and runtime values converged; successful up retired temporary remote access |
| Initial Flux convergence | All initial runtime Kustomizations, including TAMOSS, reached Ready before any host reconciliation request. Current-Git refresh and ownership transfer remain explicit operations |
| Public GitOps lifecycle | Repeated up preserved exact resource bindings. Native SSH bootstrap, Vault persistence, ownership transfer and repeated handover passed after the namespace correction. Repeated handover preserved Git and left Kind stopped |
| Shared TAMOSS/TADOSS operation | Changing only `tadoss.enabled` in client Git deployed TADOSS without asset publication or a host reconcile request. Trusted HTTPS, OAuth scopes, linked timed metadata and persistence after four verified pod replacements passed; all 35 inventoried OCI IDs, including the asset store, were unchanged |
| Workload convergence | TADOSS's OAuth Job completed on its first attempt with unchanged Authentik pod UIDs and restart counts |
| Environment cleanup | Assisted `down` and its repeat passed. Workloads, storage IAM and Kind were removed; Vault secret deletion was scheduled. Explicit asset-store retirement and its repeat passed. Independent administrator inventory found all 21 hardware categories empty; the pre-existing compartment, Vault and key remain retained |
| Release upgrade and package credential rotation/revocation | Remain unqualified; local fixtures and same-version reconciliation do not establish these outcomes |
| Recovery and other failure modes | Managed-database failover and browser logout-button interaction remain untested; regional recovery and management-state restoration are not established |

Detailed procedures are in the [GitOps guide](../deploy/gitops/README.md).
