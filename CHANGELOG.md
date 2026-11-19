# Changelog

## Unreleased

First public release.

- `mise run setup` prepares the private deployment settings and discovers the
  missing OCI values: identity domain, Object Storage namespace, service
  network, OKE image, worker placements and the workstation's public IPv4
  allowlist.
- `mise run up` creates a fresh deployment from a pushed commit of this
  repository. A local Kind cluster creates the Vault secrets, IAM, network and
  OKE cluster, then stops. Flux and Crossplane in OKE create the PostgreSQL
  system and media bucket with OKE workload identity and install the platform,
  TAMOSS and optional TADOSS.
- `mise run apply` applies changed settings to OKE without Kind and refuses
  changes to the resources `up` created.
- `mise run handover` moves the settings to a private GitHub repository that
  Flux in OKE follows.
- `mise run down` starts Kind again, removes the applications, empties the
  bucket and deletes the database backups from Jobs in OKE, removes the
  infrastructure, retires the credentials and audits the compartment.
- `mise run account:create` and `account:remove` let an administrator create
  and remove a provisioner limited to the published policy.
- `mise run check`, `check:management` and `qualify` cover local contracts,
  controller behaviour in disposable Kind clusters and a running deployment.
