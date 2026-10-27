# TADOSS on the shared platform

This integration consumes the published [TADOSS release](https://github.com/livewyer-ops/tadoss/releases)
without modifying TADOSS or TAMOSS. The selected version and asset checksums are
in [release.yaml](release.yaml). Local overlays provide OCI-specific configuration.

TADOSS shares OKE workers, the PostgreSQL system, Authentik, Traefik, certificate
management, Flux and Vault/External Secrets with TAMOSS. It uses the `tads`
namespace, its own `tadoss` database and role, and a separate OAuth application.
TAMOSS stores media in Object Storage; TADOSS stores timed metadata and references
the media source through a `tams://` identifier. TADOSS needs no object store.

## Release access

Published upstream release assets are public and downloaded without authentication.
Private bundle publication uses `GITHUB_TOKEN`; metadata verification uses
`GHCR_READ_TOKEN`. OKE uses the existing package-read credential delivered from
Vault.

Downloads have size/time limits and must match the committed checksums. The
private `tadoss-release-assets` bundle contains only unchanged published assets
and a static Kustomize entrypoint. Flux consumes its immutable digest. No local
credentials, source checkout or private notes are included.
Select `tadoss` in the release publishing workflow's application input to publish
that bundle; the existing TAMOSS bundle can retain its verified digest.

## Prepare bootstrap

Use the [GitOps workflow](../gitops/README.md). Supply the published TADOSS bundle
alongside the existing TAMOSS bundle in the private environment's `gitops.yaml`:

```yaml
tadoss:
  bundle:
    url: oci://ghcr.io/OWNER/tadoss-release-assets
    digest: sha256:REPLACE_WITH_PUBLISHED_DIGEST
```

Bootstrap prepares persisted TADOSS database and OAuth credentials in Vault and
restricts their readers to this environment's cluster and service accounts.
The initial Git export includes `tadoss.enabled: false` and the release pins.
No TADOSS workloads or logical database are created until enablement. Older
environments require those bootstrap prerequisites before Kind is stopped.

## Enable through Git

After the documented ownership transfer and Kind stop, change the environment
repository's existing `clusters/<environment>/values.yaml`:

```yaml
tadoss:
  enabled: true
```

Change only that field; preserve the sibling `release` mapping generated during
export. Commit and push to the configured branch. Flux then delivers credentials,
initialises the separate database, configures Authentik, installs the released
operator and reconciles the multi-server instance. Reconciliation uses the
existing ingress address at `https://tads.<hyphenated-public-IP>.sslip.io`.

Use the separate `tadoss-<deployment-id>` OAuth client with Authentik's
`/application/o/token/` endpoint and `client_credentials` grant. Request the
appropriate `tads-api/read`, `tads-api/write` or `tads-api/delete` scopes.
The client secret remains in Vault and the `auth/tadoss-oauth` Secret; never put
it in Git. Bearer requests use the resulting signed JWT.

Inspect native controller status:

```bash
kubectl --kubeconfig "$ENV_DIR/remote.kubeconfig" -n auth get kustomizations
kubectl --kubeconfig "$ENV_DIR/remote.kubeconfig" -n tads get tadoss,pods,ingress,certificate
```

When TADOSS is enabled, Authentik workers apply its mounted OAuth blueprint with
the native `ak apply_blueprint` startup hook, bounded to 120 seconds. Worker
readiness waits for the hook, avoiding the hourly blueprint-discovery delay.

The instance requires its current generation, selected release and both API and
worker replica counts to be ready. Certificate readiness and working API requests
are separate checks. Initial enablement and full environment teardown are the
supported integration paths; application uninstall and upgrades are unqualified.
Removing the enablement setting is not a database deletion procedure.

## Verification and removal

`task check` validates the release bundle, Flux configuration, secret permissions,
database isolation, released migrations on PostgreSQL 16 and TLS rejection cases.
`task check:management` also tests the published operator's deletion protection
and repeated cleanup in disposable Kind.

The internal GitOps qualification uses Hurl to create a schema, track and timed
events linked to the actual TAMOSS ingest source and segment time range. It
checks anonymous and insufficient-scope rejection, retained events after pod
replacement and continued media access. Replacement is verified by comparing
pod UIDs before and after deletion. Kind must exist and remain stopped.
Capture its infrastructure baseline before the enablement commit; qualification
compares the OCI resource IDs afterwards and records the applied Git revision.
These checks passed on OCI with unchanged infrastructure IDs and Kind stopped.
The OAuth startup hook completed after each Authentik worker timed out once and
restarted automatically; first-attempt hook completion remains unqualified.
These checks require an authorised live environment; local passes alone do not
establish them.

Use the [GitOps teardown](../gitops/README.md) to return ownership to the original
Kind. It finalises TADOSS while its operator remains available, then removes
application controllers and shared infrastructure. External database data remains
until the OCI database system is deleted. The Vault/key retain their recorded
owner under the existing foundation policy.
