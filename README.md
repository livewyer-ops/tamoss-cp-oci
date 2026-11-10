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
| Management | Flux and Crossplane in Kind own deployment and teardown |
| Kubernetes | OKE with three workers and explicit failure-domain placement |
| Application | Replicated TAMOSS API, worker, UI and Console API |
| PostgreSQL | Two OCI database nodes; separate TAMOSS and Authentik databases, with verified TLS |
| Media storage | Private OCI Object Storage bucket through its S3-compatible endpoint |
| Public access | OCI load balancer, replicated ingress and Authentik, trusted HTTPS |
| Release assets | This repository at a pushed commit, official charts and pinned upstream artifacts |

The environment uses billable resources. Worker-drain checks have passed;
managed-database failover and regional recovery are outside the verified
coverage. See [architecture](docs/architecture.md) and [testing](docs/testing.md).

[Deployment from Git](deploy/gitops/README.md) follows Host -> Kind -> OKE.
Flux in Kind reads this repository and manages OKE remotely. Crossplane provisions
OCI resources from Kind. The host supplies OKE access; no second Flux or Crossplane
stack is installed in OKE. A removable read-only deploy key allows private Git
access. Fresh OCI deployment, application qualification and teardown have passed;
[testing](docs/testing.md#verified-coverage-and-limits) records the coverage and limits.

[Optional TADOSS integration](deploy/tadoss/README.md) adds timed metadata services
using the same platform. Enable it in the private settings before deployment.

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

Complete [Getting started](docs/getting-started.md) with an authorised OCI profile,
dedicated empty compartment and prepared tenancy/region settings in `values.yaml`.
Then deploy:

```bash
mise run up
```

Use a clean, committed and pushed checkout. While this repository is private,
[authenticate GitHub CLI](deploy/gitops/README.md#private-repository-authentication)
on the host before `up`. Flux receives a dedicated read-only deploy key. `up`
prints application URLs and the location of private initial login details.

Each `up` requires a fresh deployment directory. After an interrupted installation,
follow [failed-deployment cleanup](docs/operations.md#clean-up-a-failed-deployment)
before starting again. Keep Kind running throughout the demo.

Qualification replaces its test media and drains one worker. Follow the
[access instructions](docs/getting-started.md#access) to sign in and inspect the
ingest result. Keep the original Kind and environment directory until cleanup.

## Commands

| Command | Purpose |
| --- | --- |
| `mise run setup` | Create private settings without overwriting existing deployment state. |
| `mise run check` | Validate releases, rendering, TLS and local contracts. |
| `mise run check:management` | Also test controller reconciliation in disposable Kind clusters. |
| `mise run check:storage` | Test a real OCI bucket in a separately authorised compartment. |
| `mise run check:storage:cleanup` | Finish an interrupted storage probe's cleanup. |
| `mise run up` | Create a fresh deployment with public TLS ready; Kind retains infrastructure ownership. |
| `mise run qualify` | Test ingest, access, network isolation and a worker drain. |
| `mise run down` | Delete workloads and infrastructure through Kind, then retire credentials. |

`ENV_DIR` selects the private deployment directory. Storage checks have separate
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
- [GitOps integration](deploy/gitops/README.md): execution context, chart sources and private Git access.
