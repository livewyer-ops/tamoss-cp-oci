# Testing

[Overview](../README.md) | [Getting started](getting-started.md) | [Operations](operations.md) | [Architecture](architecture.md)

Run commands from the repository root with Aqua's tools on `PATH`. Local checks
need Docker and internet access. They do not require OCI credentials.

## Local checks

```bash
task check
```

| Area | Coverage |
| --- | --- |
| TAMOSS release | Published metadata/checksums, matching source, immutable bundle and selected upstream browser-test collection |
| Infrastructure | Initial/partial/ready composition rendering, schema validation, immutable inputs and deletion dependencies |
| Database | SQL repeatability, released migration command and trusted TLS; rejection of untrusted CA, hostname mismatch and plaintext |
| Runtime | External service settings, HA overlays, operation/ownership contracts and release matching |
| TADOSS | Immutable assets, shared platform configuration, separate database and scoped Vault access, PostgreSQL 16 migrations and TLS rejection |

The check builds the container for the selected release's unchanged browser tests.
Only the cases used by this deployment are collected. Downloads/build caches are
private under `.local/tmp/`; reports and browser build logs are under `.local/reports/`.

## Management checks

```bash
task check:management
```

This includes `check`, then creates and removes a disposable, credential-free Kind
cluster. It tests provider package health, real API admission, required database
CA references, identity/adoption rejection and interrupted cleanup. Cleanup checks
include partial installs and retention of state when the cloud audit fails.

Bootstrap checks use the real Crossplane and ESO controllers with fixture child
compositions that create no cloud resources. They cover dependency readiness,
controller restart with unchanged child identities, rejection of a replaced root,
preservation of current settings after release and the pause before deletion.

External Secrets uses a local Kubernetes backend; the database connection Job
uses fixture retrieval. Tests cover persisted-value reuse and refresh, missing
secrets, denied access, stale connection data and release-record handling. Native
Job tests exercise asynchronous secret retirement, deadlines and failed retrieval;
Kind restart checks preserve the kubeconfig and reject a mismatched identity. Git
publication checks cover repeat pushes, interrupted promotion and unrelated edits. These
checks do not establish OCI authentication, real Vault rotation or a TAMOSS upgrade.

## OCI storage check

This creates a real private OCI bucket and a temporary Kind cluster. Prepare a
separately authorised, dated spending allowance, a test compartment and a scoped
[OCI profile](getting-started.md#api-signing-profile). Run local checks explicitly
before paid testing:

```bash
task check
task check:storage OCI_TEST_COMPARTMENT_ID=ocid1.compartment.REPLACE
```

Expected: repeat bucket apply succeeds, deletion is confirmed directly through
OCI, and Kind is removed. The command prepares separate inputs and does not run
the unrelated local suite. Its default directory is `.local/tmp/storage-check`.

If interrupted or failed, preserve that directory and use the same OCI identity:

```bash
task check:storage:cleanup
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
and the matching published environment Git checkout:

```bash
task qualify ENV_DIR=.local/environment CHECKOUT=.local/gitops
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
evidence and continue independent checks as appropriate, while keeping the budget
and cleanup deadline. Follow [operations](operations.md#retry-a-failed-deployment).

## Verified coverage and limits

| Behaviour | Observed status |
| --- | --- |
| TAMOSS application | External DB/S3, trusted TLS, ingest, browser access/playback, replica placement and network policy passed on a fresh deployment |
| Worker disruption | Replica placement and ordinary worker-drain availability passed |
| Original Kind interruption | Stop/start preserved identity and resumed reconciliation; service continuity passed |
| Bootstrap root | Dependency convergence, controller restart and release/pause checks passed locally; OCI provisioning with Task stopped still needs live qualification |
| Public GitOps lifecycle | Fresh bootstrap, repeat with unchanged identity/Git/Kind state, current-Git qualification, workload authentication, persisted secrets, private Git/GHCR pulls and ownership transfer/return passed |
| Shared TAMOSS/TADOSS operation | Git-enabled TADOSS, trusted HTTPS, OAuth scope enforcement, timed metadata linked to ingested media, persistence after verified pod replacement and unchanged OCI resource IDs passed with Kind stopped |
| Combined environment cleanup | Public down completed in one invocation: original Kind startup, current-Git ownership return, application finalisation, empty OCI hardware audit, pending Vault secret deletion and Kind removal passed |
| Build readiness | Fresh TAMOSS bootstrap completed without a provider restart. Git-enabled TADOSS passed after the OAuth startup-hook correction; each Authentik worker required one automatic restart after its first hook timed out. First-attempt hook completion remains unqualified |
| Release upgrade and package credential rotation/revocation | Remain unqualified; local fixtures and same-version reconciliation do not establish these outcomes |
| Recovery and other failure modes | Managed-database failover and browser logout-button interaction remain untested; regional recovery and management-state restoration are not established |

Detailed procedures are in the [GitOps guide](../deploy/gitops/README.md).
