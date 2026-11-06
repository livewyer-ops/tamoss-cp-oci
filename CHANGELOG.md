# Changelog

## Unreleased

- Quick deployment needs no environment repository, GitHub App or registry
  credentials. Product bundles are public; `task up` renders one local deployment
  seed and prints access details after readiness succeeds.
- Optional `task handover` publishes the same configuration to private Git and
  uses native Flux bootstrap with a read-only SSH deploy key persisted in Vault.
  Git adoption precedes the existing single-writer infrastructure transfer.
- Setup defaults to `media-demo` with three required values: compartment, contact
  email and administrator CIDRs. Git settings are separate and used only for handover.
- `task setup` prepares a single `values.yaml` and the pinned OCI CLI. Deployment
  supplies HA defaults and release bundle pins, discovers regional OCI values,
  and records bootstrap settings for repeat runs. After handover, operational
  changes belong in environment Git.
- Budget, cost worksheets, environment expiry and UTC-midnight gates are removed
  from the product. Bootstrap Jobs retain bounded execution and retry controls.
- Published bundle references are recorded alongside their application release
  locks. Existing deployments must retain their selected product revision.
- `task up` now completes deployment with Kind retaining infrastructure ownership.
  Run `task handover` separately to transfer ownership to OKE and stop original
  Kind. Update automation that previously relied on `up` performing both steps.
- Deployment readiness now requires current, ready public certificates for
  Authentik, TAMOSS and enabled TADOSS. Certificate issuance failures prevent
  successful completion; cert-manager owns retries.

Existing environments retain their deployed product revision for operations and
teardown. These changes do not migrate existing environment layouts.
