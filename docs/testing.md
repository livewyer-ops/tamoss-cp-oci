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

Setup contracts exercise private initialisation, preserved edits, deterministic
regional selections, unavailable/ambiguous images, invalid configuration and
repeat preparation without discovery. The client-asset lifecycle still requires
a fresh full OCI deployment, native GitHub bootstrap and Vault-backed SSH
handover. An isolated OCI test passed private snapshot upload/readback, restricted
reader access, Flux Bucket consumption, Helm/Kustomize reconciliation and source
cache recovery. Those results do not establish the complete OKE lifecycle.
Local contracts and controller tests cannot establish unobserved cloud outcomes.

The Flux-managed Kind bootstrap, OKE bootstrap Job and Vault-delivered adoption
bindings passed an assisted OCI run. The Job succeeded on its first Pod attempt;
runtime values and applications converged through ordinary reconciliation.
Repeat up preserved identity and Git while Kind remained stopped.

The run required retries while new OCI credentials propagated, host comparison
and teardown corrections, and native certificate renewal after an ACME timeout.
The corrected comparisons retain resource identity and desired configuration
while allowing provider-owned IP attachments and approximate bucket usage to
differ. Native API tests cover the deletion-policy transition and interrupted
ownership return. An uninterrupted lifecycle from the corrected product remains
unqualified.

Deployment readiness now includes current-generation public certificates for
Authentik, TAMOSS and enabled TADOSS. Native Flux checks cover missing, false,
unknown and stale certificate readiness and recovery. This prevents false
success while TLS is unavailable; it does not resolve or qualify the original
ACME connection timeout. The separate `up` and `handover` commands still need
a fresh uninterrupted OCI lifecycle.

| Behaviour | Observed status |
| --- | --- |
| Automatic storage identity and credentials | Isolated OCI qualification passed Crossplane IAM creation, restricted capabilities, Job creation, exact Vault readback, bucket read/write and denial for another existing bucket. Repeats and provider restarts preserved IDs and credentials; S3 reads passed with Kind stopped. Exact-key revocation, native IAM deletion and repeated cleanup passed. This does not establish a full deployment or GitOps handover |
| TAMOSS application | External DB/S3, trusted TLS, ingest, all five selected upstream browser tests, replica placement and network policy passed |
| Worker disruption | All 540 API/login-path requests succeeded across the worker drain; post-drain media reads passed |
| Original Kind interruption | Stop/start preserved identity and resumed reconciliation; service continuity passed |
| Bootstrap root | Flux installed the Kind controllers; Crossplane's OKE Job completed on its first attempt with zero container restarts. Vault-delivered bindings and derived runtime values converged without a provider restart |
| Initial Flux convergence | All initial runtime Kustomizations, including TAMOSS, reached Ready before any host reconciliation request. Current-Git refresh and ownership transfer remain explicit operations |
| Public GitOps lifecycle | Resumed bootstrap, repeat with unchanged identity/Git/Kind state, current-Git qualification, workload authentication, persisted secrets, private Git/GHCR pulls and ownership transfer/return passed |
| Shared TAMOSS/TADOSS operation | Git-enabled TADOSS, trusted HTTPS, OAuth scope enforcement, timed metadata linked to ingested media and persistence after four verified pod replacements passed with Kind stopped; all 34 OCI resource IDs were unchanged |
| Combined environment cleanup | Resumed public down passed after the comparison and interrupted-return corrections, with the pinned host checkout retained throughout. Current-Git ownership return, application finalisation, all 21 hardware categories empty, scheduled Vault secret deletion and Kind removal passed |
| Workload convergence | Git-enabled TADOSS converged without a host reconciliation request; its OAuth Job completed on the first attempt with unchanged Authentik pod UIDs/restart counts. Cold public certificate issuance remains subject to the ACME qualification limit above |
| Release upgrade and package credential rotation/revocation | Remain unqualified; local fixtures and same-version reconciliation do not establish these outcomes |
| Recovery and other failure modes | Managed-database failover and browser logout-button interaction remain untested; regional recovery and management-state restoration are not established |

The storage identity test used narrower bucket permissions than the documented
provisioner prerequisites. Its independent OCI audit found buckets remaining
after their Kubernetes records disappeared; administrator-assisted cleanup
removed them. This test qualifies IAM retirement, not unattended bucket teardown.

Detailed procedures are in the [GitOps guide](../deploy/gitops/README.md).
