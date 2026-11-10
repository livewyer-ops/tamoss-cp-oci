# Getting started

[Overview](../README.md) | [Operations](operations.md) | [Testing](testing.md) | [Architecture](architecture.md)

Run commands from the repository root. The default deployment directory is
`.local/environment`. Retain that directory and the original Kind cluster until
teardown is verified.

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
`values.yaml`. Repeating setup preserves the file. It refuses to
initialise a directory containing an earlier deployment. Select a fresh directory
with `ENV_DIR=.local/environments/my-environment mise run setup` when needed, then use
that same `ENV_DIR` for every lifecycle command.

Setup performs no OCI provisioning or Git publication. Account access and the
following settings must be supplied before `up`.

## OCI preparation

Use a precreated compartment with quota for three OKE workers, two PostgreSQL
nodes, networking, storage and a load balancer. The [account prerequisites](../deploy/oci/README.md)
define infrastructure and restricted identity-management permissions. Deployment
creates the application storage identity. The provisioner also needs the
Vault and runtime IAM permissions listed in those prerequisites.
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

Use a clean checkout with its current commit pushed to this repository's GitHub
`origin`. Flux in Kind reads that exact commit. While the repository is private,
run `mise exec -- gh auth login --hostname github.com --git-protocol https` with
an account allowed to manage its deploy keys. Leave `source.private: true` in
settings. A public repository can use `source.private: false` to skip this step.
Use a dedicated compartment with no workload resources.

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

The [defaults](../charts/management/values.yaml) supply HA capacity, network ranges,
PostgreSQL settings and the OKE version. Owner, ACME contact and
administrator email use `contactEmail`. The Vault foundation defaults to
`<name>-vault`. Set `tadoss.enabled: true` before deployment to include TADOSS.

```bash
mise run up
```

`up` records the Git revision and renders the supplied inputs. Helm validates
required fields and types. Kind installs Flux, Crossplane and External Secrets;
Crossplane provisions OCI resources. The host records OKE's identity and supplies
Kind with a bounded ServiceAccount kubeconfig. Flux in Kind then installs the
platform and applications on OKE. Keep Kind running through teardown.

After current source/chart revisions and public TLS are ready, `up` prints URLs
and writes initial login details to `.local/environment/access/ui-login.json`.
OKE access remains available in Kind until workload cleanup finishes. See the
[full process](../deploy/gitops/README.md#process-and-execution-context), including
token expiry and renewal.

`up` accepts only a fresh deployment directory. Keep its inputs unchanged during
installation. `mise run check` is a contributor validation command; it is not
required before every deployment.

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
against the [settings schema](../charts/management/values.schema.json) and environment API.
Keep subnets inside the selected VCN. Reuse an owned Vault/key through
`foundation.name` and recorded `foundation.adoption` fields; a matching name is
not proof of ownership.

`source.json` records the repository and Git commit. Commit and push source edits
before a fresh deployment; local chart directories require no registry publication.

| Generated output | Location under `.local/environment/` |
| --- | --- |
| Deployment input | `values.yaml` |
| Host facts: deployment identity, OCI profile identifiers and Git source | `deployment.yaml`, `source.json` |
| Kind seed overlay | `kustomization.yaml`, `source.yaml`, `release.yaml` |
| Local copies of the resources Kind derives | `bootstrap.yaml`, `environment.yaml`, `foundation.yaml`, `settings.yaml` |
| Temporary protected OCI signing material | `discovery/` files, removed after seeding Kind |
| Management and OKE access | `management.kubeconfig`, `remote.kubeconfig` |
| Qualification cloud outputs | `outputs.json`, written by `qualify`; live outputs are in Kind's `TamossEnvironment.status.outputs` |
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

Expected: TAMOSS and its external StorageBackend report `Ready`. `up` has already
exported the initial login details to `.local/environment/access/ui-login.json`.
If you removed that private file, recreate it with:

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
