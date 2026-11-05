ARG OCI_IMAGE
ARG FLUX_IMAGE
ARG KUBECTL_IMAGE
ARG YQ_IMAGE
FROM ${FLUX_IMAGE} AS flux
FROM ${KUBECTL_IMAGE} AS kubectl
FROM ${YQ_IMAGE} AS yq
FROM ${OCI_IMAGE}
COPY --from=flux /usr/local/bin/flux /usr/local/bin/flux
COPY --from=kubectl /bin/kubectl /usr/local/bin/kubectl
COPY --from=yq /usr/bin/yq /usr/local/bin/yq
ENV PYTHONDONTWRITEBYTECODE=1
USER 1000:1000
ENTRYPOINT ["oci"]
