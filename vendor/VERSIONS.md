# Vendored / Hermeto-pinned artifacts

| Artifact | Version | How it enters the image |
|----------|---------|-------------------------|
| WireMock standalone JAR | 3.12.0 | Hermeto `x-maven` via `pom.xml` + `lockfile.json` (`/cachi2/output/deps/maven`) |
| WireMock gRPC extension JAR | 0.11.0 | Hermeto `x-maven` via `pom.xml` + `lockfile.json` (`/cachi2/output/deps/maven`) |
| `grpc/kessel.dsc` | `buf.build/project-kessel/inventory-api:main` at refresh time | Committed under `vendor/grpc/` (Buf BSR is not Hermeto-prefetchable) |

Refresh pins / descriptor:

```bash
./scripts/refresh-vendor.sh
```

Konflux builds `Dockerfile` with `hermetic: true` and
`prefetch-input: [{"type":"x-maven","path":"."}]`. Local builds use
`Dockerfile`.
