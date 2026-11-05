# Getting started

[Overview](../README.md) | [Operations](operations.md) | [Testing](testing.md) | [Architecture](architecture.md)

Run commands from the repository root. Examples use `.local/environment` for a
new deployment; use the same `ENV_DIR` and `CHECKOUT` for every lifecycle command. Retain this
directory and the original Kind cluster until teardown is verified.

## Workstation prerequisites

The deployment has been exercised from Linux. Other workstation platforms remain
unverified. Install Bash, Git, curl, OpenSSL, GNU coreutils and findutils, tar,
gzip, unzip and Docker with the Compose plugin. Docker must be running and
accessible to your user; local checks run containers and management checks create
a Kind cluster.

Install [Aqua](https://aquaproj.github.io/docs/install/), then follow the
[quickstart](../README.md#quickstart). Aqua supplies the tools pinned in
[aqua.yaml](../aqua.yaml). In each shell used for this checkout:

```bash
export PATH="$(aqua root-dir)/bin:$PATH"
docker info
docker compose version
task --list
```

Expected: Docker is reachable, Compose is available and Task lists the public
commands. Setup and local checks need internet access for pinned downloads and
container builds. Browser checks run in the repository's container.

## OCI preparation

Use a dedicated, precreated compartment with quota for three OKE workers,
two PostgreSQL nodes, networking, storage and a load balancer. The
[account prerequisites](../deploy/oci/README.md) define separate provisioning
and application-storage identities and their scoped IAM permissions.

Obtain the compartment OCID, Object Storage namespace, OKE-compatible image,
Kubernetes version, availability/fault domains and regional service-network ID
and CIDR. Use one region throughout. Obtain your workstation's public egress
IPv4 address, including any VPN gateway, for the API allowlist. The account
administrator owns creation and retirement of these prerequisites.

### API signing profile

Store the provisioner's signing key outside Git. Create its configuration directory:

```bash
install -d -m 700 ~/.oci
```

**File: `~/.oci/config`**

```ini
[DEFAULT]
user=<provisioner user OCID>
fingerprint=<API key fingerprint>
tenancy=<tenancy OCID>
region=eu-frankfurt-1
key_file=/absolute/path/to/oci_api_key.pem
```

Set `key_file` to the actual absolute path, then restrict both files:

```bash
chmod 600 ~/.oci/config /absolute/path/to/oci_api_key.pem
```

`OCI_CLI_CONFIG_FILE` and `OCI_CLI_PROFILE` select another config/profile for
Task commands. Their defaults are `~/.oci/config` and `DEFAULT`. The profile's
region must match the environment. The pinned [OCI CLI container](operations.md#native-oci-cli)
can validate access without installing another CLI on the workstation.

## Environment inputs

Create a fresh private directory and copy the examples:

```bash
umask 077
install -d -m 700 .local/environment .local/environment/secrets
cp environments/example/environment.yaml environments/example/settings.yaml \
  environments/example/cost.yaml environments/example/foundation.yaml \
  environments/example/gitops.yaml .local/environment/
```

### Infrastructure

**File: `.local/environment/environment.yaml`**

Edit the copied [example](../environments/example/environment.yaml); preserve its
complete structure. Replace all placeholders and review these fields:

| Fields | Required values |
| --- | --- |
| `metadata.name` | Unique name: 3–23 lowercase letters, digits or hyphens, starting with a letter and ending with a letter or digit |
| `spec.region`, `spec.compartmentId`, `spec.owner` | Deployment region, dedicated compartment and accountable owner |
| `spec.expiresAt` | UTC teardown deadline covering the run and cleanup, no later than the next UTC midnight |
| `spec.budget` | Currency `USD`; amount at least the allowance in `cost.yaml` |
| `spec.network` | Non-overlapping network ranges, your API allowlist and regional OCI service-network ID/CIDR |
| `spec.oke` | Compatible version/image, worker capacity and three availability/fault-domain placements |
| `spec.database` | PostgreSQL version, per-node capacity, administrator and backup retention |
| `spec.storage` | Object Storage namespace and an unused bucket name |

The example environment uses EUR; change `spec.budget.currency` to `USD` to
match the cost contract. Keep namespace `tamoss-infra`, provider configuration
`oci` and database credential Secret `database-admin`. The
[environment schema](../charts/environment/definition.yaml) defines supported
inputs and immutability rules. Select capacity before creating the environment.

After the [native OCI CLI setup](operations.md#native-oci-cli), inspect the
selected region's worker options and service networks:

```bash
docker compose -f deploy/oci/compose.yaml run --rm -T oci ce node-pool-options get \
  --node-pool-option-id all \
  --compartment-id "$(yq -r .spec.compartmentId .local/environment/environment.yaml)"
docker compose -f deploy/oci/compose.yaml run --rm -T oci network service list
```

Choose an image compatible with the selected Kubernetes version and worker
architecture. Use the regional all-services network's ID and CIDR, and obtain
the exact availability/fault-domain names from OCI for the worker placements.

### Application settings

**File: `.local/environment/settings.yaml`**

```yaml
acmeEmail: operator@example.com
adminEmail: admin@example.com
```

Use monitored addresses. Public API, UI and authentication hostnames are derived
from the reserved public IP using sslip.io. Cert-manager obtains public
certificates through HTTP validation on port 80; application access uses HTTPS
on port 443. The current input interface derives these hostnames automatically.

### Storage credentials

The separate storage identity's Customer Secret Key must have access to the exact
bucket named above. Supply owner-only files containing the credential bytes,
without trailing line endings. Enter the values at the hidden prompts:

```bash
umask 077
read -r -s -p 'S3 access key: ' S3_ACCESS_KEY
printf '%s' "$S3_ACCESS_KEY" > .local/environment/secrets/s3-access-key
unset S3_ACCESS_KEY
read -r -s -p 'S3 secret key: ' S3_SECRET_KEY
printf '%s' "$S3_SECRET_KEY" > .local/environment/secrets/s3-secret-key
unset S3_SECRET_KEY
chmod 600 .local/environment/secrets/s3-access-key .local/environment/secrets/s3-secret-key
```

Keep credentials out of manifests, command-line arguments, shell tracing and
logs. Application database passwords are generated on first deployment. A
missing credential in an established environment must be recovered.

### Git and Vault preparation

Create a private environment Git repository with an initial commit and clone it:

```bash
git clone https://github.com/YOUR-OWNER/tamoss-environments.git .local/gitops
```

Configure Git author/committer identity and authenticated push access on the
workstation. `up` publishes the generated configuration and the handover policy;
branch protections must permit these pushes. Flux uses a separate GitHub App
with read access to the environment and product repositories.

Edit `.local/environment/gitops.yaml` to match the checkout's exact origin,
branch and an unused `clusters/<name>` path. Select the published product commit
checked out locally and the immutable private GHCR bundle digest. Follow the
[private bundle procedure](../deploy/tamoss/README.md#private-release-bundle).

Edit `.local/environment/foundation.yaml` for the same region, compartment and
owner. To reuse an owned Vault/key, provide its recorded adoption IDs and creation
identity; retain that foundation record. The [OCI prerequisites](../deploy/oci/README.md)
include secret-management and runtime-IAM permissions.

Place the GitHub App IDs, PEM private key and package-read Docker credential JSON
in the exact owner-only files listed under
[secret delivery](../deploy/gitops/README.md#inputs-and-secret-delivery). The App's
read token does not provide the workstation's push access. Never commit secrets
or kubeconfigs to either repository.

### Spending and expiry

**File: `.local/environment/cost.yaml`**

Complete the copied [cost example](../environments/example/cost.yaml) with current
regional prices and HTTPS source references. It is a preflight estimate:

| Field | Meaning |
| --- | --- |
| `date`, `currency` | Current UTC date and `USD` |
| `allowanceUSD`, `spentUSD` | Total authorised allowance and spend already charged against it |
| `runHours`, `cleanupHours`, `reserveUSD` | Positive run window, cleanup window and contingency |
| `hourlyUSD` | Combined worker, database, Kubernetes, load-balancer, networking and storage rates |
| `transferUSD`, `priceReferences` | Transfer allowance and sources for the prices |

The projected total, including previous spend and cleanup, must fit the allowance.
Zero placeholder prices are insufficient. A repeated deployment preserves its
identity and deadline and must still have the full cleanup window available.
Expiry tags do not stop resources: monitor the deadline and start teardown in time.
Use [posted billing](operations.md#posted-billing) for actual charges; reconcile
currency differences explicitly when maintaining a USD allowance.

## Deploy

Run local checks after changing configuration or dependencies, then deploy:

```bash
task check
task up ENV_DIR=.local/environment CHECKOUT=.local/gitops
```

`up` records identity, prepares the environment Git configuration and records a
cloud inventory baseline. Its Kind seed starts Crossplane provisioning and Vault
credential persistence. As soon as OKE and its IAM grants are usable, it seeds
remote Flux. Controllers deliver generated bindings through Vault and verify observe-only OKE
adoption before transferring write authority. It waits for TAMOSS readiness, then
stops original Kind. Ongoing changes come from Git.

| Generated output | Location under `.local/environment/` |
| --- | --- |
| Management and OKE access | `management.kubeconfig`, `remote.kubeconfig` |
| Cloud IDs and endpoints | `outputs.json` |
| Verified Vault adoption record | `adoption.yaml` |
| Installed release and deployment identity | `tamoss-release.yaml`, `identity.yaml` |
| Ownership and baseline records | `resources.yaml`, `owned-cloud.yaml`, `inventory-before/` |
| Live qualification reports | `reports/` |

After a failure, follow [retry instructions](operations.md#retry-a-failed-deployment)
using this same directory. Generated files support ownership checks; do not edit
them to bypass a mismatch.

## Access

Display the public URLs and verify the application:

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
If the bootstrap password has been changed, use the current password. Remove
the exported file after use:

```bash
rm .local/environment/access/ui-login.json
```

For an authenticated API request, see [Operations](operations.md#first-api-request).

## Qualify and inspect ingest

Read the [qualification effects](testing.md#deployed-qualification) before running:

```bash
task qualify ENV_DIR=.local/environment CHECKOUT=.local/gitops
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get ingestrun qualification
```

Expected: the run reaches `Succeeded` and all qualification checks pass. In the
UI, open **Ingest runs** and follow the output Flow links. The fixture remains
until the next qualification or teardown. Finish with
[verified teardown](operations.md#destroy-the-environment) before the deadline.
