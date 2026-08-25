FROM registry.access.redhat.com/ubi9/ubi:1786631974 AS build

USER 0

# Stable WireMock 3.x + gRPC extension
ENV WIREMOCK_VERSION=3.12.0
ENV WIREMOCK_GRPC_EXTENSION_VERSION=0.11.0
# https://repo1.maven.org/maven2/ -> Maven Central returns absent or rate limit errors.
ENV REPO_URL=https://maven-central.storage-download.googleapis.com/maven2/
ENV BUF_VERSION=1.49.0

# Kessel inventory protos from Buf Schema Registry.
# Labels: buf registry module label list buf.build/project-kessel/inventory-api
ARG KESSEL_INVENTORY_API_REF=main

RUN set -eux; \
  mkdir -p /var/wiremock/{lib,extensions,grpc}; \
  curl_get() { curl -fSL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 300 -o "$1" "$2"; }; \
  curl_get /var/wiremock/lib/wiremock-standalone.jar \
    "${REPO_URL%/}/org/wiremock/wiremock-standalone/${WIREMOCK_VERSION}/wiremock-standalone-${WIREMOCK_VERSION}.jar"; \
  curl_get /var/wiremock/extensions/wiremock-grpc-extension-standalone.jar \
    "${REPO_URL%/}/org/wiremock/wiremock-grpc-extension-standalone/${WIREMOCK_GRPC_EXTENSION_VERSION}/wiremock-grpc-extension-standalone-${WIREMOCK_GRPC_EXTENSION_VERSION}.jar"; \
  case "$(uname -m)" in x86_64) a=x86_64;; aarch64) a=aarch64;; *) exit 1;; esac; \
  curl_get /usr/local/bin/buf "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-Linux-${a}"; \
  chmod +x /usr/local/bin/buf; \
  ref=${KESSEL_INVENTORY_API_REF}; [ "${ref}" = latest ] && ref=main; \
  buf build "buf.build/project-kessel/inventory-api:${ref}" \
    -o /var/wiremock/grpc/kessel.dsc --as-file-descriptor-set

# Runtime
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.24-3.1787219885

LABEL maintainer="Red Hat, Inc."

LABEL version="ubi9"
#label for EULA
LABEL com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"
WORKDIR /home/wiremock
USER 0

RUN mkdir -p /home/wiremock/mappings /home/wiremock/__files /home/wiremock/grpc /var/wiremock/extensions

COPY --from=build /var/wiremock/lib/wiremock-standalone.jar /var/wiremock/lib/wiremock-standalone.jar
COPY --from=build /var/wiremock/extensions/wiremock-grpc-extension-standalone.jar /var/wiremock/extensions/wiremock-grpc-extension-standalone.jar
COPY --from=build /var/wiremock/grpc/kessel.dsc /home/wiremock/grpc/kessel.dsc
COPY docker-entrypoint.sh /

EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]