# Testing

[Overview](../README.md) | [Contributing](../CONTRIBUTING.md) | [Operations](operations.md) | [Architecture](architecture.md)

Run commands from the repository root through mise. Local checks need Docker
with its Compose plugin and internet access. They do not require OCI
credentials. Deploying does not require any command on this page.

## Local checks

```bash
mise run check
```

| Area | Coverage |
| --- | --- |
| TAMOSS release | Published metadata/checksums, matching source, immutable bundle and selected upstream browser-test collection |
| Infrastructure | Initial/partial/ready composition rendering, schema validation, immutable inputs and deletion dependencies |
| Generated state | Published runtime values and runtime access readiness; local seed preparation without cloud outputs and identical configuration export |
| Database | SQL repeatability, released migration command and trusted TLS; rejection of untrusted CA, hostname mismatch and plaintext |
| Runtime | External service settings, HA overlays, operation/ownership contracts and release matching |
| Operational Jobs | Shared retry bounds, security, image and temporary-storage contract for the remaining Jobs; rejection of missing deadlines and unsafe container permissions |
| Remote OKE deployment | Git source, local values and substitutions, and access/retirement rendering contracts; controller checks run under `check:management` |
| Installation flow | Fresh-install command sequencing, refusal to reuse an existing deployment, failure propagation and credential-export cleanup; Git source selection, public authentication bypass and dependency-lock validation |
| Setup discovery | Fixture-backed OCI/IP lookups, image selection, domain placement, explicit overrides, setup arguments, failure preservation and refusal to change existing deployments |
| Preflight | Stubbed Docker, GitHub and OCI checks: missing or placeholder settings and each unavailable dependency stop `up` with its message; a public source skips the GitHub checks |
| TADOSS | Immutable assets, shared platform configuration, separate database and scoped Vault access, PostgreSQL 16 migrations and TLS rejection |

`qualify` builds the container for the selected release's unchanged browser tests;
only the cases used by this deployment are collected. A GitHub workflow runs
`mise run check` on pull requests and on `main`. Downloads/build caches are
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

The remote deployment test adds a second disposable Kind cluster. Production
credential tasks establish a real ServiceAccount token. Flux in the management
cluster reads an authenticated local SSH Git fixture and applies a Helm release
and Kustomize workload remotely. Values and substitutions stay in the management
cluster. The test checks TLS/identity rejection, continued access during teardown,
revocation and suspended declarations across controller restart.
The target has no Flux installation. Kind's certificate supplies administrator
access in the fixture; this does not qualify OCI authentication.
The local Git fixture requires `sshd` on the host and a free port 22422 reachable
from the disposable Kind network. Its forced command permits read-only access to
the test repository; cleanup stops that server and removes its temporary keys.

Authentik startup checks use the selected release's chart and image with an
external PostgreSQL database and verified TLS. They require bounded OAuth setup
with no server or worker restarts, then first-attempt repeat application and
recovery from an invalid blueprint without pod replacement.

Bootstrap checks use the real Crossplane and ESO controllers with fixture child
compositions that create no cloud resources. They cover dependency readiness,
controller restart with unchanged child identities, rejection of a replaced root,
preservation of current settings after release, teardown retaining Kind ownership
and the pause before deletion.
Flux installs the Kind controller releases from the authenticated Git fixture. Further
checks cover chart failure/recovery, the controller-derived secret release and composed IAM policies,
irreversible credential retirement and a suspended instance across controller
restarts and original Kind stop/start. Fixture sources and a Kubernetes secret backend replace GitHub and OCI Vault;
these checks do not qualify those external services.

External Secrets uses a local Kubernetes backend; the database connection Job
uses fixture retrieval. Tests cover persisted-value reuse and refresh, missing
secrets, denied access, stale connection data and release-record handling. Native
Job tests exercise asynchronous secret retirement, deadlines and failed retrieval;
Kind restart checks preserve the kubeconfig and reject a mismatched identity. These checks do not establish OCI authentication, real Vault rotation or a TAMOSS upgrade.

S3 checks run the production credential Job with only OCI requests substituted.
They verify empty-input blocking, creation claims, interrupted-response replay
rejection, Vault-style persistence and Helm upgrade retention. Admission checks
reject changed identity domains and the removed manual-user interface. Composition
checks cover generated identities, restricted capabilities, policy drift and immutable ID
records before credential creation. Retirement checks retain unrelated
keys, resume after deletion and reject uncertain creation outcomes. Composition
checks keep bootstrap authority active until the creation Job and its Pods are
gone. These local checks do not establish live OCI IAM propagation or API outcomes.

Readiness checks wait for initial source revisions and reject stale runtime source and chart
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
and the matching product source revision:

```bash
ENV_DIR=.local/environment mise run qualify
```

**Qualification changes the environment.** It deletes its previous IngestRun and
owned fixture flows, then requires the store to contain no other flows. It uploads
a fresh fixture, creates an operator-owned IngestRun and drains one worker using
`--delete-emptydir-data`. Use a dedicated qualification environment. Check retained
media before rerunning qualification; the old test flows will be removed.

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
[operations](operations.md).

`qualify` exercises TAMOSS. When TADOSS is enabled, follow the
[shared-platform qualification sequence](../deploy/tadoss/README.md#verification-and-removal)
to capture the infrastructure baseline and run its OAuth and persistence checks too.

## Verified coverage and limits

On 11 November 2026, published commit `51c3af4` completed a fresh OCI deployment
in `uk-london-1`, TAMOSS and TADOSS qualification and teardown. Both
applications were enabled before installation. `setup` discovered every OCI
setting using an administrator profile. Deployment and teardown used a temporary
scoped OCI identity and needed no manual resource repair.

| Behaviour | Observed status |
| --- | --- |
| Setup discovery | Identity domain, storage namespace, service network, OKE image, placements and public IPv4 address were discovered; no setting was entered except the compartment and contact |
| Git delivery and readiness | Private SSH fetch with a temporary read-only deploy key, chart packaging from the selected commit and current-revision readiness passed. One unattended `up` completed in approximately 26 minutes |
| Worker placement | The node pool reported one worker in each of three availability domains, in fault domains 1, 2 and 3 |
| Remote access | The host issued a non-expiring ServiceAccount token; teardown removed it with the remote access after application removal |
| TAMOSS | Trusted TLS, ingest, media and byte-range reads, anonymous rejection, the selected browser tests, replica placement and network policy passed |
| Worker disruption | API and login-path sampling across the worker drain had no failed requests; the worker was uncordoned and post-drain media reads passed |
| TADOSS | Trusted TLS, OAuth scopes, linked timed metadata and persistence after pod replacement passed. Inventoried OCI IDs were unchanged |
| Teardown | One `down` removed workloads, cloud resources, application IAM, the Git deploy key and Kind in approximately 15 minutes. Independent native OCI inventory found no remaining workload resources. Existing local clusters were unchanged |
| Retained foundation | The pre-existing compartment, Vault and key were retained. The deployment's Vault secrets were scheduled for deletion |

Later on 11 November, commit `7649e61` repeated the deployment, both
qualifications and teardown with one temporary identity holding only the
[published policy](../deploy/oci/README.md#policy). `setup` discovered every
setting with that identity, and `up` passed its preflight checks and completed
in approximately 26 minutes. The first `setup` attempts were refused as
unauthenticated for about two minutes after the API key was created.

Two earlier runs on 10 November used the same design before its final commits;
the second also passed as one unattended `up`, with its three composed runtime
IAM policies observed Ready and Synced. `check:management` passed in full
on the merged content.

On 10 November, commit `0bc2c3e` passed an original Kind interruption on OCI:
media and UI login access continued with Kind stopped, the same container and
management identity returned and Flux readiness recovered. That deployment used
an expiring OKE token. The interruption has not been repeated on OCI with the
non-expiring token; local checks cover Kind restart.

In the `0bc2c3e` run the TADOSS OAuth blueprint Job failed its first attempt and
completed on its automatic retry. Its failure log contained an exception while
sanitising importer logs, so the underlying cause remains unconfirmed. One local
Authentik startup check also failed once while other checks shared the host and
passed when repeated alone.

Deployments running longer than about an hour, other regions and regions with fewer than three availability domains
are unverified on OCI. Release upgrades, credential rotation, managed-database
failover, browser logout-button interaction, regional recovery and
management-state restoration remain unqualified. Earlier OCI external-binding
loss and intermittent ACME failures were not reproduced; their causes remain
unconfirmed.

Detailed procedures are in the [GitOps guide](../deploy/gitops/README.md).
