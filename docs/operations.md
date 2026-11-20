# Operations

Run commands from the deployed Git revision. Use one lifecycle command at a time per environment. For the examples below, open a shell with the pinned tools and select your original environment:

```bash
mise exec -- bash
export ENV_DIR="${ENV_DIR:-.local/environment}"
export KUBECONFIG="$ENV_DIR/remote.kubeconfig"
```

## Inspect the installation

```bash
kubectl get nodes
kubectl -n tams get tamoss,storagebackends,ingestruns
kubectl get certificates -A
kubectl -n tamoss-infra describe kustomization deployment-ready
```

Expect three Ready workers, a Ready TAMOSS instance and StorageBackend, and Ready public certificates. If `deployment-ready` is waiting, inspect the dependency named in its conditions. For controller errors, see [Recovery](recovery.md).

To find the UI URL again:

```bash
kubectl -n tams get tamoss tamoss -o jsonpath='{.spec.publicEndpoint.uiURL}{"\n"}'
```

If you removed the initial login file and the bootstrap password is still in use, recreate it privately:

```bash
install -d -m 700 "$ENV_DIR/access"
install -m 600 /dev/null "$ENV_DIR/access/ui-login.json"
kubectl -n auth get secret authentik -o json |
  yq -p=json -o=json '.data | {"username": (.AUTHENTIK_BOOTSTRAP_USERNAME | @base64d), "password": (.AUTHENTIK_BOOTSTRAP_PASSWORD | @base64d)}' > "$ENV_DIR/access/ui-login.json"
```

## First API request

Read the API token into a private header file, then request the flows collection. Keep shell tracing disabled. The subshell removes the header file when it exits.

```bash
(
  set -euo pipefail
  umask 077
  header=$(mktemp "$ENV_DIR/api-header.XXXXXX")
  trap 'rm -f "$header"' EXIT
  secret=$(kubectl -n tams get tamoss tamoss -o jsonpath='{.status.resolved.generatedSecrets.apiToken}')
  kubectl -n tams get secret "$secret" -o json |
    yq -p=json -r '"Authorization: Bearer " + (.data.TAMOSS_API_TOKEN | @base64d)' > "$header"
  domain=$(kubectl -n tams get tamoss tamoss -o jsonpath='{.spec.publicEndpoint.baseDomain}')
  curl --proto '=https' --fail --silent --show-error --max-time 30 --header "@$header" "https://api.$domain/flows"
)
```

Expect HTTP 200 and a JSON collection. An empty collection is valid before ingest.

## Change settings

Before Git handover, edit `$ENV_DIR/values.yaml` and run `mise run apply`. For example, change the certificate contact or database backup retention. OKE applies the settings while Kind stays stopped. To follow a database change that OCI is still applying, run `kubectl -n tamoss-infra get psqldbsystems`.

`apply` rejects changes to the original network, OKE cluster, identity, Vault and TADOSS selection.

### Keep settings in an environment repository

Create an empty private GitHub repository. Sign in to the GitHub CLI with permission to push commits and manage its deploy keys, then run:

```bash
mise run handover --repository OWNER/NAME
kubectl -n tamoss-infra get kustomization tamoss-environment -o jsonpath='{.status.lastAppliedRevision}{"\n"}'
```

The first commit on `main` adopts the two live ConfigMaps, `tamoss-gitops-values` and `tamoss-assets`. Handover returns when Flux in OKE has applied that commit. All later settings changes go through `settings.yaml` in that repository. The deployment cannot switch back to `apply`. Keep the deployment ID, region and compartment unchanged.

To enable [TADOSS](../deploy/tadoss/README.md), edit the embedded `values.yaml` in `tamoss-gitops-values`, change `tadoss.enabled` to `true`, commit and push. Check that `lastAppliedRevision` matches the new commit and that `kubectl -n tamoss-infra get kustomization tadoss` reports Ready.

## Destroy the environment

**Teardown permanently deletes media objects and versions, PostgreSQL data and its backups.** Keep the original Kind cluster, environment directory, checkout and credentials available. Run:

```bash
mise run down
```

`down` restarts Kind. OKE removes the applications, load balancer, database and bucket. Kind then removes the workers, cluster, network and deployment IAM. After verifying OCI inventory, the host revokes deploy keys and removes Kind. If interrupted, rerun `down` from the same directory. See [interrupted teardown](recovery.md#interrupted-teardown) if progress stops.

Review `$ENV_DIR/inventory-after/` and `$ENV_DIR/retained-foundation.yaml`. The compartment, Vault, encryption key, Git repositories and local records remain. Keep the foundation ownership record. An administrator can then [retire the provisioner](../deploy/oci/README.md#retirement).

### Manual cleanup after losing the Kind cluster

A replacement cluster cannot recover the original infrastructure state. Use the [manual cleanup procedure](recovery.md#manual-cleanup-after-losing-the-kind-cluster) to verify ownership before deleting anything.
