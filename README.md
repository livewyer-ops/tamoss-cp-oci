# TAMOSS on OCI Kubernetes Engine

This repository defines a temporary HA qualification environment: local Kind
runs Crossplane, which provisions OKE with three workers, external OCI
PostgreSQL and a private Object Storage bucket. Helmfile installs the platform;
Kustomize installs the published TAMOSS operator and `multi-server` instance.

[GitOps integration](deploy/gitops/README.md) adds a small environment repository,
OCI Vault delivery and Flux ownership on OKE. Its components and transfer controls
have local checks; complete OCI handover and upgrades still require live
qualification. The public deployment commands retain the tested Kind-owned lifecycle.

The selected TAMOSS release provides database TLS with certificate and hostname
verification for workloads and generated Jobs. Local checks exercise rendering,
SQL, TLS, configuration and operation contracts. Live infrastructure creation
and teardown have been verified with three Ready OKE workers, external object
storage and PostgreSQL reporting both Ready and Synced. TAMOSS deployment,
database bootstrap with TLS, ingest, object/range reads, browser login/playback,
replica placement and network policy have passed live checks. Repeat deployment
and management stop/start also passed. After correcting workload shutdown timing,
two worker drains passed all 540 API/login-path samples each; the final drain also
passed 270 authenticated UI API requests. Native HTTP session logout passed.
Browser logout-button interaction and managed-database failover remain untested.

## Prerequisites

Use a Linux workstation with Docker, Aqua, Git, curl, OpenSSL, GNU coreutils,
findutils and archive tools.
Tool versions are in [aqua.yaml](aqua.yaml); infrastructure component selections
and checksums are in [dependencies.yaml](dependencies.yaml).
[deploy/tamoss/release.yaml](deploy/tamoss/release.yaml) selects TAMOSS.
Use the original private environment directory for the lifetime of a deployment.

## Infrastructure adoption controls

The environment API supports `spec.managementPolicies` with full management
(`['*']`), observation (`[Observe]`) or deletion without updates
(`[Observe, Delete]`). Adoption requires the existing deployment ID, original
composite UID and all 23 exact provider external names in `spec.adoption`.
Bindings are immutable and adoption must start with observation. A bucket's
external name uses `n/<namespace>/b/<bucket>`; it is not the bucket OCID.
The composition retains original ownership tags when the Kubernetes UID changes.

These controls have local render/admission coverage. Internal transfer tasks
compare both inventories, stop the previous writer and return current Git
configuration to the original Kind for deletion. Real OCI handover still requires
qualification. Ordinary `up` and `down`
reject an adopted or observe-only environment; they continue to operate the
original Kind-owned lifecycle. Retain the original Kind and private records.

For OKE, the provider package chart accepts `okeWorkloadIdentity.region`. It
creates a distinct stable service account configuration for each OCI service
provider and a namespace-scoped ProviderConfig using OKE workload identity.
Its authentication Secret contains only the method and region. OCI policies must
grant the required service access to those exact cluster, namespace and service
account identities. Default Kind installation continues to use its scoped API key;
runtime workload authentication remains a live qualification requirement.

## Secret-store and connection components

The following charts are connected through the GitOps integration and have local
coverage. Ordinary `up` and `down` still use the original local secret and
connection handoff.

| Chart | Behaviour |
| --- | --- |
| [secret-foundation](charts/secret-foundation) | Separate retained OCI Vault and AES key, with immutable owner and provider identity; cloud deletion is excluded from its management policies |
| [secrets](charts/secrets) | Kind-only initial credential persistence, separate readback and namespace-scoped OKE workload identity; runtime configuration emits no password generator or PushSecret |
| [database-connection](charts/database-connection) | Bounded OCI CLI Job, validated hostname/CA response and a restricted ConfigMap patch that rejects stale database IDs and refresh revisions |
| [runtime-access](charts/runtime-access) | Cluster, namespace and service-account scoped OCI grants; provider write access is enabled only after the Kind resources are quiescent |
| [gitops](charts/gitops) | Flux sources, Helm releases and readiness dependencies for controllers, credentials, platform, network policy and TAMOSS |

Record the foundation's owner and cloud IDs before removing its management
cluster. Remove credential creation before starting consumers; established
environments must recover missing persisted values. The database adapter requires
scoped OCI access and consumer readiness checks; its configuration alone does not
qualify OCI workload authentication or database TLS.

## TAMOSS assets and upgrades

[deploy/tamoss](deploy/tamoss/README.md) contains this deployment's integration
configuration. The published operator manifest and matching source archive are
downloaded and verified in a private cache. The upstream platform Helmfile,
charts, multi-server base, browser tests and input fixture are consumed unchanged.
A neighbouring TAMOSS checkout is not required and is never modified.

The release lock records the tag and checksums for the release record and source
archive. The verified release record supplies the source commit, image digests
and published asset checksums. The instance's `spec.version` selects its runtime
from the operator's release catalogue. To select a future release, update the lock using
its published metadata, review compatibility and migration requirements, then
run `task check`. Changes to upstream configuration or test interfaces may still
require changes to our overlays. The database TLS requirement remains mandatory.

Each environment retains its original `tamoss-release.yaml`. `up` and `qualify`
reject a different repository selection; `down` uses the recorded selection and
can fetch its assets again. The lock is not an in-place upgrade or database
rollback mechanism. Finish teardown before selecting a different release for
that environment.

```console
aqua install
export PATH="$(aqua root-dir)/bin:$PATH"
task check
```

`check` verifies downloaded artefacts, composition initial/partial/ready states,
immutable inputs, deletion dependencies, SQL repeatability, runtime overlays,
operation contracts and browser-test collection. Database connection tests run
the pinned psql client and released migration command against a trusted TLS
server, an untrusted CA, a hostname mismatch and a plaintext server. It builds the container that
runs the selected release's unchanged browser tests. Download and build caches
are private under `.local/tmp/`.
Only the browser cases used by this deployment are collected; unrelated upstream
cases are outside this repository's local check.

```console
task check:management
```

This additionally creates a disposable, credential-free Kind cluster and checks
package health, real API admission including required database CA references,
cluster identity rejection and repeat
application cleanup without marker files, including removal before cert-manager
or the operator was installed. It also checks interrupted storage cleanup,
ownership rejection and state retention when the OCI audit fails, using fixture
credentials and a paused Bucket. It removes its cluster afterwards.

The management check also exercises ESO against a local Kubernetes secret backend
and runs the database connection Job with fixture retrieval. It checks persisted
credential reuse, missing values, denied access and stale connection publication.
These checks do not contact OCI Vault or the OCI PostgreSQL API.

```console
task check:storage OCI_TEST_COMPARTMENT_ID=ocid1.compartment.REPLACE
```

The storage check uses real OCI credentials and creates a small private bucket.
It checks repeat apply, deletion and direct OCI inventory before deleting Kind.
It requires a separately authorised, dated spending allowance and prepares its
own inputs without running the unrelated local suite. Run `check` explicitly
before paid testing. `task --list` shows the public commands. Task requires Aqua's
shims to resolve every managed tool before work starts. The PATH setup above
selects the pins for Task, its subprocesses and direct CLI use.

If the storage test fails or is interrupted, retain `.local/tmp/storage-check`
and use the same OCI profile:

```console
task check:storage:cleanup
```

Cleanup uses the recorded bucket, compartment and OCI identity. It removes the
owned Bucket through Crossplane, checks OCI directly against the baseline, then
deletes Kind and archives records under `.local/reports/storage/`. Failed cleanup
retains management state and credentials for another attempt. Cleanup alone does
not mark the test as passed. If Kind is already absent, the OCI audit must still
confirm deletion; surviving cloud resources require ownership-verified manual
cleanup. Incomplete or missing records stop automatic cleanup.
`STORAGE_DIR` selects an alternative private probe directory; use the same value
for the storage check and its cleanup.

## Environment inputs

Use a dedicated, precreated qualification compartment. Crossplane manages its
contents; this product does not create or delete the compartment. Configure a
scoped OCI API-key profile and supply a bucket-scoped S3 Customer Secret Key.
Credential creation and rotation belong to the operator's credential workflow;
the [account prerequisites](deploy/oci/README.md) describe the required access.

```console
install -d -m 700 .local/environment/secrets
cp environments/example/environment.yaml environments/example/settings.yaml environments/example/cost.yaml .local/environment/
```

Replace every example value. The environment describes region, compartment,
network ranges and API allowlist, OKE image/version/capacity, failure-domain
placements, two-node PostgreSQL capacity, bucket, owner, budget and expiry.
Environment names must contain 3-23 lowercase letters, digits or hyphens, start
with a letter and end with a letter or digit. This leaves room for the worker
suffix within OCI's 32-character node-pool name limit.
Keep namespace `tamoss-infra`, provider `oci` and database credential Secret
`database-admin`. Supply real ACME and administrator email addresses in settings.

Provide owner-only files `secrets/s3-access-key` and `secrets/s3-secret-key`.
Each file must contain the exact credential bytes without a trailing line ending.
`OCI_CLI_CONFIG_FILE` selects the OCI configuration file and `OCI_CLI_PROFILE`
selects its profile; defaults are the usual OCI config path and `DEFAULT`.
Its `key_file` must be absolute. The OCI CLI container mounts only that config
and key. Do not place credentials in manifests, command-line arguments or Git.

Complete `cost.yaml` using current regional prices. Include all workers, the
managed Kubernetes tier, PostgreSQL, storage, load balancing, networking and
transfer. Record money already spent, bounded run/cleanup hours and contingency.
The date must match the current UTC date, and the projected total must fit the
recorded allowance and environment budget. A new deployment's expiry must cover
the run and cleanup within that UTC day. Repeating a deployment with its recorded
management identity preserves that deadline and requires the full cleanup reserve
to remain. These checks validate an estimate; expiry tags do not stop spending.
The operator must monitor the run and begin teardown in time.

## Deployment and qualification

Run local checks explicitly after changing configuration or dependencies, then
complete the environment inputs:

```console
task up ENV_DIR=.local/environment
task qualify ENV_DIR=.local/environment
```

`up` records the OCI identity and environment inputs, creates or reuses the same
Kind cluster, installs Crossplane and captures a baseline inventory before
provisioning. Deployment UID tags distinguish environments with reused names.
The private identity record binds the management namespace UID, composite UID,
OKE identifier, remote namespace UID and API server address. Changed identities
stop the operation.

`up` verifies the selected release and prepares Calico, operator and media assets
without rerunning the render test suite. It validates the actual environment,
cost allowance and identities before provisioning. `qualify` verifies the release
and prepares its own test assets. Neither command requires a previous check cache.

The environment must report `Ready` and its managed resources must report
`Synced` before application installation. Infrastructure outputs supply runtime
hostnames, database CA/hostname and S3 settings. The TAMOSS operator resolves
application images and the database schema
revision from the selected release catalogue entry.
Passwords are generated once; missing credentials on an existing environment
stop deployment. Database initialisation precedes platform/application readiness.
Reapplying `up` uses the existing identities and credentials.

`qualify` performs these checks:

- A new IngestRun and its owned Job complete. Previous owned fixture flows are
  removed through the TAMS API; unexpected remaining flows stop qualification.
- A one-second H.264/AAC fixture is prepared by the released TAMSin image's
  FFmpeg, uploaded to an owned prefix, and read through a restricted S3 source.
- Authenticated API access, anonymous rejection, media reads and byte ranges work.
- Unchanged upstream browser tests exercise SSO, protected browsing, rejected
  browser writes and playback, including CORS and media credential separation.
  TLS verification stays enabled and required skipped tests fail qualification.
- Certificates are Ready; application, authentication, ingress and operator
  replicas occupy different workers. Allowed and denied clients exercise the
  Console NetworkPolicy.
- API/UI sampling covers the period before, during and after an ordinary worker
  drain. Missing overlap or failed requests fail the check. The drained worker
  is restored and media is read again afterwards.

Reports remain in the private environment directory. Browser credentials are
mounted read-only into the test container and removed afterwards. The container
receives neither OCI credentials nor the Docker socket. A successful drain
qualifies that disruption case; it does not prove regional or database failover.
API and authentication servers delay shutdown by five seconds for endpoint
withdrawal. Ingress accepts requests for 35 seconds while OCI withdraws its
backend, then allows ten seconds for active requests within a 60-second pod
termination budget.
Commands print the active deployment stage. Local check reports and browser build
logs are under `.local/reports/`; live qualification reports are under
`ENV_DIR/reports/`. A failed qualification stops that command and leaves the
environment running for investigation. Preserve its reports before a rerun
overwrites them, continue independent checks as needed, and monitor the budget
and cleanup deadline.

## Teardown and interruption

```console
task down ENV_DIR=.local/environment
```

`down` checks recorded identities, inspects live Kubernetes/Helm resources and
confirms deletion through the selected resources' protection annotations.
Local application marker files do not control removal. It finalises ingest and
the external storage registration before the TAMOSS instance while the operator
is present, removes platform releases,
and verifies load-balancer deletion before infrastructure teardown. It empties
only the owned bucket, including versions and multipart uploads, and removes
the composite and its database backups. Kind and provider credentials remain
until direct OCI inventory matches the baseline, including volumes and addresses.

Retry with the same directory after resolving a failure. Retain `identity.yaml`,
`tamoss-release.yaml`, `qualification.sha256`, `resources.yaml`, `owned-cloud.yaml`, baseline inventory and credentials until
cleanup is verified. The inventory files record identifiers and ownership; do
not edit them to bypass a mismatch. Operator removal is rendered from the
environment's recorded installation asset and does not need an installation
snapshot or the render-test cache. Teardown does not run the test suite.

For a temporary management interruption, stop and start the existing Kind
containers with native Docker commands. Do not delete them or create another
cluster with the same name. OKE continues independently; check public service
continuity during the interruption and Crossplane reconciliation after restart.
Live stop/start testing preserved the original management identity and resumed
reconciliation, with all 360 sampled API/UI requests returning HTTP 200.

### Manual cleanup after management state loss

Management-state restoration is outside this temporary environment's supported
lifecycle. If Kind state is lost, stop normal deployment operations and use the
retained identity and inventory records with the native OCI CLI or OCI console.

1. Confirm the tenancy, region and dedicated compartment against `identity.yaml`.
   Discover resources by the recorded deployment/composite UID tags and resource
   IDs. Compare with the baseline; names alone do not establish ownership.
2. Remove the owned load balancer, node pools and OKE cluster, then inspect
   retained boot/block volumes. Remove only identified environment resources.
3. Delete the owned PostgreSQL system and backups associated with its recorded
   database IDs. Empty the owned bucket's objects, versions and multipart
   uploads before deleting it.
4. Remove the reserved IP and networking in dependency order: subnets, route and
   security resources, gateways, then VCN. OCI must confirm each deletion.
5. Repeat every inventory category listed in
   [deploy/oci/inventory.yaml](deploy/oci/inventory.yaml), plus boot volumes in
   each configured availability domain. Compare the resulting IDs with the
   baseline before declaring cleanup complete or discarding credentials.

Never remove Crossplane finalisers as a substitute for cloud deletion. If the
retained identity evidence is insufficient, establish ownership before deleting
resources. Keep the qualification compartment itself.
