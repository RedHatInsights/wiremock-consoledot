FROM registry.access.redhat.com/ubi9/ubi:9.7-1773204657 AS build

USER 0

ENV WIREMOCK_VERSION 3.12.0

# grab wiremock standalone jar
RUN mkdir -p /var/wiremock/lib/ \
  && curl https://repo1.maven.org/maven2/org/wiremock/wiremock-standalone/$WIREMOCK_VERSION/wiremock-standalone-$WIREMOCK_VERSION.jar \
    -o /var/wiremock/lib/wiremock-standalone.jar

# Runtime
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.24-2.1771324987
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