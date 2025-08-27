#!/usr/bin/env bash
# uninstall-ollama.sh
# Remove Ollama (service + binário) e, opcionalmente, dados/modelos.
# Flags:
#   --yes           : não perguntar (assume 'sim' para remoção de dados)
#   --keep-data     : não remove dados/modelos
#   --all-users     : remove ~/.ollama de todos os usuários (além do atual)
# Uso:
#   chmod +x uninstall-ollama.sh
#   ./uninstall-ollama.sh --yes --all-users

set -euo pipefail

ASK=1
KEEP_DATA=0
ALL_USERS=0

for arg in "$@"; do
  case "$arg" in
    --yes) ASK=0 ;;
    --keep-data) KEEP_DATA=1 ;;
    --all-users) ALL_USERS=1 ;;
    *) echo "Flag desconhecida: $arg"; exit 2 ;;
  esac
done

SUDO=""
if [ "$EUID" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Este script precisa de root (direto ou via sudo)."
    exit 1
  fi
fi

info(){ echo -e "\033[1;34m[*]\033[0m $*"; }
ok(){ echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[!]\033[0m $*"; }

# 1) Parar/desabilitar serviço systemd, se existir
if [ -f /etc/systemd/system/ollama.service ] || systemctl list-unit-files | grep -q '^ollama\.service'; then
  info "Parando serviço ollama…"
  $SUDO systemctl disable --now ollama || true
  # Remove unit e overrides
  $SUDO rm -f /etc/systemd/system/ollama.service || true
  $SUDO rm -rf /etc/systemd/system/ollama.service.d || true
  $SUDO systemctl daemon-reload || true
  ok "Serviço removido."
else
  warn "Serviço systemd do Ollama não encontrado (ok)."
fi

# 2) Matar qualquer processo remanescente
if pgrep -f "ollama serve" >/dev/null 2>&1; then
  info "Encerrando processos ollama remanescentes…"
  $SUDO pkill -f "ollama serve" || true
fi
if pgrep -x ollama >/dev/null 2>&1; then
  $SUDO pkill -x ollama || true
fi

# 3) Remover binário(s)
REMOVED=0
for p in /usr/local/bin/ollama /usr/bin/ollama; do
  if [ -x "$p" ]; then
    info "Removendo binário: $p"
    $SUDO rm -f "$p" && REMOVED=1
  fi
done
[ $REMOVED -eq 1 ] && ok "Binário removido." || warn "Binário não encontrado (ok)."

# 4) Remover dados/modelos (opcional)
SYS_DIRS=(/usr/share/ollama /var/lib/ollama /var/cache/ollama)
USER_DIRS=("$HOME/.ollama")

if [ "$ALL_USERS" -eq 1 ]; then
  for d in /home/*/.ollama /root/.ollama; do
    [ -d "$d" ] && USER_DIRS+=("$d")
  done
fi

TO_REMOVE=()
for d in "${SYS_DIRS[@]}" "${USER_DIRS[@]}"; do
  [ -d "$d" ] && TO_REMOVE+=("$d")
done

if [ "$KEEP_DATA" -eq 1 ]; then
  warn "Mantendo dados/modelos por --keep-data."
else
  if [ "${#TO_REMOVE[@]}" -gt 0 ]; then
    echo "Diretórios de dados/modelos detectados:"
    for d in "${TO_REMOVE[@]}"; do echo "  - $d"; done
    DO_REMOVE=0
    if [ "$ASK" -eq 0 ]; then
      DO_REMOVE=1
    else
      read -r -p "Remover TODOS os dados/modelos acima? [y/N] " ans
      [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] && DO_REMOVE=1
    fi
    if [ "$DO_REMOVE" -eq 1 ]; then
      for d in "${TO_REMOVE[@]}"; do
        info "Removendo $d"
        $SUDO rm -rf "$d" || true
      done
      ok "Dados/modelos removidos."
    else
      warn "Dados/modelos preservados por escolha do usuário."
    fi
  else
    warn "Nenhum diretório de dados/modelos encontrado."
  fi
fi

# 5) Limpeza final: porta 11434 livre?
if command -v ss >/dev/null 2>&1 && ss -ltn | grep -q ':11434'; then
  warn "A porta 11434 ainda está em uso. Verifique processos restantes."
else
  ok "Porta 11434 livre."
fi

ok "Desinstalação do Ollama concluída."
