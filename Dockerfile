# Single Dockerfile for Konflux hermetic and local networked builds.
# Hermeto x-maven prefetches JARs under /cachi2/output (pom.xml + lockfile.json).
# Local: curl the same artifacts from Maven Central mirror when /cachi2 is absent.
# kessel.dsc is vendored (Buf Schema Registry is not Hermeto-prefetchable).
FROM registry.access.redhat.com/ubi9/ubi:1793179250 AS prepare

USER 0

ENV WIREMOCK_VERSION=3.12.0
ENV WIREMOCK_GRPC_EXTENSION_VERSION=0.11.0
# https://repo1.maven.org/maven2/ -> Maven Central returns absent or rate limit errors.
ENV REPO_URL=https://maven-central.storage-download.googleapis.com/maven2/

RUN set -eux; \
  mkdir -p /var/wiremock/lib /var/wiremock/extensions; \
  WM_JAR="wiremock-standalone-${WIREMOCK_VERSION}.jar"; \
  GRPC_JAR="wiremock-grpc-extension-standalone-${WIREMOCK_GRPC_EXTENSION_VERSION}.jar"; \
  if [ -d /cachi2/output/deps/maven ]; then \
    cp "/cachi2/output/deps/maven/org/wiremock/wiremock-standalone/${WIREMOCK_VERSION}/${WM_JAR}" \
      /var/wiremock/lib/wiremock-standalone.jar; \
    cp "/cachi2/output/deps/maven/org/wiremock/wiremock-grpc-extension-standalone/${WIREMOCK_GRPC_EXTENSION_VERSION}/${GRPC_JAR}" \
      /var/wiremock/extensions/wiremock-grpc-extension-standalone.jar; \
  else \
    curl_get() { curl -fSL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 300 -o "$1" "$2"; }; \
    curl_get /var/wiremock/lib/wiremock-standalone.jar \
      "${REPO_URL%/}/org/wiremock/wiremock-standalone/${WIREMOCK_VERSION}/${WM_JAR}"; \
    curl_get /var/wiremock/extensions/wiremock-grpc-extension-standalone.jar \
      "${REPO_URL%/}/org/wiremock/wiremock-grpc-extension-standalone/${WIREMOCK_GRPC_EXTENSION_VERSION}/${GRPC_JAR}"; \
  fi

# Fat JARs ship without META-INF/maven pom.properties, so Syft invents
# pkg:maven/<filename>/... PURLs that do not merge with Hermeto's
# pkg:maven/org.wiremock/... Inject GAV metadata so Syft matches Hermeto.
RUN python3 - <<'PY'
import os, zipfile
from pathlib import Path

def inject(jar: Path, group: str, artifact: str, version: str) -> None:
    entry = f"META-INF/maven/{group}/{artifact}/pom.properties"
    body = f"groupId={group}\nartifactId={artifact}\nversion={version}\n".encode()
    tmp = jar.with_suffix(".jar.tmp")
    with zipfile.ZipFile(jar, "r") as zin, zipfile.ZipFile(tmp, "w") as zout:
        for info in zin.infolist():
            if info.filename == entry:
                continue
            zout.writestr(info, zin.read(info.filename))
        zout.writestr(entry, body)
    tmp.replace(jar)

inject(
    Path("/var/wiremock/lib/wiremock-standalone.jar"),
    "org.wiremock",
    "wiremock-standalone",
    os.environ["WIREMOCK_VERSION"],
)
inject(
    Path("/var/wiremock/extensions/wiremock-grpc-extension-standalone.jar"),
    "org.wiremock",
    "wiremock-grpc-extension-standalone",
    os.environ["WIREMOCK_GRPC_EXTENSION_VERSION"],
)
PY

FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.24-3.1792711376

LABEL maintainer="Red Hat, Inc."
LABEL version="ubi9"
LABEL com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"

WORKDIR /home/wiremock
USER 0

RUN mkdir -p /home/wiremock/mappings /home/wiremock/__files /home/wiremock/grpc /var/wiremock/extensions

COPY --from=prepare /var/wiremock/lib/wiremock-standalone.jar /var/wiremock/lib/wiremock-standalone.jar
COPY --from=prepare /var/wiremock/extensions/wiremock-grpc-extension-standalone.jar /var/wiremock/extensions/wiremock-grpc-extension-standalone.jar
COPY vendor/grpc/kessel.dsc /home/wiremock/grpc/kessel.dsc
COPY docker-entrypoint.sh /

EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]
