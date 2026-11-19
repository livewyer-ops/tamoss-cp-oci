# TADOSS on the shared platform

This integration consumes the published [TADOSS release](https://github.com/livewyer-ops/tadoss/releases)
without modifying TADOSS or TAMOSS. The selected version and asset checksums are
in [release.yaml](release.yaml). Local overlays provide OCI-specific configuration.

TADOSS shares OKE workers, the PostgreSQL system, Authentik, Traefik, certificate
management, Flux and Vault/External Secrets with TAMOSS. It uses the `tads`
namespace, its own `tadoss` database and role, and a separate OAuth application.
TAMOSS stores media in Object Storage; TADOSS stores timed metadata and references
the media source through a `tams://` identifier. TADOSS needs no object store.

## Enable TADOSS

The [release lock](release.yaml) selects published upstream assets by checksum
and digest. Flux in OKE pulls the operator's OCI artifact directly. It builds
this repository's integration charts from the selected Git commit.

After [Git handover](../../docs/operations.md#keep-settings-in-an-environment-repository), set the option in the environment repository. For enablement during initial installation, before `mise run up` set the private deployment's `values.yaml`:

```yaml
tadoss:
  enabled: true
```

Crossplane and External Secrets prepare the database and OAuth credentials in
Vault. Flux in OKE installs the separate database/role, Authentik configuration,
released operator and instance. The API uses
`https://tads.<hyphenated-public-IP>.sslip.io`.

Use the separate `tadoss-<deployment-id>` OAuth client with Authentik's
`/application/o/token/` endpoint and `client_credentials` grant. Request the
appropriate `tads-api/read`, `tads-api/write` or `tads-api/delete` scopes.
The client secret remains in Vault and the `auth/tadoss-oauth` Secret; never put
it in Git. Bearer requests use the resulting signed JWT.

Enter `mise exec -- bash`, then inspect native controller status. These examples
use `.local/environment`; substitute your deployment directory if different.

```bash
kubectl --kubeconfig .local/environment/management.kubeconfig -n tamoss-infra get kustomizations
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
Initial enablement, enablement through Git after handover, and full environment teardown are the
supported integration paths; standalone application uninstall and upgrades are unqualified.
Removing the enablement setting is not a database deletion procedure.

## Verification and removal

`mise run check` validates the release bundle, Flux configuration, secret permissions,
database isolation, released migrations on PostgreSQL 16 and TLS rejection cases.
`mise run check:management` also tests the published operator's deletion protection,
repeated cleanup and Authentik startup in disposable Kind. Startup checks use an
external PostgreSQL database with verified TLS and two replicas each of the
server and worker. They cover repeat application and recovery after an invalid
blueprint without pod replacement.

For a running deployment with TADOSS enabled, `mise run qualify` captures an
infrastructure baseline, runs the TAMOSS qualification and then the TADOSS
checks. The TAMOSS qualification creates the ingest source the TADOSS checks
use; read its [effects](../../docs/testing.md#deployed-qualification) before
running it.

TADOSS qualification uses Hurl to create a schema, track and timed
events linked to the actual TAMOSS ingest source and segment time range. It
checks anonymous and insufficient-scope rejection, retained events after pod
replacement and continued media access. Replacement is verified by comparing
pod UIDs before and after deletion. The checks compare OCI IDs against the
captured baseline and record the selected Git commit. These checks have passed
on OCI with Kind stopped; see
[verified coverage](../../docs/testing.md#verified-coverage-and-limits).
These checks require an authorised live environment; local passes alone do not
establish them.

Use [teardown through Kind](../gitops/README.md) to finalise TADOSS while its operator remains available, then remove
application controllers and shared infrastructure. External database data remains
until the OCI database system is deleted. The Vault/key retain their recorded
owner under the existing foundation policy.
