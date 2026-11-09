# Getting started

[Overview](../README.md) | [Operations](operations.md) | [Testing](testing.md) | [Architecture](architecture.md)

Run commands from the repository root. The default deployment directory is
`.local/environment`; the environment Git checkout is `.local/gitops`. Retain
both directories and the original Kind cluster until teardown is verified.

## Workstation prerequisites

Use Linux amd64 with Bash, Git, curl, OpenSSL, GNU coreutils and findutils, tar,
gzip, unzip and Docker with its Compose plugin. Docker must be running and
accessible to your user. Other workstation platforms remain unverified.

Install [mise](https://mise.jdx.dev/installing-mise.html), then run:

```bash
mise trust
mise install --locked
mise run setup
```

mise supplies the pinned tools, including an isolated native OCI CLI and Python.
The committed lockfile includes its Python dependencies. No PATH export or shell
activation is required for `mise run`. `setup` creates an owner-only input directory containing
`values.yaml` and optional `gitops.yaml`. Repeating setup preserves the file. It refuses to
initialise a directory containing an earlier deployment. Select a fresh directory
with `ENV_DIR=.local/environments/my-environment mise run setup` when needed, then use
that same `ENV_DIR` for every lifecycle command.

Setup performs no OCI provisioning or Git publication. Account access and the
following settings must be supplied before `up`.

## OCI preparation

Use a precreated compartment with quota for three OKE workers, two PostgreSQL
nodes, networking, storage and a load balancer. The [account prerequisites](../deploy/oci/README.md)
define infrastructure and restricted identity-management permissions. Deployment
creates the application storage identity. The provisioner also needs the [Vault and runtime IAM permissions](../deploy/gitops/README.md#inputs-and-secret-delivery).
These account prerequisites can be reused across deployments.

### API signing profile

Store the provisioner's signing key outside Git. Configure `~/.oci/config`:

```ini
[DEFAULT]
user=<provisioner user OCID>
fingerprint=<API key fingerprint>
tenancy=<tenancy OCID>
region=eu-frankfurt-1
key_file=/absolute/path/to/oci_api_key.pem
```

Restrict the configuration and key to mode `600` and their directory to `700`.
`OCI_CLI_CONFIG_FILE` and `OCI_CLI_PROFILE` select another file/profile; their
defaults are `~/.oci/config` and `DEFAULT`. The deployment reads its region from
that profile.

### Storage identity

Crossplane creates a dedicated storage user, group and bucket access policy in
the tenancy's Default identity domain. Supply that domain's OCID and endpoint in
`storageIdentity`; the generated user reuses `contactEmail`. There is no storage
user OCID to enter. The provisioner needs the
[storage IAM permissions](../deploy/oci/README.md#storage-iam-permissions).

The default bucket is `tamoss-media-demo-media`. Setting `name` changes it to
`tamoss-<name>-media`; `storage.bucket` overrides the bucket name. Crossplane
creates the bucket and grants the generated user access to that bucket only.

During `up`, a bounded Job in Kind creates the key and stages its one-time
response in a Kubernetes Secret. ESO persists it in OCI Vault and reads it back
before bootstrap continues. No S3 key files or copy-and-paste step are required.
Database and application passwords are also generated and persisted in Vault.

## Quick deployment

The quick deployment needs no GitHub login, environment repository or registry
credentials. The host fetches the CI deployment release pinned in
`dependencies.yaml`. Flux in Kind and OKE reads its manifest bundle and packaged
Helm charts directly from the public registry by digest. Local source edits do not enter the release; contributors
publish and pin a new bundle before deploying their changes. Use a dedicated
compartment with no workload resources.

Complete `.local/environment/values.yaml`, copied from the
[example settings](../environments/example/values.yaml). Have the account
administrator prepare the OCI values for the selected tenancy and region:

| Input | Value to supply |
| --- | --- |
| `compartmentId`, `contactEmail`, `adminCidrs` | Empty deployment compartment, operator contact and administrator API allowlist |
| `storageIdentity.domainId`, `storageIdentity.idcsEndpoint` | Default identity domain OCID and HTTPS endpoint |
| `storage.namespace` | Tenancy's Object Storage namespace |
| `network.ociServiceId`, `network.ociServiceCidr` | Regional All Services network OCID and service CIDR label |
| `oke.imageId` | OKE-compatible x86-64 image OCID for the selected Kubernetes version and worker shape |
| `oke.placements` | Worker availability-domain names and fault domains; the example has three placements |

Reuse the prepared tenancy/region values for fresh deployments. Update them when
the tenancy, region, worker image or placement changes. The installer does not
query OCI catalogues or check regional image/shape availability before provisioning.

Use your actual public egress IPv4 address, including any VPN gateway, for the
API allowlist. The name defaults to `media-demo`; choose another unused `name`
for a separate environment. Names have 3–23 lowercase letters, digits or hyphens,
starting with a letter and ending with a letter or digit.

The [defaults](../charts/setup/values.yaml) supply HA capacity, network ranges,
PostgreSQL settings and the OKE version. Owner, ACME contact and
administrator email use `contactEmail`. The Vault foundation defaults to
`<name>-vault`. TADOSS credentials are prepared, with the application disabled.

```bash
mise run up
```

`up` fetches the pinned deployment release and renders the supplied inputs.
Helm checks required fields and input types. OCI handles deployment compatibility
errors. Frankfurt with three availability domains is the previously qualified
placement.

Kind starts Flux, Crossplane and Vault credential persistence. Once OKE is ready,
the host records its identity and creates a temporary bootstrap ServiceAccount.
It requests a one-hour token and submits a self-contained kubeconfig Secret to
Kind. Keep `up` running until that submission; afterwards Kind's Flux installs
and seeds OKE through declared dependencies: Flux, ESO, Vault-backed asset access,
then the deployment. OKE's Flux reconciles the platform
and applications independently of the host.

After public TLS and application readiness pass, `up` suspends Kind's remote
bootstrap Kustomizations, stops their controller and revokes the bootstrap
ServiceAccount. It then prints URLs and writes initial login details to
`.local/environment/access/ui-login.json` with owner-only permissions. If bootstrap
access expires before completion, follow
[failed-deployment cleanup](operations.md#clean-up-a-failed-deployment).

Kind remains the infrastructure writer. Applications run on OKE. `up` accepts
only a fresh deployment directory; it refuses an existing deployment identity.
Keep `values.yaml` unchanged while installation runs. `mise run check` is a
contributor validation command; it is not required before each deployment.

## Optional GitOps handover

After `up` succeeds, authenticate once on the workstation:

```bash
mise exec -- gh auth login --hostname github.com --git-protocol https
```

Set `.local/environment/gitops.yaml`:

```yaml
owner: YOUR-OWNER
repository: tamoss-environments
branch: main
```

The repository and branch above are defaults; the cluster path defaults to
`clusters/<name>`. Use an account allowed to create the repository or administer
an existing repository and its deploy keys. Existing repositories must contain
the selected branch and permit the generated commits. Existing cluster paths
belonging to another deployment are rejected.

```bash
mise run handover
```

Handover creates a private repository if needed and publishes the running
configuration. Native Flux bootstrap registers a repository-scoped, read-only SSH
deploy key. The operator's GitHub token stays on the workstation; the deploy key
is persisted through Kind's Vault store and delivered to OKE through ESO.

Once Git has adopted the deployment, handover verifies both inventories, quiesces
Kind, grants OKE write authority and publishes the ownership change. Original Kind
stops only after readiness passes. Resources, passwords and application capabilities
remain in place. Git owns subsequent changes, including
[TADOSS enablement](../deploy/tadoss/README.md#enable-through-git).

GitHub may remove a deploy key when the token used to register it is revoked.
Retain that authentication. Renewal must update GitHub, Vault and ESO together;
see [credential ownership](../deploy/gitops/README.md#inputs-and-secret-delivery).
Automated rotation is not yet qualified, and Vault persistence does not keep a
revoked GitHub key valid.

Retain `.local/gitops`, `.local/environment` and the original Kind containers
until teardown. Failed handover can be retried with the same inputs; `up` never
restores the initial configuration over established GitOps settings.

## Advanced inputs and generated records

Override supported infrastructure fields in `values.yaml` only when needed:

```yaml
name: another-demo
owner: platform-team@example.com
acmeEmail: certificates@example.com
storage:
  bucket: my-authorised-media-bucket
```

Network, worker placement/image, sizing and database overrides are validated
against the [setup schema](../charts/setup/values.schema.json) and environment API.
Keep subnets inside the selected VCN. Reuse an owned Vault/key through
`foundation.name` and recorded `foundation.adoption` fields; a matching name is
not proof of ownership.

`product.url` records source provenance. Local source edits require a new published
release and digest pin. See [release artifacts](../deploy/assets/README.md).

| Generated output | Location under `.local/environment/` |
| --- | --- |
| Deployment input | `values.yaml` |
| Resolved product, infrastructure and settings | `product.yaml`, `environment.yaml`, `foundation.yaml`, `settings.yaml` |
| Initial deployment configuration | `deployment/`, `deployment.yaml` |
| Selected bundle and chart digests | `assets.lock.yaml` |
| Protected OCI profile and render inputs | `discovery/` |
| Management and OKE access | `management.kubeconfig`, `remote.kubeconfig` |
| Cloud outputs and adoption record | `outputs.json`, `adoption.yaml` |
| Installed release and deployment identity | `tamoss-release.yaml`, `identity.yaml` |
| Ownership and teardown records | `identity.yaml`, `foundation-record.yaml`, `inventory-after/` |
| Qualification reports | `reports/` |

Follow [cleanup instructions](operations.md#clean-up-a-failed-deployment) using the
original directory. Existing deployments must retain their deployed product revision
for operations and teardown; this layout does not migrate them.

## Access

Enter `mise exec -- bash` for the native commands in this section, then display
the public URLs and application status:

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss tamoss -o json |
  yq '.spec | {"api": ("https://api." + .publicEndpoint.baseDomain), "ui": .publicEndpoint.uiURL, "auth": .auth.authentikBlueprints.issuerURL}'
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss,storagebackends
```

Expected: TAMOSS and its external StorageBackend report `Ready`. Export the
initial login details to an owner-only file:

```bash
umask 077
install -d -m 700 .local/environment/access
install -m 600 /dev/null .local/environment/access/ui-login.json
kubectl --kubeconfig .local/environment/remote.kubeconfig -n auth get secret authentik -o json |
  yq -p=json -o=json '.data | {"username": (.AUTHENTIK_BOOTSTRAP_USERNAME | @base64d), "password": (.AUTHENTIK_BOOTSTRAP_PASSWORD | @base64d)}' \
  > .local/environment/access/ui-login.json
```

Open the private file locally, visit the UI URL and sign in through Authentik.
If the bootstrap password has changed, use the current password. Remove the
exported file after use. For authenticated API requests, see
[Operations](operations.md#first-api-request).

## Qualify and inspect ingest

Read the [qualification effects](testing.md#deployed-qualification) before running:

```bash
mise run qualify
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get ingestrun qualification
```

Expected: the run reaches `Succeeded` and all qualification checks pass. In the
UI, open **Ingest runs** and follow the output Flow links. Qualification drains
one worker and replaces its test media. The environment remains running after
qualification; use [verified teardown](operations.md#destroy-the-environment)
when it is no longer needed.
