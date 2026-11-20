# Recovery

Run `mise exec -- bash` from the deployed checkout. Set `ENV_DIR` to the original deployment directory (default `.local/environment`). Keep the Kind containers, credentials and ownership records until OCI confirms cleanup. Clearing a finaliser or deleting a receipt can prevent a controller from verifying which resources it owns.

## Failed installation

`up` accepts one installation per environment. If it exits, controllers that received the seed can continue provisioning. Keep the environment intact while diagnosing it. To inspect Kind while it is running:

```bash
export ENV_DIR="${ENV_DIR:-.local/environment}"
kubectl --kubeconfig "$ENV_DIR/management.kubeconfig" -n tamoss-infra get tamossbootstrap,helmreleases,gitrepositories
kubectl --kubeconfig "$ENV_DIR/management.kubeconfig" -n tamoss-infra get events --sort-by=.lastTimestamp
```

| Symptom | Inspect |
| --- | --- |
| Preflight fails | OCI signing profile, pushed Git revision, Docker access and, for a private product source, GitHub deploy-key permissions |
| Bootstrap stalls in Kind | `TamossBootstrap` conditions, managed-resource events, provider health in `crossplane-system` and OCI work requests |
| OKE API times out | Workstation or VPN egress address against `adminCidrs` |
| OKE platform stalls | Kind's `oke-root` HelmRelease, then OKE's `tamoss-gitops` HelmRelease and `deployment-ready` Kustomization in `tamoss-infra` |
| PostgreSQL or bucket is pending | `TamossServices` and its managed resources in OKE, then OCI quota, worker placement and database work requests |
| Database bootstrap fails | OKE `tamoss-infra/tamoss-database-connection` HelmRelease and `auth/tamoss-database-init` Job. Check the database ID, hostname and CA. |
| Certificate or ingest fails | OKE Certificate events and public DNS/ports 80 and 443, or `IngestRun` conditions and its owned Job |

If Flux repeatedly reports an unknown ExternalSecret kind, first confirm the CRD is Established and OKE reports the ExternalSecrets Ready. If the health check still fails discovery, restart the OKE Flux controller with `kubectl --kubeconfig "$ENV_DIR/remote.kubeconfig" -n flux-system rollout restart deployment/kustomize-controller` and recheck the affected Kustomization.

After inspection, use `mise run down` with the same directory. This also handles an installation interrupted before OKE received access. Verify the final inventory before choosing a fresh directory for another installation.

## Interrupted teardown

Inspect `status.retirement` on `TamossBootstrap` in Kind and, while OKE is reachable, `TamossServices` in OKE:

```bash
kubectl --kubeconfig "$ENV_DIR/management.kubeconfig" -n tamoss-infra get tamossbootstrap -o yaml
kubectl --kubeconfig "$ENV_DIR/remote.kubeconfig" -n tamoss-infra get tamossservices -o yaml
```

Check the failing HelmRelease and Job events. Kind waits for the current deployment's retirement acknowledgement before revoking OKE access. Restore connectivity if the OKE API is unreachable. If a route table blocks VCN deletion, compare its VCN, deployment and composite tags, rules, subnet associations and the pre-deployment inventory. Remove an orphan only after confirming it belongs to this deployment, has no rules or attached subnets, and is separate from the Crossplane-managed table. Resume with `mise run down`.

### S3 credential recovery

Keep the `storage-identity` and `s3-credential-operation` ConfigMaps in Kind. A failed key-creation Job may already have created the key in OCI. Teardown matches the recorded user and attempt before revoking the key. If the outcome is ambiguous, use OCI Audit to establish whether creation succeeded. Leave the receipt and unrelated keys intact.

Recorded storage IAM resources use `Observe,Delete`. If `storageIdentityReady` is false, compare the observed user capabilities, membership and bucket policy with `spec.forProvider`. Have the account administrator repair drift against the recorded IDs.

### Recover a policy binding

If OCI returns `PolicyAlreadyExists` and the managed resource has no external name, inspect `Ready` and `LastAsyncOperation`. Set `POLICY` to the affected managed resource name. Using the original Kind kubeconfig, pause only that policy and wait for reconciliation to stop:

```bash
export KUBECONFIG="$ENV_DIR/management.kubeconfig"
resource=policy.identity.oci.m.upbound.io
kubectl -n tamoss-infra annotate "$resource" "$POLICY" crossplane.io/paused=true
kubectl -n tamoss-infra wait "$resource/$POLICY" --for='jsonpath={.status.conditions[?(@.type=="Synced")].reason}=ReconcilePaused' --timeout=180s
kubectl -n tamoss-infra get "$resource" "$POLICY" -o yaml
```

Record its UID and resource version. Let in-flight OCI requests finish. Verify that exactly one policy matches its expected compartment, name, deployment tag, statements and creation time using `oci iam policy list`, `oci iam policy get` and OCI Audit. Stop if the match is ambiguous or the resource already has a different binding.

Set `OCI_POLICY_ID` to the verified OCID and `RESOURCE_VERSION` to the inspected resource version. On the same managed resource, run:

```bash
kubectl -n tamoss-infra annotate "$resource" "$POLICY" crossplane.io/external-name="$OCI_POLICY_ID" --resource-version="$RESOURCE_VERSION"
kubectl -n tamoss-infra annotate "$resource" "$POLICY" crossplane.io/paused-
kubectl -n tamoss-infra wait "$resource/$POLICY" --for=condition=Ready --timeout=180s
kubectl -n tamoss-infra wait "$resource/$POLICY" --for=condition=Synced --timeout=180s
```

If the version check fails, reinspect the UID and binding before retrying. Verify the observed OCI policy ID before resuming teardown.

## Manual cleanup after losing the Kind cluster

`down` requires the original Kind state. If it is lost, use the OCI CLI or Console with the retained `identity.yaml` and inventory:

1. Confirm tenancy, region and compartment. Match resources by recorded OCID and deployment or composite UID tags. If ownership is uncertain, stop.
2. Remove the owned load balancer, node pools and OKE cluster. Inspect retained boot and block volumes in each configured availability domain.
3. Delete the owned PostgreSQL system and backups for its recorded ID. Empty the owned bucket, including object versions and multipart uploads, before deleting it.
4. Remove reserved IPs, subnets, route and security resources, gateways and the VCN in dependency order. Confirm each deletion in OCI.
5. Compare the remaining workload IDs against every category in the [OCI inventory](../deploy/oci/inventory.yaml). Account for deployment IAM, storage keys, persisted secrets and GitHub deploy keys. Preserve the compartment, retained Vault, encryption key and owner record.
