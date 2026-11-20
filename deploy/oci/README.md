# OCI account prerequisites

Use a dedicated compartment with quota for OKE, PostgreSQL, networking, storage and a load balancer. An OCI account administrator creates the compartment and grants access to a provisioner. Use the provisioner's API signing profile for deployment.

## Create the provisioner

Select an administrator OCI profile. Set `COMPARTMENT_OCID` to the dedicated compartment OCID and `CONTACT_EMAIL` to the provisioner contact address, then run:

```bash
mise run account:create --compartment-id "$COMPARTMENT_OCID" --contact-email "$CONTACT_EMAIL"
```

The command creates a user, group, policy and API signing key. It writes the owner-only provisioner profile and key to `.local/account/tamoss-provisioner/`. Set `OCI_CLI_CONFIG_FILE` to the generated `oci-config` and select its `DEFAULT` profile for [deployment](../../docs/getting-started.md#configure-oci-access). Use `--name` for a separately named provisioner.

## Policy

For manual provisioning, create the group and assign the following policy in the root compartment. Substitute the group and compartment OCIDs. The account task reads the same [policy template](policy.txt).

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

Pass the compartment OCID to `setup` so the OKE image lookup uses this grant. The tenancy-wide compartment inspection supports availability-domain discovery. If the administrator omits it, supply `oke.placements` explicitly.

## Storage IAM permissions

Reserve the `tamoss-storage-` user and group name prefix across the tenancy. Kind creates one storage identity per deployment, restricts it to Customer Secret Keys and grants its group read access to the named media bucket and object management inside that bucket. OKE uses workload identity for the database and bucket lifecycle.

## Retirement

Keep the provisioner until [teardown](../../docs/operations.md#destroy-the-environment) verifies the final OCI inventory. Retain the compartment, Vault, encryption key and ownership record. To remove a temporary provisioner, select the original **administrator** OCI profile and run:

```bash
mise run account:remove
```

If you used `--name` at creation, pass the same name at removal. This removes the provisioner's key, policy, membership, group, user and local credentials.
