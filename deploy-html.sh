#!/usr/bin/env bash
# deploy-html.sh — servir SPA rapidamente (NGINX em Docker; fallback python)
# Uso:
#   ./deploy-html.sh start  --dir ./pasta-do-html --port 8000 --name spa-html [--copy-main] [--src main.html] [--autoindex]
#   ./deploy-html.sh stop   [--name spa-html]
#   ./deploy-html.sh status [--name spa-html]
# Notas:
#   - Se --copy-main for omitido: copia main.html -> index.html APENAS se index não existir.
#   - Por padrão procura main.html ao lado deste script; pode trocar com --src.

set -euo pipefail

CMD="${1:-start}"
DIR="./"
PORT="8000"
NAME="spa-html"
AUTOINDEX=0
COPY_MAIN=0
SRC_FILE="main.html"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)       DIR="${2:-}"; shift 2 ;;
    --port)      PORT="${2:-}"; shift 2 ;;
    --name)      NAME="${2:-}"; shift 2 ;;
    --autoindex) AUTOINDEX=1; shift 1 ;;
    --copy-main) COPY_MAIN=1; shift 1 ;;
    --src)       SRC_FILE="${2:-}"; shift 2 ;;
    *) echo "Arg desconhecido: $1"; exit 2 ;;
  esac
done

# paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# se SRC_FILE não for absoluto, resolva relativo ao SCRIPT_DIR
[[ "$SRC_FILE" = /* ]] || SRC_FILE="${SCRIPT_DIR}/${SRC_FILE}"

absdir() {
  if command -v realpath >/dev/null 2>&1; then realpath "$1"; else
    python3 - "$1" <<'PY'
import os, sys; print(os.path.abspath(sys.argv[1]))
PY
  fi
}
DIR="$(absdir "$DIR")"

have() { command -v "$1" >/dev/null 2>&1; }
require() { have "$1" || { echo "Faltando: $1"; exit 1; }; }
need_read_access() { [ -d "$1" ] && [ -r "$1" ] && [ -x "$1" ]; }
need_write_access() { [ -w "$1" ]; }

# 1) Preparar pasta alvo e copiar main.html -> index.html se aplicável
mkdir -p "$DIR"
need_write_access "$DIR" || { echo "Sem permissão de escrita em: $DIR"; exit 1; }

if [ -f "$SRC_FILE" ]; then
  if [ $COPY_MAIN -eq 1 ] || [ ! -f "$DIR/index.html" ]; then
    cp -f "$SRC_FILE" "$DIR/index.html"
    echo "Copiado: $(basename "$SRC_FILE") → $DIR/index.html"
  fi
else
  # Se não há SRC, mas também não há index, avisa
  if [ ! -f "$DIR/index.html" ]; then
    echo "Nem '$SRC_FILE' nem '$DIR/index.html' existem. Crie um deles."
    exit 1
  fi
fi

# 2) Servidores
docker_start() {
  require docker
  need_read_access "$DIR" || { echo "Sem permissão de leitura em: $DIR"; exit 1; }
  [ -f "$DIR/index.html" ] || { echo "index.html não encontrado em: $DIR"; exit 1; }

  # gera conf Nginx no diretório atual
  CONF="$(pwd)/.nginx-${NAME}-${PORT}.conf"
  {
    echo "server {"
    echo "  listen 80 default_server;"
    echo "  server_name _;"
    echo "  root /usr/share/nginx/html;"
    echo "  index index.html;"
    echo "  location / {"
    echo "    try_files \$uri \$uri/ /index.html;"
    [ $AUTOINDEX -eq 1 ] && echo "    autoindex on;"
    echo "  }"
    echo "  location ~* \.(html)$ { add_header Cache-Control \"no-store\"; }"
    echo "  location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?)$ { add_header Cache-Control \"public, max-age=300\"; }"
    echo "  gzip on;"
    echo "  gzip_types text/plain text/css application/json application/javascript application/xml image/svg+xml;"
    echo "  add_header X-Content-Type-Options nosniff;"
    echo "  add_header X-Frame-Options SAMEORIGIN;"
    echo "  add_header Referrer-Policy no-referrer-when-downgrade;"
    echo "}"
  } > "$CONF"

  # remove container antigo
  docker rm -f "$NAME" >/dev/null 2>&1 || true

  docker run -d --name "$NAME" --restart unless-stopped \
    -p "${PORT}:80" \
    -v "${DIR}:/usr/share/nginx/html:ro" \
    -v "${CONF}:/etc/nginx/conf.d/default.conf:ro" \
    nginx:alpine >/dev/null

  echo "OK: servido em http://127.0.0.1:${PORT}"
  echo "Se usar Ollama local, ajuste no host: OLLAMA_ORIGINS=http://127.0.0.1:${PORT},http://localhost:${PORT}"
}

docker_status() {
  if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "RUNNING: $NAME em http://127.0.0.1:${PORT}"
  else
    echo "STOPPED: $NAME"
  fi
}

docker_stop() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  echo "Parado: $NAME"
}

python_start() {
  need_read_access "$DIR" || { echo "Sem permissão de leitura em: $DIR"; exit 1; }
  [ -f "$DIR/index.html" ] || { echo "index.html não encontrado em: $DIR"; exit 1; }
  echo "Docker não encontrado. Usando python http.server…"
  echo "Servindo ${DIR} em http://127.0.0.1:${PORT}"
  echo "Pressione Ctrl+C para sair."
  cd "$DIR"
  python3 -m http.server "$PORT"
}

case "$CMD" in
  start)
    if have docker; then docker_start; else python_start; fi
    ;;
  stop)
    if have docker; then docker_stop; else echo "Nada para parar (python é foreground)."; fi
    ;;
  status)
    if have docker; then docker_status; else echo "Sem Docker; status não se aplica."; fi
    ;;
  *)
    echo "Uso: $0 {start|stop|status} [--dir DIR] [--port PORT] [--name NAME] [--copy-main] [--src ARQUIVO] [--autoindex]"
    exit 1
    ;;
esac
