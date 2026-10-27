# Architecture

[Overview](../README.md) | [Getting started](getting-started.md) | [Operations](operations.md) | [Testing](testing.md)

The public lifecycle uses Crossplane on local Kind to provision an OKE environment.
Helmfile installs the platform on OKE; Kustomize applies the published TAMOSS
operator and the `multi-server` instance. The original Kind holds management
state and is required for reconciliation and teardown.

```mermaid
flowchart LR
    Inputs[Private environment inputs] --> Kind[Kind / Crossplane]
    Kind --> OCI[OKE, networking, PostgreSQL and bucket]
    Release[Verified TAMOSS release] --> Install[Helmfile / Kustomize]
    OCI --> Install
    Install --> Operator[TAMOSS operator on OKE]
    Operator --> App[API, worker, UI, Console and ingest]
    Git[Environment Git repository] -. Internal GitOps workflow .-> Flux[Flux on OKE]
    Flux -. After verified handover .-> Runtime[Crossplane and External Secrets on OKE]
    Runtime -. Ongoing reconciliation .-> OCI
    Vault[OCI Vault] -. Persisted secrets .-> Runtime
    Flux -. Release reconciliation .-> Operator
```

The [GitOps integration](../deploy/gitops/README.md) has passed live ownership
transfer, workload authentication, persisted secret delivery and operations with
Kind stopped. Release upgrade and package-read credential rotation/revocation
remain unqualified. Its internal tasks have not replaced the public lifecycle.

## Ownership

| Owner | Responsibility |
| --- | --- |
| Account administrator | Dedicated compartment, scoped OCI identities, policies and signing/storage keys |
| Kind and Crossplane | One environment composite owning networking, OKE/node pools, PostgreSQL, bucket and reserved IP |
| OKE cloud controller | Load balancer created by the ingress `LoadBalancer` Service |
| Helmfile and Kustomize | Platform releases, local HA/OCI overlays and TAMOSS declarations |
| TAMOSS operator | Application workloads, runtime images, schema migrations, StorageBackend and IngestRun Jobs |
| Database bootstrap Job | Separate TAMOSS and Authentik databases and login roles |
| Operator of this environment | Spending deadline, qualification, retained records and verified cleanup |

In the internal GitOps lifecycle, Flux takes release ownership and Crossplane on
OKE takes infrastructure ownership through observe-only adoption and exact
provider bindings. Only one control plane may write at a time. The original Kind
is retained without write authority, stopped, and later receives current Git/live
configuration for deletion. This does not recover lost Kind state.

The OKE PostgreSQL provider polls every minute so observe-only adoption can
refresh status within the five-minute readiness check. Its first observation
can lose status when the provider adds its Kubernetes finaliser. The next poll
restores it without restarting the provider; Ready, Synced and identity checks
still control ownership transfer.

The optional [TADOSS integration](../deploy/tadoss/README.md) uses the same OKE,
PostgreSQL, authentication, ingress and secret services. Git enables its released
operator and API/worker replicas, a separate database/role and an OAuth client.
TADOSS owns its schema migrations and stores timed metadata referencing TAMS
media. This repository owns the platform configuration; both upstream products
are consumed read-only. Git enablement, authenticated linked-media checks and
persistence after pod replacement passed with Kind stopped. OCI resource IDs
remained unchanged across enablement. See the [qualification limits](testing.md#verified-coverage-and-limits).

## Configuration flow

| Source | Purpose |
| --- | --- |
| [Environment examples](../environments/example/) | Private region, placement, capacity, settings and cost inputs |
| [Environment schema](../charts/environment/definition.yaml) | Typed infrastructure contract and immutable fields |
| [dependencies.yaml](../dependencies.yaml), [aqua.yaml](../aqua.yaml) | Infrastructure component selections/checksums and workstation tools |
| [TAMOSS release lock](../deploy/tamoss/release.yaml) | Verified release record and matching source archive |
| [TAMOSS integration](../deploy/tamoss/README.md) | Platform settings, instance overlays, database bootstrap and qualification assets |

Crossplane observations become `outputs.json`; verified database connection
details provide the hostname and CA. Runtime rendering derives sslip.io hostnames
from the reserved IP and writes the instance settings. Edit source inputs only
within their lifecycle constraints; generated files are overwritten.

TAMOSS's upstream manifests, charts, profile and tests are consumed unchanged from
the selected release. A sibling checkout is unnecessary. The operator's release
catalogue owns application image digests and schema revisions. See
[release selection](../deploy/tamoss/README.md#release-selection).

## Availability and external services

Three OKE workers use explicit availability/fault-domain placements. Application,
authentication, ingress and operator replicas use worker separation and disruption
budgets. The API and authentication servers delay shutdown for endpoint withdrawal;
ingress allows the OCI backend to be withdrawn before it stops accepting requests.

Both TAMOSS and Authentik use the provisioned, two-node OCI PostgreSQL system.
Separate roles/databases share its endpoint. Consumers verify the server's
certificate and hostname using the retrieved CA. The bootstrap Job creates roles
and databases; TAMOSS owns its schema migrations. Database backups follow the
configured retention, but teardown deletes the owned system and its backups.

The private OCI bucket stores media. TAMOSS registers it through an external
StorageBackend and uses the S3-compatible HTTPS endpoint for application and
browser media access. A separate bucket-scoped Customer Secret Key supplies
storage access. Qualification's ingest source is restricted to its input prefix.

Worker-drain availability has passed live checks. That result does not establish
managed-database failover, regional recovery or management-state restoration.
See the [coverage limits](testing.md#verified-coverage-and-limits).

## Secrets and retained state

The public lifecycle keeps owner-only credential inputs in the private environment
directory and delivers Kubernetes Secrets. Existing credentials are reused; missing
values stop deployment. OCI API credentials stay on the workstation and in Kind's
provider configuration.

The internal GitOps workflow creates a separately retained OCI Vault/key from
Kind. External Secrets persists initial values, reads them back and delivers them
to OKE using scoped workload identities. Git contains non-secret configuration and
provider bindings. The environment repository contains neither TAMOSS source nor
secret payloads. See [secret delivery](../deploy/gitops/README.md#inputs-and-secret-delivery).

Keep original Kind state, deployment identity, release records and cloud inventory
until deletion is verified. [Operations](operations.md#destroy-the-environment)
lists the resources deleted and retained by each lifecycle.
