# TAMOSS on OKE

The `tamoss` instance in the `tams` namespace uses the upstream `multi-server` profile. The operator selects images and migrations from its release catalogue. The local [instance overlay](instance/) configures worker separation, the private S3-compatible bucket and external PostgreSQL. The database bootstrap creates roles and databases. TAMOSS owns its schema migrations.

Database clients verify the server hostname using the CA in `spec.backends.db.external.tls.caConfigMap`. `spec.publicEndpoint.tlsSecretName` selects the shared API and UI certificate. To inspect the running store, see [Operations](../../docs/operations.md#inspect-the-installation).

## Release selection

For a new installation, update [release.yaml](release.yaml) from the published TAMOSS release record and matching source archive. Check compatibility and migration requirements, update matching upstream files and [pins](../../pins.yaml), then run the [local checks](../../docs/testing.md#local-checks). These compare the checked-in upstream charts, defaults and instance base against the selected release.

Flux pulls the operator OCI artefact by digest and packages integration charts from the recorded product commit. Existing deployments retain that commit and their `tamoss-release.yaml` through qualification and teardown. In-place release upgrades are unqualified.
