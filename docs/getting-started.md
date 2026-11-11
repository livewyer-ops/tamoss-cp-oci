# Getting started

[Overview](../README.md) | [Operations](operations.md) | [Configuration](configuration.md) | [Architecture](architecture.md)

Run commands from the repository root. The default deployment directory is
`.local/environment`. Keep that directory, this checkout and the Kind cluster
created by `up` until teardown has finished.

## 1. Prepare the workstation

Use Linux amd64 with Bash, Git, curl, OpenSSL, GNU coreutils and findutils, tar,
gzip and Docker. Docker must be running and accessible to your user. Other
workstation platforms are unverified.

Install [mise](https://mise.jdx.dev/installing-mise.html), then run:

```bash
git clone https://github.com/dodwyer/tamoss-cp-oci.git
cd tamoss-cp-oci
mise trust
mise install --locked
```

mise installs the pinned tools, including kubectl, the OCI CLI and the GitHub
CLI. No PATH export or shell activation is required for `mise run`.

## 2. Prepare the OCI account

Ask an account administrator for:

- a dedicated compartment with no workload resources, and quota for three OKE
  workers, two PostgreSQL nodes, networking, storage and a load balancer;
- a provisioner user in a group that holds the [account policy](../deploy/oci/README.md#policy);
- an API signing key for that user.

An administrator can create the last two with
[one command](../deploy/oci/README.md#create-the-provisioner), which also writes
the signing profile described below.

The same account preparation can be reused for later deployments. OCI can take
a few minutes to accept a new API key; if `setup` reports `NotAuthenticated`
straight after the key was added, wait and run it again.

### API signing profile

Store the signing key outside Git and configure `~/.oci/config`:

```ini
[DEFAULT]
user=<provisioner user OCID>
fingerprint=<API key fingerprint>
tenancy=<tenancy OCID>
region=uk-london-1
key_file=/absolute/path/to/oci_api_key.pem
```

Restrict the configuration and key to mode `600` and their directory to `700`.
The deployment uses the region of this profile. `OCI_CLI_CONFIG_FILE` and
`OCI_CLI_PROFILE` select another file or profile.

## 3. Sign in to GitHub (private repository only)

Flux reads this repository at the commit you have checked out. While the
repository is private, `up` registers a read-only deploy key for the deployment,
so sign in with an account allowed to manage the repository's deploy keys:

```bash
mise exec -- gh auth login --hostname github.com --git-protocol https
```

Your GitHub token stays on the workstation. Teardown revokes the deploy key.
Skip this step for a public repository and set `source.private: false` in the
settings created by the next step.

## 4. Create the settings

```bash
mise run setup --compartment-id 'ocid1.compartment.oc1..example' --contact-email 'you@example.com'
```

| Argument | Value |
| --- | --- |
| `--compartment-id` | OCID of the empty deployment compartment |
| `--contact-email` | Operator contact, also used for certificates and the administrator account |

`setup` creates the private settings file `.local/environment/values.yaml` and
fills in the storage namespace, identity domain, service network, OKE image,
worker placements and your current public IPv4 address. It makes read-only
requests and creates no cloud resources. Both arguments are optional; without
them, enter `compartmentId` and `contactEmail` in the settings file.

Check `adminCidrs` if your VPN or proxy uses a different outbound address for
Kubernetes access. Set `tadoss.enabled: true` to include
[TADOSS](../deploy/tadoss/README.md). [Configuration](configuration.md) lists
the other settings and explains how discovery chooses its values.

## 5. Deploy

Use a clean checkout whose current commit exists on GitHub `origin`.

```bash
mise run up
```

`up` first checks the settings, Docker, GitHub access for a private repository
and that the OCI profile can read the compartment. A failed check names the fix
and changes nothing. `up` then takes about 25 minutes. It starts Kind, creates the OCI resources, installs
the application on OKE and waits for public HTTPS. It then prints the
application URLs and writes the initial login details to
`.local/environment/access/ui-login.json`.

`up` accepts only a fresh deployment directory. If it fails, follow
[failed-deployment cleanup](operations.md#clean-up-a-failed-deployment) before
starting again.

## Access

Open `.local/environment/access/ui-login.json` locally, visit the UI URL and sign
in through Authentik. Remove the file after use.

Enter `mise exec -- bash` for the commands below. Display the URLs and status
again with:

```bash
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss tamoss -o json |
  yq '.spec | {"api": ("https://api." + .publicEndpoint.baseDomain), "ui": .publicEndpoint.uiURL, "auth": .auth.authentikBlueprints.issuerURL}'
kubectl --kubeconfig .local/environment/remote.kubeconfig -n tams get tamoss,storagebackends
```

Expected: TAMOSS and its external StorageBackend report `Ready`. If you removed
the login file, recreate it with:

```bash
umask 077
install -d -m 700 .local/environment/access
install -m 600 /dev/null .local/environment/access/ui-login.json
kubectl --kubeconfig .local/environment/remote.kubeconfig -n auth get secret authentik -o json |
  yq -p=json -o=json '.data | {"username": (.AUTHENTIK_BOOTSTRAP_USERNAME | @base64d), "password": (.AUTHENTIK_BOOTSTRAP_PASSWORD | @base64d)}' \
  > .local/environment/access/ui-login.json
```

If the bootstrap password has changed, use the current password. For
authenticated API requests, see [Operations](operations.md#first-api-request).

## Remove the deployment

```bash
mise run down
```

`down` takes about 15 minutes and deletes application data. Read
[teardown and retention](operations.md#destroy-the-environment) first.

## Another deployment

Use a separate directory and name for each additional deployment:

```bash
ENV_DIR=.local/environments/my-environment mise run setup --compartment-id 'ocid1.compartment.oc1..example' --contact-email 'you@example.com'
```

Set an unused `name` in its `values.yaml` and pass the same `ENV_DIR` to every
later command.
