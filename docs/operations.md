# Operations

[Overview](../README.md) | [Getting started](getting-started.md) | [Testing](testing.md) | [Architecture](architecture.md)

Run commands from the repository root with Aqua's tools on `PATH`. Examples use
`.local/environment`; substitute your original environment directory throughout.
Quick deployments keep Kind as the infrastructure writer. After GitOps handover,
use the matching environment Git checkout (`CHECKOUT`, default `.local/gitops`);
Kind stays stopped while OKE owns ongoing reconciliation.

## Inspect the installation

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss tamoss -o json |
  yq '.spec | {"api": ("https://api." + .publicEndpoint.baseDomain), "ui": .publicEndpoint.uiURL, "auth": .auth.authentikBlueprints.issuerURL}'
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tamoss-infra get tamossenvironments
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tamoss-infra get managed
kubectl --kubeconfig .local/environment/remote.kubeconfig -n flux-system get kustomization deployment-ready
kubectl --kubeconfig .local/environment/remote.kubeconfig get nodes
kubectl --kubeconfig .local/environment/remote.kubeconfig get pods -A
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss,storagebackends,ingestruns
kubectl --kubeconfig .local/environment/remote.kubeconfig get certificates -A
```

Expected: three Ready workers, infrastructure Ready and managed resources Synced,
TAMOSS and its external StorageBackend Ready, and public certificates Ready.
Infrastructure readiness alone does not establish successful ingest. See
[first login](getting-started.md#access) and [qualification](testing.md#deployed-qualification).

If `deployment-ready` is not Ready, describe that Kustomization for the failing
dependency, then inspect the named resource's conditions. Flux retries through
its normal reconciliation intervals.

## First API request

Read the operator's resolved API-token Secret into a private curl header file:

```bash
umask 077
install -d -m 700 .local/environment/access
install -m 600 /dev/null .local/environment/access/api-header
TOKEN_SECRET="$(kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams \
  get tamoss tamoss -o jsonpath='{.status.resolved.generatedSecrets.apiToken}')"
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get secret "$TOKEN_SECRET" -o json |
  yq -p=json -r '"Authorization: Bearer " + (.data.TAMOSS_API_TOKEN | @base64d)' \
  > .local/environment/access/api-header
API_URL="https://api.$(kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss tamoss -o jsonpath='{.spec.publicEndpoint.baseDomain}')"
curl --proto '=https' --fail --silent --show-error --connect-timeout 10 --max-time 30 \
  --header @.local/environment/access/api-header "$API_URL/flows"
rm .local/environment/access/api-header
unset TOKEN_SECRET API_URL
```

Expected: HTTP 200 with a JSON collection of flows. The header file keeps the
token out of process arguments. Remove it after use, including after an interrupted
request. Keep shell tracing disabled and credential values out of logs.

## Diagnose failures

Commands print their active stage. Inspect the corresponding controller or resource:

| Stage or symptom | Check |
| --- | --- |
| Preflight rejection | Placeholder settings, OCI discovery, published product/public package access, file permissions and recorded-input consistency |
| Crossplane providers unavailable | Provider health and events: Kind during bootstrap, OKE after handover |
| Bootstrap installation stalled | Kind `tamoss-infra` GitRepository, HelmChart and HelmRelease conditions; Flux source/Helm controller logs |
| Bootstrap waiting | Kind `TamossBootstrap` status: `foundationReady`, `credentialsReady`, `bootstrapReady`, `infrastructureReady`, `runtimeAccessReady`, `bindingsReady`, `remoteBootstrapPhase`; inspect child conditions and HelmReleases |
| OKE Flux seed failed | Kind `tamoss-infra/oke-bootstrap` Job and init-container logs; preserve the Job and `oke-connection` Secret |
| Adoption waiting | OKE `tamoss-infra/adoption-bindings` ExternalSecret and Kustomization; compare persisted identity with the original Kind records |
| Runtime waiting | OKE `tamoss-infra/runtime` Kustomization and `tamoss-runtime` ConfigMap; inspect infrastructure observations |
| Infrastructure not Ready/Synced | Composite and managed-resource conditions, OCI work requests, quota, image/version compatibility and placement capacity |
| OKE access timeout | API endpoint allowlist and current workstation/VPN egress address |
| Database bootstrap failure | `auth/tamoss-database-init` Job, database hostname/CA and Secret references |
| Pending certificate | Certificate events, public DNS and ports 80/443 |
| TAMOSS or ingest failure | Tamoss/IngestRun conditions, owned Job and operator logs |
| Teardown stopped | Recorded ownership, live deletion conditions and direct OCI inventory; retain Kind and credentials |

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n crossplane-system get pods
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tamoss-infra get events --sort-by=.lastTimestamp
kubectl --kubeconfig .local/environment/remote.kubeconfig -n auth describe job tamoss-database-init
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams describe tamoss tamoss
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams describe ingestrun qualification
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tamoss-system logs deployment/operator-controller-manager --tail=100
```

Treat diagnostic output as private and redact it before sharing. Report locations:

| Output | Location |
| --- | --- |
| Local checks and browser build logs | `.local/reports/` |
| Live ingest, placement, network, browser and availability reports | `.local/environment/reports/` |
| Cloud baseline and subsequent inventory | `.local/environment/inventory-before/`, other `inventory-*` directories |
| Recorded resource ownership | `.local/environment/resources.yaml`, `owned-cloud.yaml` |

## Operational Job recovery

Inspect the Job conditions and failed init-container logs before retrying the
owning command. Deadlines and backoff limits remain specific to each operation;
the common chart does not choose retry policy or manage the workflow.

| Job | Interruption and retry behaviour |
| --- | --- |
| Kind `tamoss-infra/oke-bootstrap` | Preserve its `oke-connection` Secret and original cluster. Repeat `task up` with the same inputs. Identity checks reject a different target; the durable completion receipt prevents reseeding a completed or released bootstrap. |
| OKE `auth/database-connection-<revision>` | Flux runs the Helm hook for the selected database/revision. Retrieval and validation precede publication; a stale identity or revision cannot overwrite the current ConfigMap. Preserve the failed Job for diagnosis and retry the owning HelmRelease after correcting the cause. |
| Kind `tamoss-infra/secret-retirement` | Repeat `task down` with the original directory and credentials. The Job only verifies deletion scheduling; it does not request deletion. Active or scheduling secrets keep verification incomplete. A failed inventory request cannot count as successful retirement. |

Do not delete identity receipts or clear finalisers to bypass a failed operation.
Database hostname/CA validation failures leave the previously published connection
data intact. Secret-retirement failure keeps Kind and its credentials available
for a later teardown attempt.

## Convergence and handover

`task up` completes deployment with Kind running and owning infrastructure; OKE
Crossplane observes the same resources. `task handover` attaches the environment
repository, persists its SSH deploy key, checks readiness and transfers ownership before
stopping Kind. Flux already manages applications in both states.

```bash
task up ENV_DIR=.local/environment
task handover ENV_DIR=.local/environment CHECKOUT=.local/gitops
```

Repeating `up` after deployment observes readiness once without changing ownership.
Repeating completed `handover` observes readiness once without restarting Kind or
publishing another commit. `qualify` works in either state. `down` also supports
cleanup before handover and after an interrupted transfer.
Keep the host checkout at the product commit recorded in `product.yaml`, or
selected in environment Git after handover;
handover rejects a different revision before changing ownership.

| Stage after remote seeding | Native actions |
| --- | --- |
| Initial convergence (`up`) | Observe bootstrap readiness, record bindings and inventory, then check deployment/public TLS readiness and OKE managed resources |
| Attach Git | Create/connect a private repository, publish the shared configuration, run native Flux bootstrap and persist its deploy key through Vault/ESO |
| Begin transfer | Verify the published deployment revision and health; an unpublished ownership-only change is allowed on retry |
| Verify adoption | Read and compare both control planes' resource identities and configuration |
| Quiesce Kind | Freeze the instance HelmRelease, release and pause the bootstrap, set infrastructure to Observe, and wait for managed resources to acknowledge their pause |
| Enable OKE ownership | Refresh both inventories, verify Kind has stopped writing, enable runtime IAM writes, and commit/push the promotion to the environment repository |
| Verify promotion | Observe the published environment revision, product revision, chart generation and deployment health through Chainsaw |
| Complete handover | Refresh both inventories, verify ownership and OKE managed-resource readiness, stop the original Kind containers, and record completion |

The inventory comparisons occur before quiescing, before enabling OKE writes and
before stopping Kind. Readiness observations do not trigger Flux reconciliation.
A failed promotion observation leaves handover incomplete and preserves the state for retry.
Teardown retains its binding-delivery waits because the bootstrap is paused then.

## Retry a failed deployment

Resolve the reported problem, preserve its evidence, then repeat with the original
inputs and state:

```bash
task up ENV_DIR=.local/environment
```

Run `task check` first if configuration or dependencies changed. `up` verifies and
prepares its deployment assets independently; a previous check cache is not required.
Unchanged repeats reuse identities and persisted credentials. After handover,
`up` observes the current published Git selection and keeps Kind stopped. Resume
an interrupted transfer with `task handover` using the same inputs. It accepts
the published configuration or its pending ownership-policy change; `up` rejects
unpublished changes and directs a pending transfer back to `handover`. Resolve input/ownership mismatches
and missing established credentials before retrying. Once teardown starts, use
`down` to finish it.

During initial provisioning, Flux and Crossplane continue reconciling if
Task exits. After credential retirement, Kind's `oke-bootstrap` Job can retrieve
the remote connection, install Flux and seed the deployment without the Task process.
Resume `up` to observe deployment completion, then run `handover` separately. Preserve
`bootstrap.yaml`, `management-values.yaml` and the recorded
bootstrap UID alongside the existing environment identity. Do not manually unpause a released root during
operations or deletion; `down` verifies and preserves the paused boundary.
Keep `tamoss-bootstrap-instance` suspended after handover. Restarting Kind must
not reinstall its original bootstrap intent. Teardown refreshes controller/API
releases from current Git while leaving that instance suspended.

The Job allows six retries and at most thirty minutes per attempt. A repeat `up`
archives a terminal failure's Job, logs and events before replacing that original Job.
An active, completed or released bootstrap is never replaced by this retry.
Do not delete `oke-connection`: its completion record prevents replay, and its
cluster identity prevents a retry seeding a different cluster. Inspect progress
without exposing the connection data:

```bash
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get tamossbootstrap
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get job oke-bootstrap
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra logs job/oke-bootstrap --all-containers=true
```

The new Job contract applies to new environments. Use an existing environment's
recorded product commit for its operations and teardown.

A failed `qualify` leaves the environment running. Preserve reports before a rerun
overwrites them and continue independent checks where appropriate. Remove the
environment explicitly with `down` when it is no longer needed.

## Release selection

Initial deployment uses the repository's verified TAMOSS lock. Afterwards, Git
owns the release selection. `qualify` verifies and records the current selection
while preserving the initial release record. `down` returns current Git/live
configuration to Kind for deletion.

Follow the [release-change procedure](../deploy/gitops/README.md#release-changes).
A supported upgrade still needs live qualification. A Git revert alone does not
establish that database migrations can be reversed.

## Native OCI CLI

Aqua supplies `uv`; install the OCI CLI version recorded in `dependencies.yaml`
into its isolated Python environment:

```bash
uv tool install --python 3.12 "oci-cli==$(yq -r .oci.version dependencies.yaml)"
export PATH="$(aqua root-dir)/bin:$(uv tool dir --bin):$PATH"
export OCI_CLI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
export OCI_CLI_PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
oci os ns get
```

Expected: the Object Storage namespace. Commands use the selected local profile
and signing key. The bootstrap Job mounts its Kind-held key read-only and uses
the same pinned OCI CLI version. This does not grant additional IAM access.

The Job's [tooling image](../deploy/oke-bootstrap/Dockerfile) contains the pinned
OCI CLI, Flux, kubectl and yq. To change its tools, update the selections in
`dependencies.yaml` and run the [publication workflow](../.github/workflows/bootstrap-tools.yaml)
on the product repository's default branch. The workflow uses `GITHUB_TOKEN` to
publish and verify public package ownership, then checks anonymous access.
Record the published digest in `bootstrapTools.image` before selecting that
product commit for a new environment. No deployment registry credential is needed.

## Posted billing

Use a profile allowed to read tenancy billing. Oracle requires
`read usage-report in tenancy`; the scoped provisioner may not have that access.
See [Oracle Cost Analysis](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costanalysisoverview.htm).
Select that profile before the [CLI setup](#native-oci-cli).

Enter the start and exclusive end dates at UTC midnight for the period to inspect:

```bash
read -r -p 'Usage start (YYYY-MM-DDT00:00:00Z): ' COST_START
read -r -p 'Usage end, exclusive (YYYY-MM-DDT00:00:00Z): ' COST_END
COST_TENANCY="$(yq -p=ini -oy -r '(. * (.[strenv(OCI_CLI_PROFILE)] // {})).tenancy' "$OCI_CLI_CONFIG_FILE")"
oci \
  usage-api usage-summary request-summarized-usages \
  --tenant-id "$COST_TENANCY" \
  --time-usage-started "$COST_START" --time-usage-ended "$COST_END" \
  --granularity DAILY --query-type COST --is-aggregate-by-time true \
  --group-by '["compartmentId","compartmentName","currency"]' \
  --compartment-depth 6 --limit 1000
```

Read `computed-amount`, `currency` and `is-forecast` from each item. This request
does not request a forecast; check that returned items have `is-forecast: false`.
It covers the whole tenancy: use the recorded compartment IDs to attribute project
charges. Include every page if `opc-next-page` is present, repeating the command
with `--page '<returned token>'`. Grouping by `currency` alone instead returns
the tenancy total per currency for reconciliation.

Report posted amounts in their returned currency, with the query period and time.
Do not relabel an API amount as another currency. Oracle says data can take up to 48 hours to appear in
[Cost Analysis](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costanalysisoverview.htm).
Missing recent usage does not prove zero cost, and posted usage is not a final
invoice or a live resource inventory.

## Destroy the environment

**Destruction deletes managed application data**, including media, the database
and its backups. Keep the original environment directory and credentials.

Run from the product commit recorded in `product.yaml`, or selected by
`tamoss-product` in the environment repository after handover. If the product checkout has moved, save local edits and check out
that commit before running `down`. Ownership return rejects a different product
commit before freezing Flux or deleting cloud resources.

```bash
task down ENV_DIR=.local/environment CHECKOUT=.local/gitops
```

`down` starts the original Kind and waits for API readiness before checking its
identity. Quick deployments already have Kind ownership and skip Git operations.
For Git-owned deployments, it verifies the published checkout, freezes Flux,
quiesces OKE providers and revokes their write grants. Current Git configuration
and exact Vault bindings return to Kind before it receives deletion authority.

TAMOSS finalises while its operator remains available. Teardown removes platform
releases and the load balancer, empties the owned bucket (including versions and
multipart uploads), and deletes infrastructure and database backups. Kind and
provider credentials remain until direct OCI inventory matches the baseline.

| Deleted | Retained |
| --- | --- |
| Workloads, OKE/workers, load balancer, PostgreSQL/backups, media bucket, reserved IP, networking and runtime IAM grants, then Kind | Precreated compartment, retained Vault/key and owner record, private environment Git configuration and local records |

After the cloud audit, teardown retires the binding PushSecret and schedules
environment secrets for deletion. A bounded Kubernetes Job waits
for OCI to report `PENDING_DELETION` or `DELETED`; a timeout retains Kind and the
Job for diagnosis. `retained-foundation.yaml` records the owner, Vault/key and
scheduled deletion times. The compartment still contains that foundation.

After the audit succeeds, the account administrator can retire run-owned keys and
temporary IAM prerequisites using [account retirement](../deploy/oci/README.md#retirement).
Keep access until deletion is confirmed. Retain the foundation's compartment and
owner access; local exported credentials remain your responsibility.

### Interrupted teardown

Resolve the failure and repeat `task down` with the same directory. Preserve
`identity.yaml`, `tamoss-release.yaml`, `qualification.sha256`, `resources.yaml`,
`owned-cloud.yaml`, the baseline inventory and credentials until cleanup completes.
Do not edit records to bypass mismatches or remove finalisers to simulate deletion.

## Retained management state

`handover` stops original Kind after verified transfer. Keep those containers and the
private identity records intact; do not create a replacement cluster with the
same name. `down` starts and verifies the original cluster automatically. A
failed API readiness or identity check stops the operation without deleting it.

For manual inspection, identify the original containers:

```bash
MANAGEMENT_NAME="tamoss-cp-$(yq -r .metadata.name .local/environment/environment.yaml)"
docker ps -a --filter "label=io.x-k8s.kind.cluster=$MANAGEMENT_NAME"
```

Keep Kind's non-writing configuration after handover. Operational changes belong
in Git and reconcile on OKE while Kind is stopped.

## Manual cleanup after management state loss

Management-state restoration is outside this environment's supported lifecycle.
If Kind state is lost, stop normal deployment operations. Use retained identity
and inventory records with the native OCI CLI or Console:

1. Confirm tenancy, region and compartment against `identity.yaml`. Discover
   resources by recorded deployment/composite UID tags and IDs; compare with the
   baseline. Names alone do not establish ownership.
2. Remove the owned load balancer, node pools and OKE cluster, then inspect
   retained boot/block volumes. Remove only identified environment resources.
3. Delete the owned PostgreSQL system and backups associated with its recorded
   database IDs. Empty the owned bucket's objects, versions and multipart uploads
   before deleting it.
4. Remove the reserved IP and networking in dependency order: subnets, route and
   security resources, gateways, then VCN. OCI must confirm each deletion.
5. Repeat every category in [the OCI inventory](../deploy/oci/inventory.yaml),
   including boot volumes in each configured availability domain. Compare IDs
   with the baseline before declaring cleanup complete or discarding credentials.

Keep the precreated compartment until its owner retires it. If ownership evidence
is insufficient, establish ownership before deletion. For a GitOps deployment,
also account for runtime IAM, persisted secrets and the retained Vault/key with
their owner; a replacement Kind does not restore their management state.
