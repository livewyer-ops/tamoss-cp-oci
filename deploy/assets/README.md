# Client-owned deployment assets

[Getting started](../../docs/getting-started.md) | [GitOps](../gitops/README.md) | [Operations](../../docs/operations.md)

A deployment publishes its definitions from the checked-out commit to a private
client-owned OCI Object Storage bucket. Kind and OKE use native Flux Bucket
sources. Product Git availability, visibility and later branch changes cannot
change an existing deployment.

## Publication and ownership

`mise run up` builds the initial snapshot before starting Kind:

1. Require a clean committed checkout. Unpushed commits are supported.
2. Verify the selected TAMOSS/TADOSS releases, source archive and bundle digests.
3. Assemble the [allowlisted paths](paths.txt), unchanged upstream deployment
   assets and pinned Calico manifest. Resolve upstream Kustomize includes locally.
4. Record build inputs, the product commit, file checksums and matching operator
   tooling. Create the private bucket and restricted reader with native OCI CLI.
5. Upload under a build-specific `releases/<sha256>/` prefix without overwriting.
   Download it again and verify the complete file set and checksums before
   recording the publication and selecting it.

An interrupted upload can resume when existing bytes match. A missing, altered
or unexpected file fails verification. A changed checkout or build input selects
a new prefix. Publication receipts are stored separately under `publications/`.
The publisher must preserve release contents: Flux Bucket has no digest selector
or server-side immutability guarantee. Its lock selects a fixed prefix, and only
the provisioner can write the store.

Snapshots include both operators even when TADOSS is disabled. They include
TAMOSS's matching source archive for qualification and an archive of this
product's tracked operator tooling for recovery. Git history, private working
files, credentials and kubeconfigs are excluded. Upstream assets remain unchanged;
this product's integration overlays are separate.

Application/container images, provider packages, the official Flux distribution
and third-party Helm repositories remain external dependencies with their existing
pins. This snapshot is not an air-gapped mirror.

The client owns the bucket, published releases, reader lifecycle and optional
environment Git repository. Normal `down` retires the reader and removes workload
resources while retaining the store. Store retention incurs storage charges.

## Credentials

The host provisioner prepares a separate `tamoss-assets-<deployment-id>` user,
group, membership and policy in the Default identity domain. Only Customer
Secret Keys are enabled. The policy permits reading this asset bucket and its
objects; it permits neither publication nor media-bucket access.

The one-time key response is stored in owner-only local files and seeded into
Kind. ESO persists it in Vault and verifies exact readback before local staging
is removed. OKE receives it through workload identity and a separate
`flux-system/asset-vault` SecretStore. Its grant names the exact OKE cluster,
service account and deployment secret.

Kind Flux installs OKE Flux, then ESO, then the asset SecretStore/ExternalSecret,
then the deployment. This dependency order avoids requiring private source access
to install the controller that supplies that access. Reader credentials never
appear in Git, the asset lock or Crossplane status.

OCI identity changes can take time to propagate. Flux retries source access.
Inspect Bucket conditions and retain the original reader when initial access
fails; do not generate another key to bypass propagation.

If creation was interrupted after a complete key response, retry reuses that
response. If OCI contains a key but its one-time response was lost, stop and
recover it from retained records or revoke that exact key through the account
administrator before retrying. Never delete an established reader to force
recreation. An empty pending response also stops retry: use OCI Audit to establish
the outcome before removing that creation claim. An empty key list alone does
not prove that an in-flight create failed. Missing established Vault values
require credential recovery.

## Git selection and upgrades

Initial selection is recorded privately in `assets.lock.yaml`. Handover exports
that same ConfigMap to the client repository alongside `values.yaml`.
The lock holds the source prefix, checksums and release/dependency pins.
Client values hold operational choices such as `tadoss.enabled`. Native
Kustomize replacements and Helm values references apply both.

To prepare a candidate, use a clean committed product checkout with reviewed
release locks and the original environment directory:

```bash
ENV_DIR=.local/environment mise run assets:publish
```

This uploads and verifies a candidate. It does not update the active lock,
private deployment, client Git repository or running resources.

After handover, select the candidate in the client repository:

```bash
cp .local/environment/assets-build/published.lock.yaml \
  .local/gitops/clusters/media-demo/assets.lock.yaml
git -C .local/gitops add clusters/media-demo/assets.lock.yaml
git -C .local/gitops commit -m "feat: select deployment asset release"
git -C .local/gitops push origin main
```

Use the configured checkout, branch and cluster path. Review the lock diff and
release migration requirements before committing. Leave client values unchanged
unless the intended operation requires a configuration change. Enabling TADOSS
requires only its existing values setting; it needs no new publication.

Verify reconciliation and existing media, then run qualification. Publishing a
snapshot does not establish upgrade compatibility. A Git revert is safe only
when the target release's database migrations support returning to the earlier
release.

## Recovery and retirement

Flux recovers a lost source cache by downloading the selected prefix again.
The host restores qualification assets from the client store and validates them
against the selected release. Keep the bucket and original private deployment
records available throughout operations and teardown.

Each snapshot contains `operator-source.tar.gz` and `operator-commit.txt`.
These preserve matching tooling without requiring the product Git server.
Download and verify the selected snapshot using its lock and manifest first.
To reconstruct that tooling in an empty directory, with `SNAPSHOT` set to the
absolute verified snapshot directory:

```bash
tar --extract --gzip --file "$SNAPSHOT/operator-source.tar.gz" --no-same-owner
git init
git add --all
git write-tree
RECOVERED_COMMIT="$(git hash-object -t commit -w "$SNAPSHOT/operator-commit.txt")"
printf '%s\n' "$RECOVERED_COMMIT" > .git/shallow
git update-ref HEAD "$RECOVERED_COMMIT"
git diff --exit-code HEAD
```

Verify that `RECOVERED_COMMIT` matches the selected lock's `data.productCommit`
and that the working tree is clean before using it. This restores tooling only.
It does not restore a lost Kind cluster, deployment identity or credentials.
Retain original Kind and its records; automatic state-loss recovery is unsupported.

After verified `down`, explicitly delete an unwanted store:

```bash
ENV_DIR=.local/environment mise run assets:retire
```

Retirement verifies teardown, reader removal and bucket ownership. Another
deployment's recorded reader policy or externally enabled bucket versioning
blocks deletion for review. Deletion permanently removes releases and recovery
tooling. Repeating retirement verifies absence.
