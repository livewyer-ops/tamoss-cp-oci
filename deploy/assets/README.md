# Client-owned deployment assets

[Getting started](../../docs/getting-started.md) | [GitOps](../gitops/README.md) | [Operations](../../docs/operations.md)

CI assembles a deployment release from the [allowlisted paths](paths.txt), unchanged
TAMOSS/TADOSS assets and pinned dependencies. It publishes an OCI artifact after
local release checks. `dependencies.yaml` selects its digest.

`mise run up` downloads that artifact once, creates a private client bucket and
restricted reader, and uploads the release under `releases/<digest>/`. OCI verifies
upload checksums. Kind and OKE read this customer-owned copy through Flux Bucket
sources. They never read the product Git repository; later product releases do
not change the selected deployment.

## Release contents and ownership

Each release contains both applications' deployment assets, even when TADOSS is
disabled, plus the matching TAMOSS source archive for qualification. `build.yaml`
records provenance, `SHA256SUMS` covers the files, and `release.yaml` records the
manifest hash. `operator-source.tar.gz` preserves this product's matching tooling.
Private working files, credentials and kubeconfigs are excluded.

Upstream sources remain read-only. Integration overlays belong to this product.
Container images, provider packages, the official Flux distribution and external
Helm repositories retain their existing pins; the bundle is not an air-gapped mirror.

The client owns the bucket, releases, reader and optional environment repository.
Flux Bucket selects a fixed prefix rather than enforcing server-side immutability.
Only the provisioner can write the bucket, and publication does not overwrite
existing objects. Preserve those contents. Normal `down` removes workload resources
and the reader while retaining the bucket, which continues to incur storage charges.

## Credentials

The host provisioner creates a separate `tamoss-assets-<deployment-id>` user,
group, membership and policy in the Default identity domain. Only Customer Secret
Keys are enabled. Its policy permits reading this asset bucket and its objects.

The one-time key response is held in owner-only local files until it is applied
to Kind. ESO persists it to Vault; Crossplane observes all expected ExternalSecrets
before retiring staging resources. OKE obtains the reader through workload identity
and its `flux-system/asset-vault` SecretStore. Credentials never appear in Git,
the asset lock or Crossplane status.

OCI identity propagation may delay source access. Flux retries normally. Preserve
the existing reader rather than generating another key. Interrupted host preparation
requires [explicit cleanup](../../docs/operations.md#interrupted-host-preparation)
before a fresh attempt. Once the seed has been accepted by Kind, repeat `up` with
the original records to resume observation and temporary OKE access.

## Git selection and upgrades

Initial selection is recorded in the private `assets.lock.yaml`. Handover exports
that same ConfigMap beside `values.yaml` in the client's repository. The lock holds
the source prefix, manifest hash and dependency pins; values hold operational
choices such as `tadoss.enabled`.

To copy a newer, published deployment release into the client store, use the
installer containing its reviewed `deploymentBundle` pin:

```bash
ENV_DIR=.local/environment mise run assets:publish
```

This writes `.local/environment/assets-state/candidate.lock.yaml`. It does not
change the active lock or running deployment. After reviewing compatibility,
select it in the configured environment Git path:

```bash
cp .local/environment/assets-state/candidate.lock.yaml \
  .local/gitops/clusters/media-demo/assets.lock.yaml
git -C .local/gitops add clusters/media-demo/assets.lock.yaml
git -C .local/gitops commit -m "feat: select deployment asset release"
git -C .local/gitops push origin main
```

Enabling TADOSS only changes its existing value; it requires no publication.
Release upgrade compatibility remains unqualified. Check migrations and retained
media before selecting a candidate; reverting Git cannot undo an incompatible
schema migration.

## Recovery and retirement

Flux restores a missing source cache from the selected customer prefix. Handover
and qualification download that release and check its manifest before using it.
Keep the bucket, original Kind and private deployment records through teardown.

To recover matching tooling, download and verify the selected release, then extract
`operator-source.tar.gz` into an empty directory. This restores source files only;
it cannot restore a lost Kind cluster, deployment identity or credentials.

After verified `down`, explicitly remove an unwanted store:

```bash
ENV_DIR=.local/environment mise run assets:retire
```

Retirement verifies teardown, reader removal and bucket ownership. Another reader
policy or externally enabled versioning blocks deletion for review. Deletion
permanently removes the releases and recovery tooling.
