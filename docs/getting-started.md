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
`values.yaml`, optional `gitops.yaml` and `secrets/`. Repeating setup preserves the file. It refuses to
initialise a directory containing an earlier deployment. Select a fresh directory
with `ENV_DIR=.local/environments/my-environment mise run setup` when needed, then use
that same `ENV_DIR` for every lifecycle command.

Setup performs no OCI provisioning or Git publication. Account access and the
following settings must be supplied before `up`.

## OCI preparation

Use a precreated compartment with quota for three OKE workers, two PostgreSQL
nodes, networking, storage and a load balancer. The [account prerequisites](../deploy/oci/README.md)
define infrastructure and restricted identity-management permissions. Deployment
creates separate application storage and deployment-asset readers. The provisioner also needs the [Vault and runtime IAM permissions](../deploy/gitops/README.md#inputs-and-secret-delivery).
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
that profile. Verify it with the installed native CLI:

```bash
mise exec -- oci os ns get
```

### Storage identity

Crossplane creates a dedicated storage user, group and bucket access policy in
the tenancy's Default identity domain. Setup discovers that domain and reuses
`contactEmail`; there is no storage user OCID to enter. The provisioner needs the
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
credentials. The host packages the committed checkout with verified public
TAMOSS/TADOSS assets and uploads them to a private OCI bucket owned by the client.
Flux in Kind and OKE reads this snapshot. The product checkout may be public or
private and may contain unpushed commits; commit all changes before deployment.
Neither cluster reads the product Git repository.

Edit `.local/environment/values.yaml`:

```yaml
compartmentId: ocid1.compartment.oc1..REPLACE
contactEmail: operator@example.com
adminCidrs: [192.0.2.10/32]
```

Use your actual public egress IPv4 address, including any VPN gateway, for the
API allowlist. The name defaults to `media-demo`; choose another unused `name`
for a separate environment. Names have 3–23 lowercase letters, digits or hyphens,
starting with a letter and ending with a letter or digit.

The [defaults](../charts/setup/values.yaml) supply HA capacity, network ranges,
PostgreSQL settings and a qualified OKE version/image. Owner, ACME contact and
administrator email use `contactEmail`. The Vault foundation defaults to
`<name>-vault`. TADOSS credentials are prepared, with the application disabled.

```bash
mise run up
```

`up` validates the committed checkout, inputs and upstream package access. Native
OCI queries resolve the storage namespace, service network, availability domains
and pinned worker image. Default placement requires three availability domains;
Frankfurt is the previously qualified region. Unavailable or ambiguous selections
stop the build rather than silently choosing another image.

Before Kind starts, the host creates the private asset bucket and a separate
read-only identity, uploads the snapshot and verifies every uploaded file.
The asset-reader key is seeded into Kind, persisted through ESO to Vault and
removed from local staging after exact readback. Its permissions cover this
asset bucket only; the application storage identity remains separate.

Kind starts Flux, Crossplane and Vault credential persistence. Once OKE is ready,
the host validates its identity and creates a temporary bootstrap ServiceAccount.
It requests a one-hour token and submits a self-contained kubeconfig Secret to
Kind. Keep `up` running until that submission; afterwards Kind's Flux installs
and seeds OKE through declared dependencies: Flux, ESO, Vault-backed asset access,
then the deployment. OKE's Flux reconciles the platform
and applications independently of the host.

After public TLS and application readiness pass, `up` suspends Kind's remote
bootstrap Kustomizations, stops their controller and revokes the bootstrap
ServiceAccount. It then prints URLs and writes initial login details to
`.local/environment/access/ui-login.json` with owner-only permissions. If setup
outlives the server-issued token, rerun `up` to renew it. An interrupted retirement
resumes cleanup without renewing access or resubmitting workloads.

Kind remains the infrastructure writer. Applications run on OKE. Repeating `up`
reuses the original identity and does not replay a completed remote seed. Keep
`values.yaml` unchanged after inputs are recorded. `mise run check` is a contributor
validation command; it is not required before each deployment.

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

`product.url` records source provenance. Publication uses the exact local commit;
no remote branch membership is required. `assets.bucket` overrides the derived
asset bucket name. A same-named bucket must carry the recorded ownership tag;
the workflow never adopts an unrelated store. See [client assets](../deploy/assets/README.md).

| Generated output | Location under `.local/environment/` |
| --- | --- |
| Recorded bootstrap input | `setup-values.yaml` |
| Resolved product, infrastructure and settings | `product.yaml`, `environment.yaml`, `foundation.yaml`, `settings.yaml` |
| Initial deployment configuration | `deployment/`, `deployment.yaml` |
| Client asset store and selected snapshot | `asset-store.yaml`, `assets.lock.yaml` |
| OCI discovery and package checks | `discovery/` |
| Management and OKE access | `management.kubeconfig`, `remote.kubeconfig` |
| Cloud outputs and adoption record | `outputs.json`, `adoption.yaml` |
| Installed release and deployment identity | `tamoss-release.yaml`, `identity.yaml` |
| Ownership and baseline records | `resources.yaml`, `owned-cloud.yaml`, `inventory-before/` |
| Qualification reports | `reports/` |

Follow [retry instructions](operations.md#retry-a-failed-deployment) using the
same directory. Existing deployments must retain their deployed product revision
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
