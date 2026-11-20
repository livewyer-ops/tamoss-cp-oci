# TADOSS on OKE

TADOSS stores timed events linked to TAMOSS media through a `tams://` source identifier. It shares OKE, PostgreSQL, Authentik and ingress with TAMOSS, and uses its own `tads` namespace, database role and OAuth client. The [release lock](release.yaml) selects the operator.

## Enable TADOSS

Before `mise run up`, set this in the deployment's `values.yaml`:

```yaml
tadoss:
  enabled: true
```

For an existing installation, [hand settings over to Git](../../docs/operations.md#keep-settings-in-an-environment-repository) and make the same change in the `tamoss-gitops-values` ConfigMap in `settings.yaml`. Wait for Flux to apply that commit.

Enter `mise exec -- bash` and check OKE:

```bash
export KUBECONFIG="${ENV_DIR:-.local/environment}/remote.kubeconfig"
kubectl -n tamoss-infra get kustomization tadoss
kubectl -n tads get tadoss,pods,ingress,certificate
```

Expect two Ready API replicas, two Ready workers and a Ready certificate. If OAuth configuration stalls, inspect `kubectl -n auth logs -l job-name=tadoss-authentik-blueprint --prefix`.

## API access

The API is at `https://tads.<hyphenated-public-IP>.sslip.io`. Request a token from Authentik's `/application/o/token/` endpoint using the `client_credentials` grant and the `tadoss-<deployment-id>` client. Select `tads-api/read`, `tads-api/write` or `tads-api/delete` for the operation. The client secret is in Vault and the `auth/tadoss-oauth` Secret.

## Verification and removal

On a dedicated environment, [run qualification](../../docs/testing.md#deployed-qualification) to verify that timed events reference an ingested source and survive pod replacement. To remove TADOSS and its data, use [full environment teardown](../../docs/operations.md#destroy-the-environment). Standalone uninstall and in-place upgrades are unqualified.
