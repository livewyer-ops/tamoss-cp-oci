# TAMOSS on Oracle Kubernetes Engine

Deploy [TAMOSS](https://github.com/livewyer-ops/tamoss), a time-addressable media store, on Oracle Kubernetes Engine (OKE). The deployment uses three workers, a two-node PostgreSQL system and a private OCI Object Storage bucket. Users reach the API and web UI over HTTPS and sign in through Authentik.

## Quickstart

Use a Linux amd64 workstation with Docker and [mise](https://mise.jdx.dev/installing-mise.html). You need a dedicated OCI compartment and a provisioner with an API signing key. An account administrator can [create the provisioner](deploy/oci/README.md#create-the-provisioner). Set `COMPARTMENT_OCID` and `CONTACT_EMAIL` to your compartment OCID and contact email.

```bash
git clone https://github.com/livewyer-ops/tamoss-cp-oci.git
cd tamoss-cp-oci
mise trust
mise install --locked
mise run setup --compartment-id "$COMPARTMENT_OCID" --contact-email "$CONTACT_EMAIL"
```

Review `.local/environment/values.yaml`. For a private GitHub source, sign in with `mise exec -- gh auth login` using an account that can manage deploy keys. For a public source, set `source.private: false`.

```bash
mise run up
```

Open the UI URL printed by `up` and sign in with the credentials in `.local/environment/access/ui-login.json`. Keep the stopped Kind cluster, this checkout and the deployment directory until teardown completes.

## Remove the deployment

**Teardown deletes the media, database and database backups.** When you are ready to remove them, run `mise run down` from the same checkout.

## Documentation

| Guide | Use it to |
| --- | --- |
| [Getting started](docs/getting-started.md) | Prepare the workstation, configure OCI and verify the installation |
| [Configuration](docs/configuration.md) | Choose worker placement, storage, network access and optional settings |
| [Operations](docs/operations.md) | Query the API, apply settings, hand over to Git or tear down |
| [Recovery](docs/recovery.md) | Diagnose a failed deployment or resume an interrupted teardown |
| [Architecture](docs/architecture.md) | Identify which cluster and controller owns a resource |
| [TADOSS](deploy/tadoss/README.md) | Add timed metadata to media stored in TAMOSS |
| [Testing](docs/testing.md) | Verify ingest, playback and availability on a disposable installation |

For contributions, see [Contributing](CONTRIBUTING.md). Use and distribution are subject to the [licence](LICENSE).
