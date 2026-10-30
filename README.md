# Wiremock

This repo is used for deploying wiremock to EE for IQE testing via Clowder.

Customized to run on port 8000.

https://wiremock.org/

## Build

```bash
./scripts/build-local.sh
```

The Kessel inventory descriptor is committed at `vendor/grpc/kessel.dsc` because
the Buf Schema Registry is not a Hermeto-prefetchable source.

WireMock fat JARs lack `META-INF/maven/**/pom.properties`. Without injecting that
metadata, Syft invents `pkg:maven/<filename>/...` PURLs that do not merge with
Hermeto's `pkg:maven/org.wiremock/...`. The Dockerfile injects GAV
`pom.properties` after the JARs are present.

Regenerate the Maven lockfile and Kessel descriptor:

```bash
./scripts/refresh-vendor.sh
```

See `vendor/VERSIONS.md`.
