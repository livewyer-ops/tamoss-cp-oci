# Testing

To inspect a running installation without changing it, use the [readiness checks](operations.md#inspect-the-installation). Use `qualify` when you need to test ingest, playback and availability during a worker drain.

## Local checks

Install the pinned tools and start Docker with its Compose plugin. Run the checks from the repository root with internet access.

```bash
mise run check
```

`check` validates release checksums, rendered manifests, inputs, PostgreSQL migrations and TLS. To include controller reconciliation, Git delivery and recovery of the original Kind cluster, run `mise run check:management`. It includes `check` and creates disposable Kind clusters. Its Git fixture needs host `sshd` and TCP port 22422 reachable from the Kind network. Run this suite on its own. Both commands work without an OCI account and write reports to `.local/reports/`.

## Deployed qualification

**Use a dedicated installation.** This test deletes previous qualification flows and its IngestRun, requires the store to contain no other flows, uploads a fixture and drains one worker with `--delete-emptydir-data`. That drain discards pod-local `emptyDir` data on the worker.

From the deployed Git revision, with its original credentials, run:

```bash
ENV_DIR=.local/environment mise run qualify
```

| Check | Expected result |
| --- | --- |
| Ingest and media | The IngestRun and its Job succeed. Authenticated reads and byte ranges work. Anonymous access is rejected. |
| Browser | SSO and playback pass with trusted TLS and no skipped cases. |
| Availability | The API and login path continue serving requests during the drain. The worker is uncordoned and media remains readable afterwards. |
| TADOSS, when enabled | Timed events reference the ingested TAMOSS source and survive pod replacement. |

Read `reports/` in the deployment directory for the browser, placement, network and availability results. Save reports before rerunning. A failed test leaves the deployment available for inspection. Use [teardown](operations.md#destroy-the-environment) to remove it.

## Verified coverage and limits

OCI coverage is for short-lived, three-availability-domain deployments in `uk-london-1` using an existing Vault and key. Other regions, longer operating periods and creation of a new Vault with the scoped policy are unverified. The worker-drain check covers application availability. Managed database failover, regional recovery, in-place release upgrades, database resizing, credential rotation and teardown after failed database creation are unverified.
