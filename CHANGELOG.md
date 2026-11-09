# Changelog

## Unreleased

- Allow teardown of an empty media bucket when OCI's version listing contains
  only prefix metadata and omits its empty data array.

- Install a pinned CI deployment bundle and copy it to the customer's private
  asset store. Normal installation no longer assembles a release from the checkout.
- Seed the full Kind graph once and supply temporary OKE access. Crossplane
  records credential completion; Flux aggregates bootstrap and application health.
  Remove install-time inventories, repeated asset readback and intermediate host
  readiness checks. Git export occurs only during `handover`.
- Require a dedicated compartment without workload resources. Teardown audits
  final absence instead of comparing a pre-installation inventory. Interrupted
  host preparation requires explicit cleanup before a fresh attempt.
- Use an atomic ConfigMap claim for the bounded S3 key Job. Key creation and
  staging need three native commands; replay cannot issue a second key.

- Retire asset-reader membership through the native Identity Domains group API,
  using the recorded user and group under the existing scoped permissions.
- Create the readiness report directory on a fresh deployment. Let native Flux
  own its namespace when attaching Git, and use a consistent policy patch when
  returning deletion authority to Kind.
- Resume asset-reader retirement when OCI returns an empty body for a successful
  key or membership list. Ownership checks still reject unrelated keys and groups.
- Fetch the existing Crossplane and function versions directly from their official
  GHCR origin, avoiding the unavailable registry proxy. Package digests are unchanged.

- Prepare restricted asset-reader IAM with the host OCI CLI, persist its key
  through Vault and deliver it to OKE before applying the remote seed.
- Export `assets.lock.yaml` separately from client values. Optional Git selects
  a published snapshot; `assets:publish` does not activate candidates.
- Retain the asset store on `down`; revoke its reader and support pre-provider
  failure cleanup. `assets:retire` explicitly removes a retired store.
- This is a new-deployment layout. Existing environments retain their original
  tooling and state for teardown; no automatic state migration is provided.

- The host establishes temporary OKE ServiceAccount access in Kind. Native Flux
  Kustomizations install and seed OKE; `up` retires their authority after successful
  deployment. Repeats renew active bootstrap credentials or finish interrupted
  retirement; Git attachment requires retirement first.
- Initial deployment and Git export share one Kustomize base. Crossplane supplies
  observed Vault information in Kind. Remove the OKE bootstrap Job and connection
  receipt. Existing environments require their recorded product revision
  for recovery and teardown.
- Crossplane creates the storage user, group and bucket policy in Kind. Setup
  discovers the Default identity domain and no longer accepts `storage.userId`.
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
- Setup defaults to `media-demo` with compartment, contact email, administrator
  CIDRs. Git settings are separate and used only for handover.
- `mise run setup` prepares a single `values.yaml` and the pinned OCI CLI. Deployment
  supplies HA defaults and release bundle pins, discovers regional OCI values,
  and records bootstrap settings for repeat runs. After handover, operational
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
