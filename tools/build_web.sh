#!/usr/bin/env bash
# Builds the web export locally and optionally serves it.
#
#   tools/build_web.sh          build only
#   tools/build_web.sh --serve  build, then serve on http://127.0.0.1:8099
#
# Needs the export templates, which are ~1.3 GB and are NOT fetched by
# tools/setup_godot.sh. Install them once from the Godot editor
# (Editor -> Manage Export Templates) or with --templates below.
set -euo pipefail

GODOT_VERSION="4.7-stable"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GODOT="${GODOT:-$REPO_ROOT/.godot-bin/Godot_v${GODOT_VERSION}_linux.x86_64}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/4.7.stable"
PORT="${PORT:-8099}"

if [[ "${1:-}" == "--templates" ]]; then
  mkdir -p "$TEMPLATE_DIR"
  echo "fetching export templates (~1.3 GB) ..."
  curl -sSL -o /tmp/templates.tpz \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  unzip -q -o /tmp/templates.tpz -d /tmp
  mv /tmp/templates/* "$TEMPLATE_DIR/"
  rm -f /tmp/templates.tpz
  echo "templates installed to $TEMPLATE_DIR"
  shift || true
fi

if [[ ! -x "$GODOT" ]]; then
  echo "godot not found at $GODOT — run tools/setup_godot.sh first" >&2
  exit 127
fi

if [[ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]]; then
  echo "export templates missing from $TEMPLATE_DIR" >&2
  echo "run: tools/build_web.sh --templates" >&2
  exit 127
fi

mkdir -p build/web
"$GODOT" --headless --export-release "Web" build/web/index.html
echo
ls -lh build/web

if [[ "${1:-}" == "--serve" ]]; then
  echo
  echo "serving http://127.0.0.1:${PORT}/  (ctrl-c to stop)"
  # Python's http.server does not know .wasm, and a wrong Content-Type breaks
  # WebAssembly streaming instantiation.
  python3 - "$PORT" <<'PY'
import http.server, socketserver, mimetypes, sys, os
mimetypes.add_type("application/wasm", ".wasm")
port = int(sys.argv[1])
root = os.path.join(os.getcwd(), "build", "web")
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=root, **k)
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", port), H) as httpd:
    httpd.serve_forever()
PY
fi
