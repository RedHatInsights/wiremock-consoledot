FROM registry.access.redhat.com/ubi9/ubi:1784004673 AS build

USER 0

ENV WIREMOCK_VERSION 3.12.0
# https://repo1.maven.org/maven2/ -> Maven Central returns absent or rate limit errors.
ENV REPO_URL https://maven-central.storage-download.googleapis.com/maven2/

# grab wiremock standalone jar
RUN set -eux; \
  wiremock_url="${REPO_URL%/}/org/wiremock/wiremock-standalone/${WIREMOCK_VERSION}/wiremock-standalone-${WIREMOCK_VERSION}.jar"; \
  mkdir -p /var/wiremock/lib/; \
  curl -fSL --retry 5 --retry-all-errors --connect-timeout 20 --max-time 300 \
    "${wiremock_url}" -o /tmp/wiremock-standalone.jar; \
  test -s /tmp/wiremock-standalone.jar; \
  bytes="$(wc -c < /tmp/wiremock-standalone.jar)"; \
  test "${bytes}" -gt 1000000; \
  test "$(od -An -N2 -t x1 /tmp/wiremock-standalone.jar | tr -d ' \n')" = "504b"; \
  mv /tmp/wiremock-standalone.jar /var/wiremock/lib/wiremock-standalone.jar

# Runtime
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.24-2.1782292635
COPY --from=build /var/wiremock/lib/wiremock-standalone.jar /var/wiremock/lib/wiremock-standalone.jar

LABEL maintainer="Red Hat, Inc."

LABEL version="ubi9"
#label for EULA
LABEL com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"
WORKDIR /home/wiremock
USER 0

# Init WireMock files structure
RUN mkdir -p /home/wiremock/mappings && \
	mkdir -p /home/wiremock/__files && \
	mkdir -p /var/wiremock/extensions

COPY docker-entrypoint.sh /

EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]