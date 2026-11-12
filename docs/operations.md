# Operations

[Overview](../README.md) | [Getting started](getting-started.md) | [Testing](testing.md) | [Architecture](architecture.md)

Run lifecycle commands from the repository root with `mise run`. For the native
diagnostic commands below, enter a tool-enabled shell with `mise exec -- bash`;
`exit` returns to your previous shell. Examples use
`.local/environment`; substitute your original environment directory throughout.
Kind owns the network, OKE, IAM and Vault resources throughout the demo; Crossplane
in OKE owns the PostgreSQL system and the media bucket. `up` stops Kind when the
deployment is ready, and `down` starts it again. Keep the stopped Kind cluster
until teardown has verified cleanup. Retain the deployed Git revision.

## Inspect the installation

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss tamoss -o json |
  yq '.spec | {"api": ("https://api." + .publicEndpoint.baseDomain), "ui": .publicEndpoint.uiURL, "auth": .auth.authentikBlueprints.issuerURL}'
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get tamossenvironments
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get managed
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get kustomization deployment-ready
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
| Preparation failure | Required settings, OCI profile, pushed Git revision and repository access |
| Crossplane providers unavailable | Provider health and events in Kind |
| Bootstrap installation stalled | Kind `tamoss-infra` GitRepository and HelmRelease conditions; Flux source/Helm controller logs |
| Bootstrap waiting | Kind `TamossBootstrap` status: `foundationReady`, `credentialsReady`, `bootstrapReady`, `infrastructureReady`, `runtimeAccessReady`; inspect child conditions and HelmReleases |
| Remote deployment failed | Kind `tamoss-infra` HelmRelease `oke-root`, then OKE `tamoss-infra` HelmRelease `tamoss-gitops` and Kustomization `deployment-ready`; inspect source, OKE access and HelmRelease readiness, then follow [failed-deployment cleanup](#clean-up-a-failed-deployment) |
| Root release waiting | Kind `tamoss-infra/oke-root` HelmRelease and the `tamoss-runtime` and `oke-bootstrap-facts` ConfigMaps; inspect infrastructure observations |
| Database or bucket not created | OKE `tamoss-infra` HelmReleases `oke-crossplane`, `oke-oci-family`, `oke-oci-services`, `tamoss-services-api` and `tamoss-services`; `TamossServices` status and its `PsqlDbSystem` and `Bucket` conditions; provider health in OKE `crossplane-system`; the `database-admin` Secret in `tamoss-infra` |
| Database connection waiting | OKE `tamoss-infra/tamoss-services` ConfigMap, published once the database is ready, then HelmRelease `tamoss-database-connection` |
| Infrastructure not Ready/Synced | Composite and managed-resource conditions, OCI work requests, quota, image/version compatibility and placement capacity |
| IAM `PolicyAlreadyExists` with no external-name | Follow [policy binding recovery](#recover-a-policy-binding) using the original managed resource and a verified OCI policy |
| OKE access timeout | API endpoint allowlist and current workstation/VPN egress address |
| Database bootstrap failure | `auth/tamoss-database-init` Job, database hostname/CA and Secret references |
| Pending certificate | Certificate events, public DNS and ports 80/443 |
| TAMOSS or ingest failure | Tamoss/IngestRun conditions, owned Job and operator logs |
| Teardown stopped | Recorded ownership, live deletion conditions and direct OCI inventory; retain Kind and credentials |

```bash
kubectl --kubeconfig .local/environment/management.kubeconfig -n crossplane-system get pods
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get events --sort-by=.lastTimestamp
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
| Final cloud inventory | `.local/environment/inventory-after/` |
| Recorded resource ownership | `.local/environment/resources.yaml`, `owned-cloud.yaml` |

## Clean up a failed deployment

`up` supports one installation attempt per deployment. If it fails, preserve the
original Kind and environment records, inspect the failure, then run teardown:

```bash
ENV_DIR=.local/environment mise run down
```

Confirm cleanup after teardown before choosing a fresh `ENV_DIR` and running `setup` for another attempt.
Keep the original inputs and private records until cleanup is verified.
Use the [access instructions](getting-started.md#access) to inspect a running
deployment and `qualify` to test it. Interrupted teardown resumes through `down`.

Flux and Crossplane continue reconciling if mise exits. Keep `up` running through
the OKE access submission; rerunning `up` cannot resume an installation.

If preparation failed before Kind accepted the seed, follow
[preparation cleanup](#interrupted-host-preparation) before starting again.
Do not delete a Kind cluster that has begun provisioning cloud resources.

Preserve `bootstrap.yaml`, kubeconfigs and the environment
identity through verified teardown. Run one lifecycle command per environment at
a time. Do not manually unpause a released root during operations or deletion.

During teardown, the instance HelmRelease is frozen and the bootstrap root is
released and paused before deleting its children. Keep it paused if cleanup fails.

Native OCI requests, Flux installation and readiness observations have bounded
timeouts. A failure stops the command and preserves the environment for diagnosis.
There is no OKE bootstrap Job or connection receipt in Kind. Inspect the root and
remote controllers with their native tools:

```bash
mise exec -- kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get tamossbootstrap
mise exec -- flux --kubeconfig .local/environment/management.kubeconfig get all --all-namespaces
```

This Kind-owned flow applies to new environments. Existing environments must retain their
recorded product commit for operations and teardown; bootstrap state is not migrated.

A failed `qualify` leaves the environment running. Preserve reports before a rerun
overwrites them and continue independent checks where appropriate. Remove the
environment explicitly with `down` when it is no longer needed.

## Native OCI CLI

mise installs the pinned OCI CLI into its isolated Python environment. Use the
selected local signing profile:

```bash
mise install --locked
export OCI_CLI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
export OCI_CLI_PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
mise exec -- oci os ns get
```

Expected: the Object Storage namespace. Commands use the selected local profile
and signing key. Host bootstrap and teardown share the same OCI kubeconfig path
and identity checks. This does not grant additional IAM access.

The S3 credential Job runs the pinned upstream OCI CLI and kubectl images selected
in `dependencies.yaml`. The project publishes no tooling image.

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

Use the retained installer and private environment records:

```bash
ENV_DIR=.local/environment mise run down
```

`down` verifies the original Kind identity, suspends reconciliation in Kind and
in OKE and releases the bootstrap's authority to recreate children. It removes
applications and their releases in OKE while the OKE API is available. Remote
access is revoked after workload cleanup.

TAMOSS finalises while its operator remains available. Teardown removes platform
releases and the load balancer and empties the owned bucket (including versions and
multipart uploads). It deletes the `TamossServices` composite in OKE and waits for
Crossplane there to remove the database and bucket, then deletes the remaining
infrastructure from Kind and the database backups. Kind and
provider credentials remain until direct OCI inventory confirms that the dedicated
compartment contains no workload resources.

| Deleted | Retained |
| --- | --- |
| Workloads, OKE/workers, load balancer, PostgreSQL/backups, media bucket, reserved IP, networking and runtime IAM grants, then Kind | Precreated compartment, retained Vault/key and owner record, source Git repository and local records |

After the cloud audit, teardown revokes the deployment's S3 key, verifies its
absence, deletes the generated storage policy, membership, group and user through Crossplane,
and verifies their absence through OCI. Unrelated keys block user deletion.
It schedules environment secrets for deletion.
A bounded Kubernetes Job waits for OCI to report `PENDING_DELETION` or `DELETED`;
a timeout retains Kind and the Job for diagnosis. `retained-foundation.yaml`
records the owner, Vault/key and scheduled deletion times. The compartment still
contains that foundation.

After the audit succeeds, the account administrator can retire run-owned keys and
temporary IAM prerequisites using [account retirement](../deploy/oci/README.md#retirement).
Keep access until deletion is confirmed. Retain the foundation's compartment and
owner access; local exported credentials remain your responsibility.

The source repository and upstream release artifacts remain available. The
per-deployment Git deploy key is revoked before Kind is removed.

### Interrupted teardown

Resolve the failure and repeat `mise run down` with the same directory. Preserve
`identity.yaml`, `tamoss-release.yaml`, `qualification.sha256`, `resources.yaml`,
`owned-cloud.yaml`, `storage-inventory.yaml`, the final inventory and credentials until cleanup completes.
Do not edit records to bypass mismatches or remove finalisers to simulate deletion.

Before any cloud providers or deployment composites were installed, `down` can
audit OCI without a foundation record. If provider
CRDs or deployment identities exist, it requires the original foundation record;
it does not infer that a partially started environment is empty.

## Retained management state

Keep the original Kind containers and private identity records intact. If Kind
has stopped, `down` starts and verifies that cluster; it does not create a replacement
with the same name. A failed API or identity check stops cleanup.

For inspection:

```bash
MANAGEMENT_NAME="tamoss-cp-$(yq -r .metadata.name .local/environment/environment.yaml)"
docker ps -a --filter "label=io.x-k8s.kind.cluster=$MANAGEMENT_NAME"
```

## Advanced recovery

These procedures are for a deployment that normal teardown cannot finish. Keep
the original Kind cluster and deployment directory throughout.

### Convergence and OKE access

`mise run up` accepts a fresh deployment directory. It stops Kind once the
deployment is ready, so the network, cluster, identity and Vault resources are
not reconciled again until `down` starts Kind. Flux and Crossplane in OKE keep
reconciling the database, bucket, platform and applications. OKE's `deployment-ready`
Kustomization checks application health; the host also checks the selected Git
commit, chart revision and current controller generations.

Kind reaches OKE with a ServiceAccount token that does not expire. It uses the
token for the `oke-root` release and for teardown. `down` revokes it after
workload cleanup. A revoked or fully torn-down deployment refuses a new token.

### Change settings

OKE reads its settings from two ConfigMaps in `tamoss-infra`,
`tamoss-gitops-values` and `tamoss-assets`, which the host renders from
`values.yaml` and applies during `up`. To change a setting that OKE reconciles,
such as the database shape or the certificate contact, edit
`.local/environment/values.yaml` and run:

```bash
mise run apply
```

`apply` does not need Kind. It applies the rendered settings to OKE, waits for
Flux there to take them and then waits for the deployment to be ready. It
refuses a change to the network, cluster, identity or Vault settings, which
belong to the resources `up` created, and a change to the TADOSS selection.
Run it from the deployed Git revision.

`apply` can return before a database change has finished: the database stays
ready while OCI updates it. Watch the change with:

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tamoss-infra get psqldbsystems
```

### Interrupted host preparation

The host records the selected release and prepares the Kind seed. Once
`identity.yaml` exists, `up` refuses another installation attempt. Preserve the
environment directory and inspect the failure before cleanup. Use `down` to
verify the dedicated compartment and remove any owned Kind, then choose a fresh
`ENV_DIR` and rerun `setup`.

Once Kind has accepted the seed, retain that Kind and use the normal
teardown path. If Kind exists but the initial apply failed, preserve it and inspect
the apply error before removing any identity or credential files.

### Operation recovery

Inspect remote bootstrap without exposing its credential:

```bash
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get kustomizations,helmreleases
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra describe kustomization deployment-ready
```

The OCI kubeconfig on the host remains available for observation and teardown.
Kind's separate ServiceAccount token stays valid until teardown deletes its
namespace on OKE. Do not manually resume retired
bootstrap declarations. `down` stops remote reconciliation before removing
applications and revokes any remaining bootstrap access. A repeated teardown
skips remote revocation once the current verified cloud inventory confirms that
the cluster is gone; a failed or missing inventory cannot establish its absence.

Inspect the failed host command, or the Job conditions and init-container logs,
before retrying. Job deadlines and backoff limits remain specific to each
operation; the common chart does not choose retry policy or manage the workflow.

| Operation | Interruption and retry behaviour |
| --- | --- |
| Kind `tamoss-infra/s3-credentials` | Native reconciliation consumes a staged or persisted response. A claimed attempt is never automatically repeated. Preserve the receipt and use [failed-deployment cleanup](#clean-up-a-failed-deployment) if installation fails. |
| Kind remote bootstrap | An interrupted installation requires teardown. Retain the original Kind and records; `down` stops remote bootstrap and revokes its access. |
| OKE `tamoss-infra/database-connection-<revision>` | Flux runs the Helm hook for the selected database/revision. Retrieval and validation precede publication; a stale identity or revision cannot overwrite the current ConfigMap. Preserve the failed Job for diagnosis and retry the owning HelmRelease after correcting the cause. |
| Kind `tamoss-infra/secret-retirement` | Repeat `mise run down` with the original directory and credentials. The Job only verifies deletion scheduling; it does not request deletion. Active or scheduling secrets keep verification incomplete. A failed inventory request cannot count as successful retirement. |

Do not delete identity receipts or clear finalisers to bypass a failed operation.
Database hostname/CA validation failures leave the previously published connection
data intact. Secret-retirement failure keeps Kind and its credentials available
for a later teardown attempt.

#### S3 credential recovery

The immutable `storage-identity` ConfigMap records the generated user, group,
membership and policy IDs. The `s3-credential-operation` ConfigMap records the deployment identity,
storage user, attempt and key ID. Preserve both and the original Kind cluster. The Job
claims the operation before calling OCI, with automatic API retries disabled.
An interruption after creation can lose the one-time secret response, so a
failed Job is not evidence that OCI created no key.

If installation fails, follow [failed-deployment cleanup](#clean-up-a-failed-deployment)
with the original directory. Teardown stops the owned Job, queries OCI for the
exact attempt's key and records its ID before revocation. Unrelated keys block
identity deletion. If the claim has no recorded ID and OCI cannot identify its
key, cleanup stops: retain the records and use OCI Audit to establish the creation
outcome. A timeout or empty list alone cannot prove that an in-flight create
failed. Do not clear the receipt to force a retry. Start a fresh deployment only
after cleanup is verified; `up` cannot resume the failed installation.

Recorded IAM resources use `Observe,Delete` to prevent replacement. If
`status.storageIdentityReady` becomes false, inspect their observed capabilities,
membership and bucket policy against `spec.forProvider`. These resources do not
repair drift automatically after recording. Restore the recorded configuration
through the account administrator; retain Kind and the ownership record if an
identity has been deleted. Do not replace the record or enable `Create` to bypass
that failure.

### Recover a policy binding

An OCI policy can exist even when its managed resource has no
`crossplane.io/external-name`. Repeated creation then fails with
`PolicyAlreadyExists`. Inspect `Ready` and `LastAsyncOperation` as well as
`Synced`; `Synced=True` alone does not establish successful creation.

Use the original Kind and environment records. Pause only the affected policy:

```bash
export KUBECONFIG=.local/environment/management.kubeconfig
POLICY="<policy-name>"
kubectl -n tamoss-infra describe policy.identity.oci.m.upbound.io "$POLICY"
kubectl -n tamoss-infra annotate policy.identity.oci.m.upbound.io "$POLICY" crossplane.io/paused=true
kubectl -n tamoss-infra wait policy.identity.oci.m.upbound.io "$POLICY" \
  --for='jsonpath={.status.conditions[?(@.type=="Synced")].reason}=ReconcilePaused' --timeout=180s
kubectl -n tamoss-infra get policy.identity.oci.m.upbound.io "$POLICY" -o yaml
```

Let any in-flight operation finish. Record the original UID and resource version.
Use `oci iam policy list`, `oci iam policy get` and OCI Audit to verify exactly
one cloud policy matches the expected name, compartment, deployment tag,
statements and creation time. Keep this evidence private. Stop if the match is
missing or ambiguous, or if the managed resource already has a different binding.

Restore the verified policy OCID on that same managed resource:

```bash
OCI_POLICY_ID="<verified-policy-OCID>"
RESOURCE_VERSION="<inspected-resource-version>"
kubectl -n tamoss-infra annotate policy.identity.oci.m.upbound.io "$POLICY" \
  crossplane.io/external-name="$OCI_POLICY_ID" --resource-version="$RESOURCE_VERSION"
kubectl -n tamoss-infra annotate policy.identity.oci.m.upbound.io "$POLICY" crossplane.io/paused-
kubectl -n tamoss-infra wait policy.identity.oci.m.upbound.io "$POLICY" --for=condition=Ready --timeout=180s
kubectl -n tamoss-infra wait policy.identity.oci.m.upbound.io "$POLICY" --for=condition=Synced --timeout=180s
```

The resource-version precondition rejects a concurrent change. Reinspect the
original resource before retrying a rejected annotation. Verify its observed
policy ID matches the restored binding, then resume the normal workflow.

This uses Crossplane's [external-resource binding](https://docs.crossplane.io/latest/guides/import-existing-resources/)
and Kubernetes' [conditional annotation update](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_annotate/).
Preserve the policy, managed resource and finalisers throughout recovery. This is
an operator recovery procedure for the [reported upstream defect](https://github.com/crossplane/upjet/issues/632),
not an automatic build step or proof that unattended installation is reliable.

### Manual cleanup after management state loss

Management-state restoration is outside this environment's supported lifecycle.
If Kind state is lost, stop normal deployment operations. Use retained identity
and inventory records with the native OCI CLI or Console:

1. Confirm tenancy, region and compartment against `identity.yaml`. Discover
   resources by recorded deployment/composite UID tags and IDs; compare with the
   recorded deployment tags and provider bindings. Names alone do not establish ownership.
2. Remove the owned load balancer, node pools and OKE cluster, then inspect
   retained boot/block volumes. Remove only identified environment resources.
3. Delete the owned PostgreSQL system and backups associated with its recorded
   database IDs. Empty the owned bucket's objects, versions and multipart uploads
   before deleting it.
4. Remove the reserved IP and networking in dependency order: subnets, route and
   security resources, gateways, then VCN. OCI must confirm each deletion.
5. Repeat every category in [the OCI inventory](../deploy/oci/inventory.yaml),
   including boot volumes in each configured availability domain. Compare IDs
   for remaining workload resources before declaring cleanup complete or discarding credentials.

Keep the precreated compartment until its owner retires it. If ownership evidence
is insufficient, establish ownership before deletion. Also account for runtime IAM, persisted secrets and the retained Vault/key with
their owner; a replacement Kind does not restore their management state.
