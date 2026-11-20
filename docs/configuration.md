# Configuration

`mise run setup` creates `${ENV_DIR:-.local/environment}/values.yaml` from the [example](../environments/example/values.yaml). Set `compartmentId` and `contactEmail` before deployment. The [management chart defaults](../charts/management/values.yaml) and [schema](../charts/management/values.schema.json) define the available fields.

## Discovered settings

| Setting | Default when empty |
| --- | --- |
| `adminCidrs` | Workstation public IPv4 address as a `/32` allowlist |
| `storageIdentity.domainId`, `storageIdentity.idcsEndpoint` | Active Default identity domain |
| `storage.namespace` | Tenancy's Object Storage namespace |
| `network.ociServiceId`, `network.ociServiceCidr` | Regional All Services network |
| `oke.imageId` | Highest standard Oracle Linux 8 x86-64 OKE build for the selected Kubernetes version, subject to worker shape availability |
| `oke.placements` | Three workers distributed across the available domains, using separate fault domains when reusing an availability domain |

To override discovery, set a value before `setup`. To refresh it, clear the value and run `setup` again before `up`. Change the identity-domain and service-network fields in pairs. Use the same OCI profile and region for deployment.

## Optional settings

| Setting | Default or effect |
| --- | --- |
| `name` | `media-demo`. Choose an unused name of 3–23 lowercase letters, digits or hyphens. Start with a letter and end with a letter or digit. |
| `owner`, `acmeEmail`, `adminEmail` | Default to `contactEmail` |
| `storage.bucket` | `tamoss-<name>-media` |
| `source.private` | `true` uses a GitHub deploy key. Set `false` for anonymous HTTPS. |
| `tadoss.enabled` | `false`. Enable before `up` or through the [environment Git repository](operations.md#keep-settings-in-an-environment-repository). |
| `foundation.name` | `<name>-vault`. To reuse a Vault and key, supply the recorded `foundation.adoption` fields as proof of ownership. |

Keep subnets within the VCN. After `up`, [apply changes](operations.md#change-settings) only to OKE-managed settings. The original network, cluster identity and Vault bindings are fixed.

## Deployment records

Keep the entire private deployment directory. Use `remote.kubeconfig` to inspect OKE, `source.json` to identify the deployed Git commit, and `identity.yaml` and `foundation-record.yaml` to verify ownership. After `down`, check `inventory-after/` and `retained-foundation.yaml` before retiring the provisioner's credentials.
