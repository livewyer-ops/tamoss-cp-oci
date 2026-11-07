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
| manage | `vaults`, `keys`, `secret-family`, `policies` |
| read | `postgres-configurations`, `postgres-work-requests` |
| inspect | `compartments` |

Each permission becomes an IAM statement, for example:

```text
Allow group id <provisioner-group-ocid> to manage cluster-family in compartment id <compartment-ocid>
```

Use a separate storage identity. Its group needs only
these statements for the bucket named in `environment.yaml`:

```text
Allow group id <storage-group-ocid> to read buckets in compartment id <compartment-ocid> where target.bucket.name = '<bucket-name>'
Allow group id <storage-group-ocid> to manage objects in compartment id <compartment-ocid> where target.bucket.name = '<bucket-name>'
```

The provisioner creates and retires the deployment's Customer Secret Key for this
user. Scope its IAM permission to that exact user:

```text
Allow group id <provisioner-group-ocid> to manage users in tenancy where all {target.user.id = '<storage-user-ocid>', any {request.permission = 'USER_READ', request.permission = 'USER_UPDATE', request.permission = 'USER_SECRETKEY_ADD', request.permission = 'USER_SECRETKEY_REMOVE'}}
```

Oracle requires `USER_UPDATE` alongside the key permissions; it also permits
updates to that user's metadata and capabilities. Keep the storage user separate
from the provisioner. Leave a Customer Secret Key slot available; OCI permits two
per user. The deployment never deletes an unrelated key to make room.

Disable unused user capabilities, including console login. The provisioner needs
API keys; the storage identity needs Customer Secret Keys. Avoid generating
console passwords or authentication tokens. For identity-domain users, honour
the domain's primary-email requirement and suppress account notifications for
these service identities using the native `bypassNotification` creation field.

Store the provisioner's private signing key and OCI profile in owner-only files.
Set the storage user OCID in [Storage identity](../../docs/getting-started.md#storage-identity).
The Kind Job creates its key during deployment and ESO persists the response in
Vault. Keep credential output out of logs and shared manifests. Validate the profile with
the [pinned OCI CLI](../../docs/operations.md#native-oci-cli) and read-only
compartment inventory before deployment; new IAM
credentials and policies can take time to propagate.

## Retirement

Retain these identities, policies and keys until `mise run down` has verified cloud
deletion. `down` revokes the deployment-created storage key after workload deletion
and verifies its absence before retiring Vault secrets. It retains the storage
user and unrelated keys. For temporary account prerequisites owned by the run, revoke remaining keys,
remove memberships and policies, delete the users/groups, then delete the empty
compartment through the administrator's credential workflow. Record identifiers
privately so cleanup does not depend on matching names.

Both quick deployment and [GitOps](../gitops/README.md#inputs-and-secret-delivery)
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
