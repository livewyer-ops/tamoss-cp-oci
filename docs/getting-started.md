# Getting started

[Overview](../README.md) | [Operations](operations.md) | [Testing](testing.md) | [Architecture](architecture.md)

Run commands from the repository root. The default deployment directory is
`.local/environment`; the environment Git checkout is `.local/gitops`. Retain
both directories and the original Kind cluster until teardown is verified.

## Workstation prerequisites

Use Linux amd64 with Bash, Git, curl, OpenSSL, GNU coreutils and findutils, tar,
gzip, unzip and Docker with its Compose plugin. Docker must be running and
accessible to your user. Other workstation platforms remain unverified.

Install [Aqua](https://aquaproj.github.io/docs/install/), then run:

```bash
aqua install
export PATH="$(aqua root-dir)/bin:$(aqua exec -- uv tool dir --bin):$PATH"
task setup
```

The PATH export is needed in each shell. `setup` installs the pinned native OCI
CLI through Aqua-managed uv and creates an owner-only input directory containing
`values.yaml` and `secrets/`. Repeating setup preserves the file. It refuses to
initialise a directory containing an earlier deployment. Select a fresh directory
with `task setup ENV_DIR=.local/environments/my-environment` when needed, then use
that same `ENV_DIR` for every lifecycle command.

Setup performs no OCI provisioning or Git publication. Account access and the
following settings must be supplied before `up`.

## OCI preparation

Use a precreated compartment with quota for three OKE workers, two PostgreSQL
nodes, networking, storage and a load balancer. The [account prerequisites](../deploy/oci/README.md)
define the provisioner's infrastructure permissions and a separate application
storage identity. The provisioner also needs the [Vault and runtime IAM permissions](../deploy/gitops/README.md#inputs-and-secret-delivery).
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
oci os ns get
```

### Storage credentials

The storage identity needs a Customer Secret Key scoped to the intended bucket.
The default bucket name is `tamoss-<name>-media`, where `name` comes from
`values.yaml`. Configure the storage policy for that exact name, or set
`storage.bucket` to the bucket name already authorised by your administrator.
Crossplane creates the bucket during deployment.

Write the credential bytes through hidden prompts:

```bash
umask 077
read -r -s -p 'S3 access key: ' S3_ACCESS_KEY
printf '%s' "$S3_ACCESS_KEY" > .local/environment/secrets/s3-access-key
unset S3_ACCESS_KEY
read -r -s -p 'S3 secret key: ' S3_SECRET_KEY
printf '%s' "$S3_SECRET_KEY" > .local/environment/secrets/s3-secret-key
unset S3_SECRET_KEY
```

Keep credentials out of manifests, shell tracing and logs. Database and application
passwords are generated and persisted in OCI Vault during deployment.

## Git and package access

Create a private environment repository with an initial commit on `main`.
Configure Git author/committer identity and authenticated push access on this
workstation. Branch protections must permit the generated commits. `up` clones
the repository into `.local/gitops` if needed and publishes its cluster directory;
`handover` later publishes the ownership policy. An existing checkout must have
exactly the origin URL and branch selected in `values.yaml`.

Install a GitHub App with read access to the product and environment repositories.
Put its App ID and installation ID in `values.yaml`. Its read access is separate
from the workstation's push credentials.

Supply owner-only files under `.local/environment/secrets/`:

| File | Content |
| --- | --- |
| `github-app-private-key` | GitHub App PEM private key |
| `ghcr-dockerconfigjson` | Self-contained Docker authentication JSON for GHCR |
| `s3-access-key` | Exact S3 access key bytes, without a trailing newline |
| `s3-secret-key` | Exact S3 secret bytes, without a trailing newline |

The GHCR credential must read the TAMOSS and TADOSS release bundles recorded in
`deploy/tamoss/release.yaml` and `deploy/tadoss/release.yaml`, plus the bootstrap
tooling image in `dependencies.yaml`. A Docker configuration referring only to a
workstation credential helper is insufficient. Set each credential file to mode
`600`; preserve the PEM and JSON formats. The deployment checks package access
before provisioning and generates the two internal App ID files automatically.

Consumers use the published packages. Maintainers who publish their own packages
follow the [bundle procedure](../deploy/tamoss/README.md#private-release-bundle)
and [tooling image procedure](operations.md#native-oci-cli), then commit their
matching pins. Private package access is still required when the product Git
repository is public.

## Environment inputs

Edit `.local/environment/values.yaml`:

```yaml
name: media-demo
compartmentId: ocid1.compartment.oc1..REPLACE
contactEmail: operator@example.com
adminCidrs: [192.0.2.10/32]
git:
  url: https://github.com/YOUR-OWNER/tamoss-environments
  githubAppId: 'REPLACE'
  githubInstallationId: 'REPLACE'
```

Replace the name, compartment, email, administrator CIDR, repository URL and App
IDs. Use your actual public egress IPv4 address, including any VPN gateway, for
the API allowlist. The name must have 3–23 lowercase letters, digits or hyphens,
starting with a letter and ending with a letter or digit. Choose an unused
cluster path and bucket name for each new deployment.

The [defaults](../charts/setup/values.yaml) provide the existing HA capacity,
network ranges, PostgreSQL settings, qualified OKE version/image selection and
`main` branch. Owner, ACME contact and administrator email default to
`contactEmail`. The cluster path defaults to `clusters/<name>`, and the Vault
foundation name to `<name>-vault`. TADOSS is prepared but initially disabled.

Before provisioning, native OCI queries resolve the Object Storage namespace,
regional service network and availability-domain names. The default placement
needs three availability domains; Frankfurt is the live-qualified region.
The pinned image must be available for the selected OKE version and architecture.
An unavailable or ambiguous selection stops setup; it does not select a newer
image automatically.

Override supported fields in the same file when needed, for example:

```yaml
owner: platform-team@example.com
acmeEmail: certificates@example.com
git:
  branch: main
  path: clusters/media-demo
network:
  vcn: 10.40.0.0/16
storage:
  bucket: my-authorised-media-bucket
```

Merge overrides into the existing mappings. Retain the Git URL and App IDs, and
keep every subnet inside the selected VCN. `oke.placements`, `oke.imageId`, sizing
and database settings have explicit overrides validated against the environment
API. To reuse an owned Vault/key, set `foundation.name` and its recorded
`foundation.adoption` fields from the retained foundation record; do not discover
or adopt an unrelated foundation by name.

The product URL defaults to this repository; `product.url` supports a published
fork. The selected local commit must be published on that repository's `main`
history. Release bundle digests come from the product's release locks.

The environment stays running until explicitly removed with `task down`.

## Deploy

Run local product checks, then deploy:

```bash
task check
task up
```

`up` validates and resolves the inputs, checks package access, and records the
settings before provisioning. Generated `environment.yaml`, `foundation.yaml`,
`settings.yaml` and `gitops.yaml` are internal records. Repeating `up` reuses the
recorded choices and preserves environment Git. Keep the original `values.yaml`
unchanged after input preparation; make operational changes in environment Git.
A failed discovery or access check can be corrected before inputs are recorded.

Kind starts Crossplane, Flux and Vault credential persistence. A Crossplane-owned
Job retrieves the OKE connection, installs Flux and seeds remote GitOps.
Controllers deliver adoption bindings and application configuration. `up` waits
for deployment readiness, including public TLS, and leaves Kind running as the
infrastructure owner. Flux manages the applications from the start.

Transfer infrastructure ownership when ready:

```bash
task handover
```

Handover verifies readiness, quiesces Kind, publishes the ownership change and
waits for OKE convergence before stopping original Kind. Application capabilities
stay the same. Keep the original containers for teardown. Enable
[TADOSS through Git](../deploy/tadoss/README.md#enable-through-git) to demonstrate
an application change while Kind is stopped.

| Generated output | Location under `.local/environment/` |
| --- | --- |
| Recorded bootstrap input | `setup-values.yaml` |
| OCI discovery and package checks | `discovery/` |
| Management and OKE access | `management.kubeconfig`, `remote.kubeconfig` |
| Cloud IDs and endpoints | `outputs.json` |
| Vault adoption record | `adoption.yaml` |
| Installed release and deployment identity | `tamoss-release.yaml`, `identity.yaml` |
| Ownership and baseline records | `resources.yaml`, `owned-cloud.yaml`, `inventory-before/` |
| Live qualification reports | `reports/` |

After a failure, follow [retry instructions](operations.md#retry-a-failed-deployment)
with the same directory. Never edit generated identities or adoption records to
bypass a mismatch. Existing deployments retain their deployed product revision
for operations and teardown; setup does not migrate them.

## Access

Display the public URLs and application status:

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
task qualify
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get ingestrun qualification
```

Expected: the run reaches `Succeeded` and all qualification checks pass. In the
UI, open **Ingest runs** and follow the output Flow links. Qualification drains
one worker and replaces its test media. The environment remains running after
qualification; use [verified teardown](operations.md#destroy-the-environment)
when it is no longer needed.
