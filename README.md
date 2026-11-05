# TAMOSS on OCI Kubernetes Engine

Crossplane configuration and deployment tooling for
[TAMOSS](https://github.com/livewyer-ops/tamoss) on Oracle Cloud Infrastructure
(OCI). TAMOSS implements the BBC Time-addressable Media Store (TAMS) API.

The deployment runs TAMOSS's `multi-server` profile on OKE with external
PostgreSQL, private Object Storage, Authentik and public HTTPS. It is intended
for temporary HA qualification environments.

## Deployment

| Component | Configuration |
| --- | --- |
| Management | Kind bootstraps; Flux and Crossplane on OKE operate; retain original Kind for teardown |
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
Flux, Crossplane and External Secrets on OKE. The preceding bootstrap, repeat,
qualification and teardown have passed, including Kind-off operation. The new
Flux-managed Kind bootstrap, the OKE bootstrap Job and Vault-delivered adoption bindings require fresh OCI qualification. Release
upgrades and package-credential rotation remain unqualified.

[Optional TADOSS integration](deploy/tadoss/README.md) adds timed metadata services
through the environment Git repository, using the same platform services. Live
checks passed with Kind stopped: authenticated metadata linked to ingested media,
persistence after pod replacement and unchanged OCI infrastructure. Authentik
workers required an automatic startup retry; see the
[qualification limits](docs/testing.md#verified-coverage-and-limits).

## Quickstart

Install [Aqua](https://aquaproj.github.io/docs/install/) and check the
[workstation prerequisites](docs/getting-started.md#workstation-prerequisites), then:

```bash
git clone https://github.com/dodwyer/tamoss-cp-oci.git
cd tamoss-cp-oci
aqua install
export PATH="$(aqua root-dir)/bin:$PATH"
uv tool install --python 3.12 "oci-cli==$(yq -r .oci.version dependencies.yaml)"
export PATH="$(aqua root-dir)/bin:$(uv tool dir --bin):$PATH"
task check
```

Complete [Getting started](docs/getting-started.md) to prepare OCI access,
private environment inputs, an environment Git checkout and a bounded spending allowance before deploying:

```bash
task up ENV_DIR=.local/environment CHECKOUT=.local/gitops
task qualify ENV_DIR=.local/environment CHECKOUT=.local/gitops
```

Qualification replaces its test media and drains one worker. Follow the
[access instructions](docs/getting-started.md#access) to sign in and inspect the
ingest result. Keep the original Kind and environment directory until cleanup.

## Commands

| Command | Purpose |
| --- | --- |
| `task check` | Validate releases, rendering, TLS and local contracts. |
| `task check:management` | Also test a disposable, credential-free Kind bootstrap. |
| `task check:storage` | Test a real OCI bucket in a separately authorised compartment. |
| `task check:storage:cleanup` | Finish an interrupted storage probe's cleanup. |
| `task up` | Provision OCI, publish GitOps configuration, install TAMOSS and stop Kind. |
| `task qualify` | Test ingest, access, network isolation and a worker drain. |
| `task down` | Return current ownership to Kind, delete hardware and retire secrets. |

`ENV_DIR` selects the private deployment directory; `CHECKOUT` selects its environment
Git checkout (default `.local/gitops`). Storage checks have separate
inputs; see [Testing](docs/testing.md#oci-storage-check).
**Teardown deletes application data**, including the owned bucket and database
backups. See [teardown and retention](docs/operations.md#destroy-the-environment).

## Documentation

- [Getting started](docs/getting-started.md): workstation, OCI setup, deployment and access.
- [Operations](docs/operations.md): inspection, retries, billing and teardown.
- [Testing](docs/testing.md): local and deployed checks, reports and coverage limits.
- [Architecture](docs/architecture.md): ownership, configuration, HA and storage.
- [TAMOSS integration](deploy/tamoss/README.md): immutable assets and release selection.
- [GitOps integration](deploy/gitops/README.md): repositories, secret delivery and ownership transfer.
