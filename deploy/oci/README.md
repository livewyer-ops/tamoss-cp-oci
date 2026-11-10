# OCI account prerequisites

[Overview](../../README.md) | [Getting started](../../docs/getting-started.md) | [Operations](../../docs/operations.md)

Create a dedicated compartment and an authorised infrastructure provisioner.
Account administrators own these prerequisites. Crossplane creates the storage
user, group, membership and bucket policy during deployment. Storage IAM remains
owned by the Kind bootstrap throughout the demo; OKE needs no user-management
permissions.

The provisioner needs an API signing key and these permissions in the dedicated
compartment:

| Verb | Resource types |
| --- | --- |
| manage | `instance-family`, `virtual-network-family`, `volume-family`, `cluster-family`, `load-balancers`, `buckets`, `objects`, `postgres-db-systems`, `postgres-backups` |
| manage | `vaults`, `keys`, `secret-family`, `policies` |
| read | `postgres-configurations`, `postgres-work-requests` |
| inspect | `compartments` |

Each permission becomes an IAM statement, for example:

```text
Allow group id <provisioner-group-ocid> to manage cluster-family in compartment id <compartment-ocid>
```

## Storage IAM permissions

Setup discovers the active Default identity domain's OCID and endpoint in `values.yaml`.
The provisioner needs permission to manage users/groups with the reserved
`tamoss-storage-` name prefix. An account administrator grants these permissions
once; deployment does not authorise itself:

```text
Allow group id <provisioner-group-ocid> to inspect users in tenancy where target.resource.domain.name = 'Default'
Allow group id <provisioner-group-ocid> to inspect groups in tenancy
Allow group id <provisioner-group-ocid> to manage users in tenancy where target.user.name = /tamoss-storage-*/
Allow group id <provisioner-group-ocid> to manage groups in tenancy where target.group.name = /tamoss-storage-*/
```

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
are filled using read-only OCI lookups. The profile needs `DOMAIN_INSPECT` for
the tenancy's identity domains, `COMPARTMENT_INSPECT` for availability-domain
discovery, and `INSTANCE_INSPECT` for the unscoped OKE node-pool options lookup.
Compartment-scoped provisioning grants alone may not cover these lookups.
Account administrators can grant tenancy-level inspection of `domains`,
`compartments` and `instances`, or supply the corresponding settings explicitly
so setup skips those requests. Oracle lists the permissions for
[IAM discovery](https://docs.oracle.com/en-us/iaas/Content/Identity/policyreference/iampolicyreference.htm)
and [OKE node-pool options](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/contengpolicyreference.htm).

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

Both quick deployment and [GitOps](../gitops/README.md)
use the Vault/key, secret and runtime-policy permissions above. The retained
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
