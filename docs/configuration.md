# Configuration

[Overview](../README.md) | [Getting started](getting-started.md) | [Operations](operations.md) | [Architecture](architecture.md)

The private settings file is `values.yaml` in the deployment directory.
`mise run setup` creates it from the [example settings](../environments/example/values.yaml).
The [chart defaults](../charts/management/values.yaml) supply HA capacity,
network ranges, PostgreSQL settings and the OKE version. The
[settings schema](../charts/management/values.schema.json) validates the file
during `up`.

## Discovered settings

`setup` fills each missing setting with a read-only lookup using the selected
OCI profile:

| Setting | Lookup |
| --- | --- |
| `storageIdentity.domainId`, `storageIdentity.idcsEndpoint` | The single active Default identity domain |
| `storage.namespace` | The tenancy's Object Storage namespace |
| `network.ociServiceId`, `network.ociServiceCidr` | The regional All Services network |
| `oke.imageId` | The highest OKE build among standard Oracle Linux 8 x86-64 images for the configured Kubernetes version; the configured worker shape must be offered |
| `oke.placements` | Three workers across the sorted availability domains, with separate fault domains when an availability domain is reused |
| `adminCidrs` | The workstation's public IPv4 address from `https://api.ipify.org`, as a `/32` |

Supplied values are preserved and skip their lookups, so you can fill in
`values.yaml` before `setup` to override discovery. To refresh a discovered
value before deployment, remove it or set it empty and rerun `setup`. Remove
both fields together when changing the identity domain or service network.
Failed discovery leaves the settings file unchanged.

`setup` refuses a directory that already holds a deployment. Keep the OCI
profile and region the same between `setup` and `up`. Discovery does not reserve
capacity. The lookups need the tenancy-level inspect statements in the
[account policy](../deploy/oci/README.md#policy); without them, supply the
corresponding settings yourself.

## Optional settings

```yaml
name: another-demo
owner: platform-team@example.com
acmeEmail: certificates@example.com
tadoss:
  enabled: true
storage:
  bucket: my-authorised-media-bucket
source:
  private: false
```

| Setting | Default and effect |
| --- | --- |
| `name` | `media-demo`. Names have 3-23 lowercase letters, digits or hyphens, starting with a letter and ending with a letter or digit. Use an unused name for each deployment |
| `owner`, `acmeEmail`, `adminEmail` | `contactEmail` |
| `tadoss.enabled` | `false`. Set before deployment to include TADOSS |
| `storage.bucket` | `tamoss-<name>-media` |
| `source.private` | `true`. Set `false` for a public repository to skip the deploy key |
| `foundation.name` | `<name>-vault` |

Network, worker placement and image, sizing and database overrides are validated
against the settings schema. Keep subnets inside the selected VCN. Reuse an
owned Vault and key through `foundation.name` and the recorded
`foundation.adoption` fields; a matching name is not proof of ownership.

Change settings only before `up`. Keep them unchanged during installation.

## Generated records

| Record | Location in the deployment directory |
| --- | --- |
| Deployment input | `values.yaml` |
| Deployment identity, OCI profile identifiers and Git source | `deployment.yaml`, `source.json` |
| Kind seed overlay | `kustomization.yaml`, `source.yaml`, `release.yaml` |
| Local copies of the resources Kind derives | `bootstrap.yaml`, `environment.yaml`, `foundation.yaml`, `settings.yaml` |
| Temporary protected OCI signing material | `discovery/`, removed after seeding Kind |
| Management and OKE access | `management.kubeconfig`, `remote.kubeconfig` |
| Initial login details | `access/ui-login.json` |
| Installed release and deployment identity | `tamoss-release.yaml`, `identity.yaml` |
| Ownership and teardown records | `identity.yaml`, `foundation-record.yaml`, `inventory-after/` |
| Qualification outputs and reports | `outputs.json`, `reports/` |

`source.json` records the repository and Git commit. Commit and push source
edits before a fresh deployment. Existing deployments must keep their deployed
product revision for operations and teardown; this layout does not migrate them.
