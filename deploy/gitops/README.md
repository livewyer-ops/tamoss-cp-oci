# Deployment from Git

Flux and Crossplane run in Kind for the lifetime of the demo. Flux reads this
repository at the committed revision selected by `up`, packages its chart
directories and deploys the application to OKE. Keep Kind running until teardown
has completed. OKE runs External Secrets and the application controllers.

## Process and execution context

| Step | Runs on | Action and result |
| --- | --- | --- |
| Prepare | Host | Read private settings and OCI profile; require a clean checkout whose commit is available from `origin`; validate the settings against the management chart. |
| Start management | Host -> Kind | Create Kind and install official Flux controllers. Apply one Kustomize overlay: Git source, settings ConfigMap, OCI Secrets and the `tamoss-management` HelmRelease. |
| Authenticate private Git | Host -> Kind | Register a dedicated read-only repository deploy key and create its Secret in Kind, with GitHub's published SSH host keys. |
| Install controllers | Flux in Kind | Fetch the pinned Git commit; install the management chart with the settings; install official Crossplane and External Secrets charts, OCI provider packages and the local composition charts. |
| Create infrastructure | Crossplane in Kind -> OCI | Create or adopt the recorded Vault/key; provision credentials, IAM, networking, OKE/workers, PostgreSQL and storage. |
| Establish OKE access | Host -> Kind | Use OCI's exec kubeconfig to verify the OKE identity and request a bounded ServiceAccount token; submit a self-contained kubeconfig Secret to Kind. |
| Discover database connection | Job in Kind -> OCI | Fetch the database hostname and CA using the existing OCI bootstrap Secret; publish validated connection data in Kind. |
| Install the platform | Flux in Kind -> OKE | Install External Secrets, ingress, certificates, Authentik and database initialisation. Chart values and substitutions are read in Kind; SQL Jobs run in OKE. |
| Install the application | Flux in Kind -> OKE | Apply the upstream TAMOSS operator and the checked-in instance overlay; include TADOSS when enabled before deployment. |
| Observe | Kind; host reads results | Check current source/chart revisions and remote workload health. Print application URLs and the location of private login details. |
| Remove workloads | Kind -> OKE | Suspend deployment reconciliation, run application finalisers and uninstall remote releases while their operators remain available. |
| Remove infrastructure | Kind -> OCI | Empty owned storage, delete infrastructure and backups, retire credentials and schedule Vault secret deletion. Host reads OCI inventory to verify cleanup. |
| Remove management | Host | Revoke the per-deployment Git key and delete Kind after the cleanup audit passes; retain local records and the Vault/key ownership record. |

The host exception is OKE access: the pinned Crossplane OCI provider does not
supply the kubeconfig needed here. Stock Flux needs a self-contained kubeconfig
and cannot run the OCI exec authentication plugin. The host creates a
ServiceAccount token Secret on OKE and copies its token into the Kind Secret. The
token does not expire: Kind already holds the OCI signing key, so an expiry would
add renewal work without limiting Kind's authority. Teardown revokes the token by
deleting its namespace after workload cleanup.

## Sources and charts

| Asset | Source |
| --- | --- |
| Flux | Official pinned CLI/controller release |
| Crossplane | Official `charts.crossplane.io/stable` Helm repository |
| External Secrets | Official `charts.external-secrets.io` Helm repository |
| OCI providers and Crossplane functions | Published packages pinned in `pins.yaml` |
| Management, compositions and operation charts | Directories in this repository, packaged by Flux from Git |
| TAMOSS platform helper charts, defaults and instance manifests | Unchanged files from the pinned TAMOSS release, checked in under `upstream/` directories and verified by `mise run check` |
| TAMOSS and TADOSS operators | Their upstream OCI release artifacts, selected by digest |
| Calico | Unchanged upstream manifest at the recorded revision |

These charts have separate lifecycles: controller installation, Crossplane APIs,
credential delivery and application releases. They do not require a separate
registry publication step. `pins.yaml` records dependency versions and upstream
digests; `source.json` records the selected product Git commit and source.

## Private repository authentication

Before deploying a private repository, authenticate GitHub CLI on the host with
an account allowed to manage that repository's deploy keys:

```bash
mise exec -- gh auth login --hostname github.com --git-protocol https
```

Leave `source.private: true` in the private deployment settings. `up` creates a
new read-only SSH deploy key for that deployment. Its private key exists in Kind;
temporary host exports are removed. The host's GitHub token is never copied into
Kind or OKE. Teardown revokes the recorded key after controllers have finished.
The repository must already contain the selected commit; `up` does not commit,
push or create another repository.

For future deployments after the repository becomes public, set
`source.private: false`. The source uses public HTTPS without a Secret reference
and skips deploy-key creation. For an existing running demo, change the Kind
GitRepository to HTTPS and remove `spec.secretRef`, verify a successful anonymous
fetch at the same commit, then run `ENV_DIR=.local/environment mise run source:revoke`
and delete `tamoss-infra/deployment-git`. Use the original environment directory;
the task revokes the key and removes its local ID so teardown will not revoke it
again. Retain the key until that anonymous fetch succeeds.

## Demo inputs and source changes

`mise run setup` creates the private `values.yaml`. Configure OCI settings and
optional `tadoss.enabled` there before `up`. Helm validates the inputs; generated
configuration and credentials stay outside Git. The source checkout shows every
controller declaration, chart and overlay that Flux will use.

Source edits must be committed and pushed before a fresh deployment. This flow
has no ownership handover or second environment repository. Retain the deployed
product revision for qualification and teardown. Fresh OCI deployment,
qualification and cleanup have passed with this flow; see the
[verified coverage and limits](../../docs/testing.md#verified-coverage-and-limits).
