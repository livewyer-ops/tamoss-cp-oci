# Changelog

To publish from the current tip of `main`, run `git fetch origin main`, then
`git tag -a 8.2-oci1 origin/main -m 8.2-oci1` and `git push origin refs/tags/8.2-oci1`.
Use the release version in both commands and in the heading below. GitHub
publishes its notes after the tagged commit passes the checks.

## 8.2-oci1

- Deploy the TAMOSS multi-server profile on OKE with OCI PostgreSQL and Object Storage. Optionally enable TADOSS for timed metadata.
- Fetch the public product repository over anonymous HTTPS by default. Private copies can opt in to SSH deploy keys.
- Apply settings directly to OKE or hand them over to a private GitHub repository.
- Retire workloads and infrastructure with `mise run down`. The original Kind cluster and environment directory are required.
