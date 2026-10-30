#!/usr/bin/env bash
# Refresh vendored kessel.dsc and regenerate Hermeto x-maven lockfile.json.
# Requires network + Maven + podman/docker.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WIREMOCK_VERSION="${WIREMOCK_VERSION:-3.12.0}"
WIREMOCK_GRPC_EXTENSION_VERSION="${WIREMOCK_GRPC_EXTENSION_VERSION:-0.11.0}"
BUF_VERSION="${BUF_VERSION:-1.49.0}"
KESSEL_INVENTORY_API_REF="${KESSEL_INVENTORY_API_REF:-main}"

# Keep pom.xml / Dockerfile ENV versions in sync.
python3 - <<PY
from pathlib import Path
import re
wm = "${WIREMOCK_VERSION}"
grpc = "${WIREMOCK_GRPC_EXTENSION_VERSION}"
pom = Path("pom.xml")
text = pom.read_text()
text = re.sub(r"(<wiremock\.version>)[^<]+", r"\g<1>" + wm, text)
text = re.sub(r"(<wiremock\.grpc\.version>)[^<]+", r"\g<1>" + grpc, text)
pom.write_text(text)
for df in ("Dockerfile", "Dockerfile"):
    p = Path(df)
    t = p.read_text()
    t = re.sub(r"^ENV WIREMOCK_VERSION=.*$", f"ENV WIREMOCK_VERSION={wm}", t, flags=re.M)
    t = re.sub(
        r"^ENV WIREMOCK_GRPC_EXTENSION_VERSION=.*$",
        f"ENV WIREMOCK_GRPC_EXTENSION_VERSION={grpc}",
        t,
        flags=re.M,
    )
    p.write_text(t)
PY

echo "Generating lockfile.json via maven-lockfile..."
mvn -s settings.xml io.github.chains-project:maven-lockfile:generate \
  -DincludeMavenPlugins=false \
  -Dreduced=true \
  -DincludeEnvironment=false

mkdir -p vendor/grpc
CONTAINER_ENGINE="${CONTAINER_ENGINE:-}"
if [[ -z "${CONTAINER_ENGINE}" ]]; then
  if command -v podman >/dev/null 2>&1; then
    CONTAINER_ENGINE=podman
  else
    CONTAINER_ENGINE=docker
  fi
fi

ref="${KESSEL_INVENTORY_API_REF}"
[[ "${ref}" == "latest" ]] && ref=main

"${CONTAINER_ENGINE}" run --rm \
  -v "${ROOT}/vendor/grpc:/out:Z" \
  "docker.io/bufbuild/buf:${BUF_VERSION}" \
  build "buf.build/project-kessel/inventory-api:${ref}" \
  -o /out/kessel.dsc --as-file-descriptor-set

cat > vendor/VERSIONS.md <<EOF
# Vendored / Hermeto-pinned artifacts

| Artifact | Version | How it enters the image |
|----------|---------|-------------------------|
| WireMock standalone JAR | ${WIREMOCK_VERSION} | Hermeto \`x-maven\` via \`pom.xml\` + \`lockfile.json\` (\`/cachi2/output/deps/maven\`) |
| WireMock gRPC extension JAR | ${WIREMOCK_GRPC_EXTENSION_VERSION} | Hermeto \`x-maven\` via \`pom.xml\` + \`lockfile.json\` (\`/cachi2/output/deps/maven\`) |
| \`grpc/kessel.dsc\` | \`buf.build/project-kessel/inventory-api:${KESSEL_INVENTORY_API_REF}\` at refresh time | Committed under \`vendor/grpc/\` (Buf BSR is not Hermeto-prefetchable) |

Refresh pins / descriptor:

\`\`\`bash
./scripts/refresh-vendor.sh
\`\`\`

Konflux builds \`Dockerfile\` with \`hermetic: true\` and
\`prefetch-input: [{"type":"x-maven","path":"."}]\`. Local builds use
\`Dockerfile\`.
EOF

echo "Refresh complete."
ls -lh lockfile.json vendor/grpc/kessel.dsc
