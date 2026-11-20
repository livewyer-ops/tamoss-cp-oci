# Getting started

## Prepare the workstation

Use Linux amd64 with Bash, Git, curl, OpenSSL, GNU coreutils and findutils, tar, gzip and Docker. Your user must be able to run `docker info`. Install [mise](https://mise.jdx.dev/installing-mise.html), then install the pinned tools from the repository root:

```bash
git clone https://github.com/livewyer-ops/tamoss-cp-oci.git
cd tamoss-cp-oci
mise trust
mise install --locked
```

## Configure OCI access

Use a dedicated compartment with no existing workloads and quota for three OKE workers, two PostgreSQL nodes, networking, storage and a load balancer. Ask an administrator for the [provisioner profile and signing key](../deploy/oci/README.md#create-the-provisioner).

The installer reads the `DEFAULT` profile in `~/.oci/config`. To use a profile elsewhere, export `OCI_CLI_CONFIG_FILE` and, if needed, `OCI_CLI_PROFILE` for the entire deployment. A manually configured profile has this form:

```ini
[DEFAULT]
user=<provisioner user OCID>
fingerprint=<API key fingerprint>
tenancy=<tenancy OCID>
region=uk-london-1
key_file=/absolute/path/to/oci_api_key.pem
```

Keep the profile and key outside Git. Set their permissions to `600` and their directory to `700`. Check the profile with `mise exec -- oci os ns get`. If a new key returns `NotAuthenticated`, allow time for IAM propagation before retrying.

## Configure the deployment

Set `COMPARTMENT_OCID` and `CONTACT_EMAIL` to your compartment OCID and contact email.

```bash
mise run setup --compartment-id "$COMPARTMENT_OCID" --contact-email "$CONTACT_EMAIL"
```

`setup` discovers OCI values and writes `.local/environment/values.yaml`. Review `adminCidrs` against the public egress IP you will use to reach OKE, particularly if you use a VPN. To add timed metadata at install time, set `tadoss.enabled: true`. See [Configuration](configuration.md) for overrides.

Flux needs a clean checkout whose commit is available on the GitHub `origin`. For a private source, keep `source.private: true` and run `mise exec -- gh auth login --hostname github.com --git-protocol https` with permission to manage repository deploy keys. For a public source, set `source.private: false` to use anonymous HTTPS.

For another installation, export a fresh `ENV_DIR` before `setup`, set an unused `name` in its `values.yaml` and keep the same `ENV_DIR` for all subsequent commands.

## Deploy

```bash
mise run up
```

`up` creates the infrastructure, waits for public HTTPS and stops the local Kind cluster. Keep its containers, the deployment directory and the deployed Git revision through teardown. If installation fails, use [failed deployment recovery](recovery.md#failed-installation) before attempting another installation.

## Access

Open the UI URL printed by `up`. Read `access/ui-login.json` privately in your deployment directory and sign in through Authentik. Remove the file after use.

To check the store, enter `mise exec -- bash` and run:

```bash
kubectl --kubeconfig "${ENV_DIR:-.local/environment}/remote.kubeconfig" -n tams get tamoss,storagebackends
```

Both resources should report `Ready`. To verify media access or remove the installation, see [Operations](operations.md).
