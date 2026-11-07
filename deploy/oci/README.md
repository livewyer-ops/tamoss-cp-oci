# OCI account prerequisites

[Overview](../../README.md) | [Getting started](../../docs/getting-started.md) | [Operations](../../docs/operations.md)

Create a dedicated compartment and separate identities for infrastructure
provisioning and application storage. Account administrators own these
prerequisites; Crossplane owns the environment resources inside the compartment.
Use the native OCI Console or OCI CLI with the administrator's credentials to
create the compartment, users, groups, memberships and policies.

The provisioner needs an API signing key and these permissions in the dedicated
compartment:

| Verb | Resource types |
| --- | --- |
| manage | `instance-family`, `virtual-network-family`, `volume-family`, `cluster-family`, `load-balancers`, `buckets`, `objects`, `postgres-db-systems`, `postgres-backups` |
| read | `postgres-configurations`, `postgres-work-requests` |
| inspect | `compartments` |

Each permission becomes an IAM statement, for example:

```text
Allow group id <provisioner-group-ocid> to manage cluster-family in compartment id <compartment-ocid>
```

Use a separate storage identity with a Customer Secret Key. Its group needs only
these statements for the bucket named in `environment.yaml`:

```text
Allow group id <storage-group-ocid> to read buckets in compartment id <compartment-ocid> where target.bucket.name = '<bucket-name>'
Allow group id <storage-group-ocid> to manage objects in compartment id <compartment-ocid> where target.bucket.name = '<bucket-name>'
```

Disable unused user capabilities, including console login. The provisioner needs
API keys; the storage identity needs Customer Secret Keys. Avoid generating
console passwords or authentication tokens. For identity-domain users, honour
the domain's primary-email requirement and suppress account notifications for
these service identities using the native `bypassNotification` creation field.

Store the provisioner's private signing key and OCI profile in owner-only files.
Capture the storage key's identifier and secret once into the private files
listed in [Storage credentials](../../docs/getting-started.md#storage-credentials). Keep all
credential output out of logs and shared manifests. Validate the profile with
the [pinned OCI CLI](../../docs/operations.md#native-oci-cli) and read-only
compartment inventory before deployment; new IAM
credentials and policies can take time to propagate.

## Retirement

Retain these identities, policies and keys until `mise run down` has verified cloud
deletion. For temporary account prerequisites owned by the run, revoke the keys,
remove memberships and policies, delete the users/groups, then delete the empty
compartment through the administrator's credential workflow. Record identifiers
privately so cleanup does not depend on matching names.

The [GitOps workflow](../gitops/README.md#inputs-and-secret-delivery)
also requires scoped Vault/key, secret and runtime-policy permissions. Its retained
foundation has an explicit owner and prevents treating the compartment as empty
after workload teardown. Billing access is separate; see
[posted billing](../../docs/operations.md#posted-billing).

Oracle documents the [OKE permissions](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengpolicyconfig.htm),
[PostgreSQL resource types](https://docs.oracle.com/en-us/iaas/Content/postgresql/policies.htm)
and [bucket conditions](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/objectstoragepolicyreference.htm).
