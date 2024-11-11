FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:1.20-2.1725851029
USER root
RUN microdnf \
    --disablerepo=* \
    --enablerepo=ubi-9-baseos-rpms \
    install -y tar rsync
RUN microdnf \
  --disablerepo=* \
  --enablerepo=ubi-9-appstream-rpms \
  --enablerepo=ubi-9-baseos-rpms \
  update -y

ARG WIREMOCK_VERSION=3.9.2
ENV WIREMOCK_VERSION=$WIREMOCK_VERSION

# grab wiremock standalone jar
RUN mkdir -p /var/wiremock/lib/ \
  && curl https://repo1.maven.org/maven2/org/wiremock/wiremock-standalone/$WIREMOCK_VERSION/wiremock-standalone-$WIREMOCK_VERSION.jar \
    -o /var/wiremock/lib/wiremock-standalone.jar

# Init WireMock files structure
RUN mkdir -p /home/wiremock/mappings && \
	mkdir -p /home/wiremock/__files && \
	mkdir -p /var/wiremock/extensions

# COPY docker-entrypoint.sh /

EXPOSE 8080 8443

HEALTHCHECK --start-period=5s --start-interval=100ms CMD curl -f http://localhost:8080/__admin/health || exit 1

# ENTRYPOINT ["/docker-entrypoint.sh"]
