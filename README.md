# TAMOSS on OCI Kubernetes Engine

Deploys [TAMOSS](https://github.com/livewyer-ops/tamoss) on Oracle Cloud
Infrastructure (OCI) with three commands. TAMOSS implements the BBC
Time-addressable Media Store (TAMS) API.

## Deployment

| Component | Configuration |
| --- | --- |
| Kubernetes | OKE with three workers spread across availability and fault domains |
| Application | Replicated TAMOSS API, worker, UI and Console API |
| PostgreSQL | Two OCI database nodes with verified TLS |
| Media storage | Private OCI Object Storage bucket |
| Public access | OCI load balancer, Authentik sign-in and trusted HTTPS |
| Optional | [TADOSS](deploy/tadoss/README.md) timed metadata services on the same platform |

A local Kind cluster on your workstation runs Flux and Crossplane. They create
the OCI resources and install the application on OKE. Keep the workstation and
that Kind cluster running until you remove the deployment. See
[architecture](docs/architecture.md).

## Requirements

- Linux amd64 workstation with Docker running and [mise](https://mise.jdx.dev/installing-mise.html) installed.
- An empty OCI compartment and an OCI API signing profile granted the
  [account permissions](deploy/oci/README.md#policy).
- While this repository is private: GitHub access that can manage its deploy keys.

Deployment takes about 25 minutes and removal about 15 minutes. The resources
are billable while they exist. Three deployments on 10 November 2026, about 3.3
hours of infrastructure in total, were posted at GBP 2.04 before tax in
`uk-london-1`; your rates may differ. See [posted billing](docs/operations.md#posted-billing).

## Quickstart

```bash
git clone https://github.com/dodwyer/tamoss-cp-oci.git
cd tamoss-cp-oci
mise trust
mise install --locked
mise exec -- gh auth login --hostname github.com --git-protocol https
mise run setup
"${EDITOR:-vi}" .local/environment/values.yaml
mise run up
```

`gh auth login` is needed only while the repository is private. `setup` reads
the OCI profile and fills in the tenancy and region settings. Enter
`compartmentId` and `contactEmail` in `values.yaml` before `up`. `up` prints the
application URLs and the location of the initial login details.

[Getting started](docs/getting-started.md) explains each step.

## Removal

```bash
mise run down
```

**Removal deletes application data**, including the media bucket and database
backups. See [teardown and retention](docs/operations.md#destroy-the-environment).

## Commands

| Command | Purpose |
| --- | --- |
| `mise run setup` | Prepare private deployment settings and discover OCI values. |
| `mise run up` | Create a fresh deployment and wait for public HTTPS. |
| `mise run down` | Remove the application and OCI resources, then retire credentials. |

`ENV_DIR` selects another private deployment directory; the default is
`.local/environment`. Use the same value for every command of one deployment.

## Documentation

- [Getting started](docs/getting-started.md): prerequisites, deployment and access.
- [Operations](docs/operations.md): inspection, failures, billing and teardown.
- [Configuration](docs/configuration.md): optional settings and generated records.
- [Architecture](docs/architecture.md): ownership, configuration, HA and storage.
- [OCI account prerequisites](deploy/oci/README.md): policy for an account administrator.
- [Contributing](CONTRIBUTING.md): local checks, qualification and release selection.
- [Changelog](CHANGELOG.md): command and compatibility changes.
