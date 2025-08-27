#!/bin/bash
set -euo pipefail

echo "[1/5] Instalar dependências mínimas"
sudo apt-get update -y
sudo apt-get install -y curl jq

echo "[2/5] Instalar Ollama (oficial)"
curl -fsSL https://ollama.com/install.sh | sh

echo "[3/5] Preparar diretórios e override do systemd"
sudo install -d -o ollama -g ollama -m 0755 /var/lib/ollama /var/cache/ollama

sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<'EOF'
[Service]
Environment=HOME=/var/lib/ollama
WorkingDirectory=/var/lib/ollama
StateDirectory=ollama
CacheDirectory=ollama
EOF

echo "[4/5] (Re)carregar, habilitar e iniciar serviço"
sudo systemctl daemon-reload
sudo systemctl enable --now ollama

echo "[5/5] Verificar serviço e API"
sleep 2
systemctl is-active --quiet ollama || { echo "ERRO: serviço não está ativo"; sudo journalctl -u ollama -n 100 --no-pager; exit 1; }

if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "OK: Ollama ativo em 127.0.0.1:11434"
else
  echo "ERRO: API não respondeu. Logs recentes:"
  sudo journalctl -u ollama -n 100 --no-pager
  exit 1
fi

echo "Versão:"
ollama --version || true
echo "Modelos:"
ollama list || true
