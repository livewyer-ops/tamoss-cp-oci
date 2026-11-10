# Changelog

## Unreleased

- Keep Flux and Crossplane in Kind through deployment and teardown. Flux deploys
  the platform and applications remotely to OKE.
- Read this repository at a pushed Git commit and build chart directories with
  Flux. Remove custom deployment bundle/chart publication and ownership handover.
- Add removable read-only SSH deploy-key authentication for the private repository;
  public deployments use anonymous HTTPS.
- Run database metadata lookup and retirement operations in Kind. Retain and renew
  OKE access until remote cleanup finishes.
- Select optional TADOSS before a fresh deployment. Existing deployments must use
  their recorded installer revision for operations and cleanup.
- Allow Authentik server health checks 30 seconds, matching worker probes, to
  avoid premature restarts during database activity.
- Remove the environment adoption inputs, remote workload-identity provider
  option, unused contracts and checks left from the ownership-handover design.
  `TamossEnvironment` no longer accepts `spec.adoption` or `Observe,Delete`.
- Seed Kind with one Kustomize overlay. Flux installs the management chart from
  Git with settings from a generated ConfigMap, and the chart derives the
  `TamossBootstrap` root in-cluster. The host-only `setup`, `deployment-inputs`
  templates and the local release copy are removed; the three API charts install
  as one `tamoss-bootstrap-api` release.
- Give Kind a non-expiring ServiceAccount token for OKE and remove
  `bootstrap:remote-access:renew`. Teardown still revokes the token.
- Stop recording infrastructure external names in Vault. Nothing consumed the
  snapshot; bootstrap readiness no longer waits for its readback.
- Run the S3 credential Job with the pinned upstream OCI CLI and kubectl images.
  Remove the project tooling image and its publication workflow.
  `storageCredentials.image` becomes `storageCredentials.images`.


### Earlier development

These notes record earlier implementations superseded by the Kind-owned Git flow above.

- Fresh deployments consume public OCI manifest bundles and packaged Helm charts
  by digest. Removed the private asset bucket, its reader IAM and credential
  delivery, upload, publication and retirement tasks. Existing bucket deployments
  require their original tooling for cleanup; new deployments require a newly
  published bundle and pin.
- Supply the identity domain, Object Storage namespace, service network, worker
  image OCID and placements in private deployment settings. Remove installation
  discovery queries and catalogue checks; keep signing credentials out of setup
  render inputs.

- Allow teardown of an empty media bucket when OCI's version listing contains
  only prefix metadata and omits its empty data array.

- Install a pinned CI deployment bundle. Normal installation no longer assembles
  a release from the checkout.
- Seed the full Kind graph once and supply temporary OKE access. Crossplane
  records credential completion; Flux aggregates bootstrap and application health.
  Remove install-time inventories, repeated asset readback and intermediate host
  readiness checks. Git export occurs only during `handover`.
- Require a dedicated compartment without workload resources. Teardown audits
  final absence instead of comparing a pre-installation inventory. Interrupted
  host preparation requires explicit cleanup before a fresh attempt.
- Use an atomic ConfigMap claim for the bounded S3 key Job. Key creation and
  staging need three native commands; replay cannot issue a second key.

- Create the readiness report directory on a fresh deployment. Let native Flux
  own its namespace when attaching Git, and use a consistent policy patch when
  returning deletion authority to Kind.
- Fetch the existing Crossplane and function versions directly from their official
  GHCR origin, avoiding the unavailable registry proxy. Package digests are unchanged.

- Export `assets.lock.yaml` separately from client values. Optional Git selects
  the published bundle and chart digests.
- This is a new-deployment layout. Existing environments retain their original
  tooling and state for teardown; no automatic state migration is provided.

- The host establishes temporary OKE ServiceAccount access in Kind. Native Flux
  Kustomizations install and seed OKE; `up` retires their authority after successful
  deployment. Git attachment requires retirement first.
- Initial deployment and Git export share one Kustomize base. Crossplane supplies
  observed Vault information in Kind. Remove the OKE bootstrap Job and connection
  receipt. Existing environments require their recorded product revision
  for recovery and teardown.
- Crossplane creates the storage user, group and bucket policy in Kind using the
  configured Default identity domain. Setup no longer accepts `storage.userId`.
  Storage IAM remains with retained Kind after handover. Existing deployments
  must use their pinned product revision; existing users are not adopted.
- Generate the deployment's S3 credential in a bounded Kind Job, persist it through
  ESO and OCI Vault, and revoke its recorded key before deleting storage IAM.
- mise replaces Aqua and Task for pinned tools and namespaced commands. Use
  `mise run setup`, `mise run up`, `mise run handover`, `mise run qualify` and
  `mise run down`; pass environment inputs before the command.
- Quick deployment needs no environment repository, GitHub App or registry
  credentials. Product bundles are public; `mise run up` renders one local deployment
  seed and prints access details after readiness succeeds.
- Optional `mise run handover` publishes the same configuration to private Git and
  uses native Flux bootstrap with a read-only SSH deploy key persisted in Vault.
  Git adoption precedes the existing single-writer infrastructure transfer.
- Setup defaults to `media-demo`; its private settings include the compartment,
  contact email, administrator CIDRs and prepared OCI values. Git settings are
  separate and used only for handover.
- `mise run setup` prepares a single `values.yaml` and the pinned OCI CLI. Deployment
  supplies HA capacity defaults and release bundle pins and renders the supplied
  OCI settings. After handover, operational
  changes belong in environment Git.
- Budget, cost worksheets, environment expiry and UTC-midnight gates are removed
  from the product. Bootstrap Jobs retain bounded execution and retry controls.
- Published bundle references are recorded alongside their application release
  locks. Existing deployments must retain their selected product revision.
- `mise run up` now completes deployment with Kind retaining infrastructure ownership.
  Run `mise run handover` separately to transfer ownership to OKE and stop original
  Kind. Update automation that previously relied on `up` performing both steps.
- Deployment readiness now requires current, ready public certificates for
  Authentik, TAMOSS and enabled TADOSS. Certificate issuance failures prevent
  successful completion; cert-manager owns retries.

Existing environments retain their deployed product revision for operations and
teardown. These changes do not migrate existing environment layouts.
