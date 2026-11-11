# OCI account prerequisites

[Overview](../../README.md) | [Getting started](../../docs/getting-started.md) | [Operations](../../docs/operations.md)

Create a dedicated compartment and an authorised infrastructure provisioner.
Account administrators own these prerequisites. Crossplane creates the storage
user, group, membership and bucket policy during deployment. Storage IAM remains
owned by the Kind bootstrap throughout the demo; OKE needs no user-management
permissions.

## Policy

Create a group for the provisioner user and a policy in the root compartment
with these statements. Replace `<group-ocid>` and `<compartment-ocid>`:

```text
Allow group id <group-ocid> to manage instance-family in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage virtual-network-family in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage volume-family in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage cluster-family in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage load-balancers in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage buckets in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage objects in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage postgres-db-systems in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage postgres-backups in compartment id <compartment-ocid>
Allow group id <group-ocid> to read postgres-configurations in compartment id <compartment-ocid>
Allow group id <group-ocid> to read postgres-work-requests in compartment id <compartment-ocid>
Allow group id <group-ocid> to inspect compartments in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage vaults in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage keys in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage secret-family in compartment id <compartment-ocid>
Allow group id <group-ocid> to manage policies in compartment id <compartment-ocid>
Allow group id <group-ocid> to read domains in tenancy
Allow group id <group-ocid> to inspect users in tenancy where target.resource.domain.name = 'Default'
Allow group id <group-ocid> to inspect groups in tenancy
Allow group id <group-ocid> to manage users in tenancy where target.user.name = /tamoss-storage-*/
Allow group id <group-ocid> to manage groups in tenancy where target.group.name = /tamoss-storage-*/
Allow group id <group-ocid> to inspect compartments in tenancy
```

A provisioner holding only this policy has completed `setup`, deployment,
qualification and teardown; see [verified coverage](../../docs/testing.md#verified-coverage-and-limits).
The last statement supports [setup discovery](#setup-discovery) of availability
domains. Leave it out if you supply `oke.placements` yourself.

| Statements | Purpose |
| --- | --- |
| `instance-family`, `virtual-network-family`, `volume-family`, `cluster-family`, `load-balancers` | OKE, workers, networking and the public load balancer |
| `buckets`, `objects` | Media bucket and its cleanup |
| `postgres-*` | PostgreSQL system, backups and work requests |
| `vaults`, `keys`, `secret-family`, `policies` | Vault foundation, persisted credentials and runtime IAM policies |
| `domains`, `users`, `groups` | The generated storage identity |
| `compartments` in tenancy | Setup discovery of availability domains |

## Storage IAM permissions

The `users` and `groups` statements in the [policy](#policy) let the provisioner
manage identities with the reserved `tamoss-storage-` name prefix. An account
administrator grants them once; deployment does not authorise itself.

Inspection permits discovery and deletion audits; it does not permit changes to
identities outside the reserved prefix. The management grants apply to matching
names across the tenancy; reserve these prefixes for deployment-owned identities.
Identity names come from the deployment ID. Crossplane
creates this policy using the generated group OCID:

```text
Allow group id <generated-storage-group-ocid> to read buckets in compartment id <compartment-ocid> where target.bucket.name = '<bucket-name>'
Allow group id <generated-storage-group-ocid> to manage objects in compartment id <compartment-ocid> where target.bucket.name = '<bucket-name>'
```

The generated user enables Customer Secret Keys only. Crossplane disables console
login and other credential capabilities, suppresses creation notifications and
uses the contact email. The provisioner retains its separate API signing key.
Neither identity is copied to OKE as an infrastructure credential.

Store the provisioner's private signing key and OCI profile in owner-only files.
There is no storage user OCID to enter. The Kind Job creates its key during
deployment and ESO persists the response in
Vault. Keep credential output out of logs and shared manifests. Validate the profile with
the [pinned OCI CLI](../../docs/operations.md#native-oci-cli) and read-only
compartment inventory before deployment; new IAM
credentials and policies can take time to propagate.

## Setup discovery

Configure the signing profile before running `mise run setup`. Missing settings
are filled using read-only OCI lookups. The [policy](#policy) covers them:
`read domains` for the tenancy's identity domains, `inspect compartments in
tenancy` for availability domains, and the compartment's `cluster-family` grant
for the OKE image lookup. That lookup is made in the deployment compartment when
`compartmentId` is known, so pass `--compartment-id` to `setup` or enter the
value first. Without it the lookup is tenancy-wide and needs wider access than
this policy grants. Supply a setting explicitly to skip its lookup.

Setup also reads the Object Storage namespace and regional service-gateway
catalogue. It writes the selected identifiers into the private settings file;
it does not change account permissions or create OCI resources.

## Deployment asset access

Flux in Kind reads this repository at the selected Git commit and consumes the
operators' pinned public OCI artifacts. Private Git access uses a read-only
repository deploy key. No OCI asset-reader identity or Vault delivery is created.

## Retirement

Retain provisioner access until `mise run down` has verified deletion. After
workload and bucket cleanup, `down` revokes the recorded storage key and verifies
its absence. Crossplane then deletes the deployment's storage policy, membership, group and
user before Vault secrets are retired. Unrecorded keys block identity deletion.
OCI requires the group to be empty; provider reconciliation retries group
deletion until its membership is removed.
The original compartment and provisioner remain administrator-owned. Retire
temporary account prerequisites through the administrator's credential workflow
only after all deployment cleanup has completed.

[Deployment from Git](../gitops/README.md) uses the Vault/key, secret and
runtime-policy permissions above. The retained
foundation has an explicit owner and prevents treating the compartment as empty
after workload teardown. Billing access is separate; see
[posted billing](../../docs/operations.md#posted-billing).

Oracle documents the [OKE permissions](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengpolicyconfig.htm),
[PostgreSQL resource types](https://docs.oracle.com/en-us/iaas/Content/postgresql/policies.htm)
and [bucket conditions](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/objectstoragepolicyreference.htm).
Its [IAM API permissions](https://docs.oracle.com/en-us/iaas/Content/Identity/policyreference/iampolicyreference.htm)
define the required Customer Secret Key permissions.
The [Vault permission reference](https://docs.oracle.com/en-us/iaas/Content/Identity/policyreference/keypolicyreference.htm)
includes `VAULT_CREATE_SECRET`, which is required for ESO persistence even when
the Vault already exists.
