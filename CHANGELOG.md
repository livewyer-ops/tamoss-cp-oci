# Changelog

## Unreleased

- `task up` now completes deployment with Kind retaining infrastructure ownership.
  Run `task handover` separately to transfer ownership to OKE and stop original
  Kind. Update automation that previously relied on `up` performing both steps.
- Deployment readiness now requires current, ready public certificates for
  Authentik, TAMOSS and enabled TADOSS. Certificate issuance failures prevent
  successful completion; cert-manager owns retries.

Existing environments retain their deployed product revision for operations and
teardown. These changes do not migrate existing environment layouts.
