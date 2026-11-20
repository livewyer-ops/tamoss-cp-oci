# Deployment from Git

The product repository supplies the charts, manifests and [dependency pins](../../pins.yaml). Flux in Kind and OKE reads the pushed commit recorded in `source.json`. Keep that checkout for the lifetime of the deployment.

| Source | Consumer | Contents |
| --- | --- | --- |
| Product Git commit | Flux in Kind | Management release, bootstrap composition and root release for OKE |
| Same product commit and pinned upstream OCI artefacts | Flux in OKE | Platform, TAMOSS and optional TADOSS operators and configuration |
| Optional private environment repository, branch `main` | Flux in OKE | The two live settings ConfigMaps, adopted at [handover](../../docs/operations.md#keep-settings-in-an-environment-repository) |

## Repository access

Kind and OKE fetch the public product repository over anonymous HTTPS. For a private copy, set `source.private: true` before `up` to register a read-only deploy key. `handover` registers its own key for the private environment repository. The GitHub CLI token stays on the workstation. `down` revokes the keys registered for the deployment.

## Inspect the applied revision

Enter `mise exec -- bash`, then run against OKE:

```bash
kubectl --kubeconfig "${ENV_DIR:-.local/environment}/remote.kubeconfig" -n tamoss-infra get gitrepositories,kustomizations,helmreleases
```

Check the `tamoss-bootstrap-product` source against the commit in `source.json`. After handover, compare `tamoss-environment` with the commit on the environment repository's `main` branch. [Operations](../../docs/operations.md#keep-settings-in-an-environment-repository) shows how to read the applied revision.
