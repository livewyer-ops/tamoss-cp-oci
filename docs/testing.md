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
| Account tasks | Stand-in OCI CLI: provisioner creation from the published policy, owner-only profile and key, refusal to replace records, removal in dependency order and after a failed policy request |
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
CA references and identity/adoption rejection.
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

When TADOSS is enabled, `qualify` also captures an infrastructure baseline first
and runs the [TADOSS checks](../deploy/tadoss/README.md#verification-and-removal)
afterwards.

## Verified coverage and limits

A fresh deployment in `uk-london-1` with TAMOSS and TADOSS enabled has passed
`setup`, `up`, both qualifications and `down` using a provisioner that holds
only the [published policy](../deploy/oci/README.md#policy), with no manual
resource repair.

| Behaviour | Verified on OCI |
| --- | --- |
| Account preparation | `account:create` creates a working provisioner and `account:remove` deletes its user, group, policy and key |
| Setup discovery | Identity domain, storage namespace, service network, OKE image, placements and public IPv4 address are discovered; only the compartment and contact are entered |
| Git delivery and readiness | Private SSH fetch with a temporary read-only deploy key, chart packaging from the selected commit and current-revision readiness. One unattended `up` completes in about 35 minutes |
| Reconciliation inside OKE | Flux in OKE installs the platform and applications from the selected commit. The database connection Job reads its details with workload identity, and External Secrets delivers the Authentik values from Vault |
| Services inside OKE | Crossplane in OKE creates the PostgreSQL system and the media bucket with workload identity under the policy composed in Kind. `down` deletes both from inside OKE before Kind removes the network and the cluster |
| Settings without Kind | `up` stops Kind when the deployment is ready. With Kind stopped, `mise run apply` changes the database backup retention and OCI takes the new value, and it refuses a change to the admin allowlist. `qualify` passes with Kind stopped, and `down` restarts Kind and removes the deployment |
| Environment repository | `handover` moves the settings to a private GitHub repository without changing them, and `apply` then refuses. A backup retention change pushed to the repository reaches OKE within a minute and OCI takes it. `down` removes the repository's deploy key |
| Kind stopped | With Kind stopped for about eight minutes, OKE keeps the database, bucket and workloads ready, serves the public endpoints and restores a deleted Secret and a deleted PodDisruptionBudget. Kind's releases are ready again after it restarts |
| Worker placement | One worker in each of three availability domains, in separate fault domains |
| Remote access | The host issues a non-expiring ServiceAccount token; teardown removes it with the remote access after application removal |
| Enable TADOSS from Git | With Kind stopped, the first settings commit preserved both ConfigMaps, the TAMOSS instance UID, deployment generations and media bytes. A second commit changed only `tadoss.enabled`. OKE brought up two API replicas and two workers. A timed event matched the source playing in TAMOSS across a segment boundary. Retirement used the enabled setting. |
| TAMOSS | Trusted TLS, ingest, media and byte-range reads, anonymous rejection, the selected browser tests, replica placement and network policy |
| Worker disruption | API and login-path sampling across the worker drain has no failed requests; post-drain media reads pass |
| TADOSS | Trusted TLS, OAuth scopes, linked timed metadata and persistence after pod replacement |
| Teardown | One `down` removes workloads, cloud resources, application IAM, the Git deploy key and Kind in about 20 minutes. Jobs in OKE abort an unfinished multipart upload, empty the bucket and delete a manual database backup with workload identity. An independent OCI inventory finds no remaining workload resources |
| Retained foundation | A pre-existing compartment, Vault and key are retained. The deployment's Vault secrets are scheduled for deletion |

In the 18 November 2026 Git handover run, `up` took 43 minutes and `down` took
32 minutes. The operator intervened twice. During installation Flux reported
that it could not discover ExternalSecrets after all ten were ready. Restarting
the OKE kustomize-controller restored the credential health check in 16 seconds.
During retirement, OCI still had an unused duplicate of the public route table
after Crossplane deleted the managed one. The operator checked the deployment
and composite tags, VCN, rules and subnet inventory before deleting the
duplicate. Crossplane then removed the VCN. The independent administrator
inventory matched the empty baseline across all 21 workload lists.

Limits:

- Deployments running longer than the recorded 99-minute lifecycle, other regions and regions
  with fewer than three availability domains are unverified on OCI.
- Creating a new Vault and key with the published policy is unverified; the
  verified deployments reused a retained Vault.
- The handover run kept Kind stopped for 23 minutes before teardown. Longer stops remain unverified on OCI.
- Teardown after a database that failed to create is unverified on OCI.
- A release upgrade through `mise run apply`, and a change to the database shape
  or size, are unverified on OCI.
- Release upgrades, credential rotation, managed-database failover, browser
  logout-button interaction and regional recovery remain unqualified.
- Recovery after losing the Kind cluster is not supported; follow
  [manual cleanup](operations.md#manual-cleanup-after-losing-the-kind-cluster).
- The TADOSS OAuth blueprint Job has failed its first attempt once and completed
  on its automatic retry; the cause is unconfirmed.
