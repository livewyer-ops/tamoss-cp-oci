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
Public bundle publication and metadata verification use `GITHUB_TOKEN`.
The workflow verifies anonymous consumption; OKE needs no registry credential.

Downloads have size/time limits and must match the committed checksums. The
public `tadoss-release-assets` bundle contains only unchanged published assets
and a static Kustomize entrypoint. CI copies its digest-pinned contents into
the deployment bundle, which Flux consumes. No local
credentials, source checkout or private notes are included.
Select `tadoss` in the release publishing workflow's application input to publish
that bundle; the existing TAMOSS bundle can retain its verified digest.

## Prepare bootstrap

Use the [GitOps workflow](../gitops/README.md). The product's
[release lock](release.yaml) selects the published public TADOSS bundle.
Publication includes it alongside TAMOSS, even while TADOSS is disabled. Both
upstream bundles are public; Flux reads deployment artifacts anonymously.

Bootstrap prepares persisted TADOSS database and OAuth credentials in Vault and
restricts their readers to this environment's cluster and service accounts.
The initial Git export includes `tadoss.enabled: false`; `assets.lock.yaml` holds
the release pins.
No TADOSS workloads or logical database are created until enablement. Older
environments require those bootstrap prerequisites before Kind is stopped.

## Enable through Git

After `mise run handover` completes the ownership transfer and Kind stop, change the environment
repository's existing `clusters/<environment>/values.yaml`:

```yaml
tadoss:
  enabled: true
```

Change only that field and retain `assets.lock.yaml`. Commit and push to the
configured branch. Flux then delivers credentials,
initialises the separate database, configures Authentik, installs the released
operator and reconciles the multi-server instance. Reconciliation uses the
existing ingress address at `https://tads.<hyphenated-public-IP>.sslip.io`.

Use the separate `tadoss-<deployment-id>` OAuth client with Authentik's
`/application/o/token/` endpoint and `client_credentials` grant. Request the
appropriate `tads-api/read`, `tads-api/write` or `tads-api/delete` scopes.
The client secret remains in Vault and the `auth/tadoss-oauth` Secret; never put
it in Git. Bearer requests use the resulting signed JWT.

Enter `mise exec -- bash`, then inspect native controller status. These examples
use `.local/environment`; substitute your deployment directory if different.

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n auth get kustomizations
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tads get tadoss,pods,ingress,certificate
```

When TADOSS is enabled, Authentik's Helm release waits for its server and workers
to become ready, then applies the mounted OAuth blueprint through a native
`ak apply_blueprint` Job. Kubernetes limits the Job to five minutes and two
retries. A failure keeps the release unready without restarting workers; inspect
`kubectl -n auth logs -l job-name=tadoss-authentik-blueprint --prefix` using the
remote kubeconfig. A cold Authentik installation can require a Job retry.
The Job runs on install and upgrade, so initial enablement does not wait for the
hourly blueprint scan. Its status and logs remain until the next hook or teardown.
Only the Job receives the TADOSS blueprint and client secret. Enabling TADOSS
leaves Authentik's server and worker pod configuration unchanged.

The instance requires its current generation, selected release and both API and
worker replica counts to be ready. The deployment aggregate also requires its
public certificate to be Ready; working API requests are a separate check.
Initial enablement and full environment teardown are the
supported integration paths; application uninstall and upgrades are unqualified.
Removing the enablement setting is not a database deletion procedure.

## Verification and removal

`mise run check` validates the release bundle, Flux configuration, secret permissions,
database isolation, released migrations on PostgreSQL 16 and TLS rejection cases.
`mise run check:management` also tests the published operator's deletion protection,
repeated cleanup and Authentik startup in disposable Kind. Startup checks use an
external PostgreSQL database with verified TLS and two replicas each of the
server and worker. They cover repeat application and recovery after an invalid
blueprint without pod replacement.

The internal GitOps qualification uses Hurl to create a schema, track and timed
events linked to the actual TAMOSS ingest source and segment time range. It
checks anonymous and insufficient-scope rejection, retained events after pod
replacement and continued media access. Replacement is verified by comparing
pod UIDs before and after deletion. Kind must exist and remain stopped.
Capture its infrastructure baseline before the enablement commit; qualification
compares the OCI resource IDs afterwards and records the applied Git revision.
These checks passed on OCI with unchanged infrastructure IDs and Kind stopped.
Git enablement converged without a host reconciliation request. The OAuth Job
completed on its first attempt, with all four Authentik pod UIDs unchanged and
zero restarts. TADOSS's four application pods also started with zero restarts.
These checks require an authorised live environment; local passes alone do not
establish them.

Use the [GitOps teardown](../gitops/README.md) to return ownership to the original
Kind. It finalises TADOSS while its operator remains available, then removes
application controllers and shared infrastructure. External database data remains
until the OCI database system is deleted. The Vault/key retain their recorded
owner under the existing foundation policy.
