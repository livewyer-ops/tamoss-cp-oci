# Operations

[Overview](../README.md) | [Getting started](getting-started.md) | [Testing](testing.md) | [Architecture](architecture.md)

Run commands from the repository root with Aqua's tools on `PATH`. Examples use
`.local/environment`; substitute your original environment directory throughout.
Use the matching environment Git checkout (`CHECKOUT`, default `.local/gitops`).
Kind stays stopped during ordinary operation; OKE owns ongoing reconciliation.

## Inspect the installation

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss tamoss -o json |
  yq '.spec | {"api": ("https://api." + .publicEndpoint.baseDomain), "ui": .publicEndpoint.uiURL, "auth": .auth.authentikBlueprints.issuerURL}'
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tamoss-infra get tamossenvironments
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tamoss-infra get managed
kubectl --kubeconfig .local/environment/remote.kubeconfig get nodes
kubectl --kubeconfig .local/environment/remote.kubeconfig get pods -A
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss,storagebackends,ingestruns
kubectl --kubeconfig .local/environment/remote.kubeconfig get certificates -A
```

Expected: three Ready workers, infrastructure Ready and managed resources Synced,
TAMOSS and its external StorageBackend Ready, and public certificates Ready.
Infrastructure readiness alone does not establish successful ingest. See
[first login](getting-started.md#access) and [qualification](testing.md#deployed-qualification).

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
| Preflight rejection | Placeholder inputs, matching OCI region/profile, file permissions, current UTC cost date and cleanup window |
| Crossplane providers unavailable | Provider health and events: Kind during bootstrap, OKE after handover |
| Bootstrap waiting | Kind `TamossBootstrap` status: `foundationReady`, `credentialsReady`, `infrastructureReady`; inspect the foundation and `database-admin` ExternalSecret |
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

## Retry a failed deployment

Resolve the reported problem, preserve its evidence, then repeat with the original
inputs and state:

```bash
task up ENV_DIR=.local/environment CHECKOUT=.local/gitops
```

Run `task check` first if configuration or dependencies changed. `up` verifies and
prepares its deployment assets independently; a previous check cache is not required.
Unchanged repeats reuse identities and persisted credentials. After handover,
`up` reconciles the current published Git selection and keeps Kind stopped. It
resumes an interrupted promotion only when the checkout matches the published
configuration or its ownership-policy change. Resolve input/ownership mismatches
and missing established credentials before retrying. Once teardown starts, use
`down` to finish it.

During initial provisioning, the root and its children continue reconciling if
Task exits. Resume `up` to complete any remaining credential import, remote seed
or handover. Preserve `bootstrap.yaml` and the recorded bootstrap UID alongside
the existing environment identity. Do not manually unpause a released root during
operations or deletion; `down` verifies and preserves the paused boundary.

A failed `qualify` leaves the environment running. Preserve reports before a rerun
overwrites them, continue independent checks where appropriate, and keep enough
time and money for cleanup. If the cleanup window is all that remains, run `down`.

## Release selection

Initial deployment uses the repository's verified TAMOSS lock. Afterwards, Git
owns the release selection. `qualify` verifies and records the current selection
while preserving the initial release record. `down` returns current Git/live
configuration to Kind for deletion.

Follow the [release-change procedure](../deploy/gitops/README.md#release-changes).
A supported upgrade still needs live qualification. A Git revert alone does not
establish that database migrations can be reversed.

## Native OCI CLI

The repository pins OCI CLI in [Compose](../deploy/oci/compose.yaml). In the shell
used for read-only inspection, select the appropriate existing OCI profile and
prepare its config/key mounts:

```bash
export OCI_CONFIG="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
export OCI_PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
export OCI_KEY_FILE="$(yq -p=ini -oy -r '(. * (.[strenv(OCI_PROFILE)] // {})).key_file' "$OCI_CONFIG")"
export OCI_UID="$(id -u)" OCI_GID="$(id -g)"
docker compose -f deploy/oci/compose.yaml run --rm -T oci os ns get
```

Expected: the Object Storage namespace. The container mounts only the selected
config and signing key, read-only. This does not grant additional IAM access.

## Posted billing

Use a profile allowed to read tenancy billing. Oracle requires
`read usage-report in tenancy`; the scoped provisioner may not have that access.
See [Oracle Cost Analysis](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costanalysisoverview.htm).
Select that profile before the [CLI setup](#native-oci-cli).

Enter the start and exclusive end dates at UTC midnight for the period to inspect:

```bash
read -r -p 'Usage start (YYYY-MM-DDT00:00:00Z): ' COST_START
read -r -p 'Usage end, exclusive (YYYY-MM-DDT00:00:00Z): ' COST_END
COST_TENANCY="$(yq -p=ini -oy -r '(. * (.[strenv(OCI_PROFILE)] // {})).tenancy' "$OCI_CONFIG")"
docker compose -f deploy/oci/compose.yaml run --rm -T oci \
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
The USD values in `cost.yaml` are planning inputs; do not relabel an API amount
as USD. Oracle says data can take up to 48 hours to appear in
[Cost Analysis](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costanalysisoverview.htm).
Missing recent usage does not prove zero cost, and posted usage is not a final
invoice or a live resource inventory.

## Destroy the environment

**Destruction deletes managed application data**, including media, the database
and its backups. Keep the original environment directory and credentials:

```bash
task down ENV_DIR=.local/environment CHECKOUT=.local/gitops
```

`down` starts the original Kind and waits for API readiness before checking its
identity. It verifies the published environment checkout, freezes Flux, quiesces
OKE providers and revokes their write grants. Current configuration and exact
provider bindings return to Kind before it receives deletion authority.

TAMOSS finalises while its operator remains available. Teardown removes platform
releases and the load balancer, empties the owned bucket (including versions and
multipart uploads), and deletes infrastructure and database backups. Kind and
provider credentials remain until direct OCI inventory matches the baseline.

| Deleted | Retained |
| --- | --- |
| Workloads, OKE/workers, load balancer, PostgreSQL/backups, media bucket, reserved IP, networking and runtime IAM grants, then Kind | Precreated compartment, retained Vault/key and owner record, private environment Git configuration and local records |

Environment secrets are scheduled for deletion. A bounded Kubernetes Job waits
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

`up` stops original Kind after verified handover. Keep those containers and the
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
