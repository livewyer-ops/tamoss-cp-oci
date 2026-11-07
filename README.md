# TAMOSS on OCI Kubernetes Engine

Crossplane configuration and deployment tooling for
[TAMOSS](https://github.com/livewyer-ops/tamoss) on Oracle Cloud Infrastructure
(OCI). TAMOSS implements the BBC Time-addressable Media Store (TAMS) API.

The deployment runs TAMOSS's `multi-server` profile on OKE with external
PostgreSQL, private Object Storage, Authentik and public HTTPS. It is intended
for HA deployments and qualification environments.

## Deployment

| Component | Configuration |
| --- | --- |
| Management | Kind owns infrastructure until optional GitOps handover to OKE; retain original Kind for teardown |
| Kubernetes | OKE with three workers and explicit failure-domain placement |
| Application | Replicated TAMOSS API, worker, UI and Console API |
| PostgreSQL | Two OCI database nodes; separate TAMOSS and Authentik databases, with verified TLS |
| Media storage | Private OCI Object Storage bucket through its S3-compatible endpoint |
| Public access | OCI load balancer, replicated ingress and Authentik, trusted HTTPS |
| Release assets | Verified TAMOSS release and matching source archive, consumed unchanged |

The environment uses billable resources. Worker-drain checks have passed;
managed-database failover and regional recovery are outside the verified
coverage. See [architecture](docs/architecture.md) and [testing](docs/testing.md).

[GitOps integration](deploy/gitops/README.md) transfers ongoing operations to
Flux, Crossplane and External Secrets on OKE. The Flux-managed Kind bootstrap,
OKE bootstrap Job and Vault-delivered adoption bindings have run on OCI, with
application qualification while Kind was stopped. The run required IAM propagation
retries, host transfer corrections and certificate renewal; an uninterrupted
lifecycle remains unqualified. The Git-free seed and SSH handover require fresh OCI qualification. Release
upgrades and credential rotation also remain unqualified.

[Optional TADOSS integration](deploy/tadoss/README.md) adds timed metadata services
through the environment Git repository, using the same platform services. Live
checks passed with Kind stopped: authenticated metadata linked to ingested media,
persistence after pod replacement and unchanged OCI infrastructure. The OAuth
Job completed on its first attempt without replacing Authentik pods; see the
[qualification limits](docs/testing.md#verified-coverage-and-limits).

## Quickstart

Install [mise](https://mise.jdx.dev/installing-mise.html) and check the
[workstation prerequisites](docs/getting-started.md#workstation-prerequisites), then:

```bash
git clone https://github.com/dodwyer/tamoss-cp-oci.git
cd tamoss-cp-oci
mise trust
mise install --locked
mise run setup
```

Complete [Getting started](docs/getting-started.md) with an OCI profile, S3 key pair,
compartment, contact email and administrator CIDR. Then deploy:

```bash
mise run up
```

The quick deployment requires no GitHub account or environment repository. Flux
reconciles pinned public product assets with the supplied configuration. Kind
retains infrastructure ownership; TAMOSS runs on OKE. `up` prints the URLs and
location of protected initial login details.

To demonstrate GitOps, configure the optional GitHub owner in `gitops.yaml`:

```bash
mise exec -- gh auth login --hostname github.com --git-protocol https
mise run handover
```

Handover publishes the existing configuration to a private repository, establishes
a read-only SSH deploy key, transfers infrastructure ownership to OKE and stops
original Kind. Then enable [TADOSS through Git](deploy/tadoss/README.md#enable-through-git).

Qualification replaces its test media and drains one worker. Follow the
[access instructions](docs/getting-started.md#access) to sign in and inspect the
ingest result. Keep the original Kind and environment directory until cleanup.

## Commands

| Command | Purpose |
| --- | --- |
| `mise run setup` | Install the pinned OCI CLI and create private settings without overwriting existing deployment state. |
| `mise run check` | Validate releases, rendering, TLS and local contracts. |
| `mise run check:management` | Also test a disposable, credential-free Kind bootstrap. |
| `mise run check:storage` | Test a real OCI bucket in a separately authorised compartment. |
| `mise run check:storage:cleanup` | Finish an interrupted storage probe's cleanup. |
| `mise run up` | Provision OCI and install TAMOSS with public TLS ready; Kind retains infrastructure ownership. |
| `mise run handover` | Attach GitOps, transfer infrastructure ownership to OKE and stop original Kind. |
| `mise run qualify` | Test ingest, access, network isolation and a worker drain. |
| `mise run down` | Return ownership if needed, delete hardware and retire secrets through original Kind. |

`ENV_DIR` selects the private deployment directory; `CHECKOUT` selects its environment
Git checkout (default `.local/gitops`). Storage checks have separate
inputs; see [Testing](docs/testing.md#oci-storage-check).
The environment stays running until explicitly removed with `mise run down`.
**Teardown deletes application data**, including the owned bucket and database
backups. See [teardown and retention](docs/operations.md#destroy-the-environment).

## Documentation

- [Getting started](docs/getting-started.md): workstation, OCI setup, deployment and access.
- [Operations](docs/operations.md): inspection, retries, billing and teardown.
- [Testing](docs/testing.md): local and deployed checks, reports and coverage limits.
- [Architecture](docs/architecture.md): ownership, configuration, HA and storage.
- [Changelog](CHANGELOG.md): command and compatibility changes.
- [TAMOSS integration](deploy/tamoss/README.md): immutable assets and release selection.
- [GitOps integration](deploy/gitops/README.md): repositories, secret delivery and ownership transfer.
