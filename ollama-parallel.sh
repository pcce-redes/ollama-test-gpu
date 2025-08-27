#!/usr/bin/env bash

set -euo pipefail

MODEL="deepseek-r1:1.5b"
HOST="0.0.0.0"
NUM_INSTANCES="2"
BASE_PORT="11434"
KEEP_ALIVE="2h"
LOG_DIR="./logs"
PID_DIR="./pids"

mkdir -p "$LOG_DIR" "$PID_DIR"

require() { command -v "$1" >/dev/null || { echo "Faltando: $1"; exit 1; }; }

die() { echo "Erro: $*"; exit 1; }

gpu_count() { nvidia-smi -L | wc -l | awk '{print $1}'; }

is_port_free() { ! ss -ltn "( sport = :$1 )" | grep -q LISTEN; }

wait_http() {
  local url="$1" tries=60
  until curl -fsS "$url" >/dev/null 2>&1; do
    tries=$((tries-1))
    [ "$tries" -le 0 ] && return 1
    sleep 1
  done
}

start_instance() {
  local idx="$1"
  local port=$((BASE_PORT + idx))
  local pidfile="$PID_DIR/ollama-gpu${idx}.pid"
  local logfile="$LOG_DIR/ollama-gpu${idx}.log"

  is_port_free "$port" || die "Porta $port em uso"

  CUDA_VISIBLE_DEVICES="$idx" \
  OLLAMA_HOST="${HOST}:${port}" \
  OLLAMA_KEEP_ALIVE="$KEEP_ALIVE" \
    nohup ollama serve >"$logfile" 2>&1 &

  echo $! > "$pidfile"
  echo "GPU ${idx} → porta ${port} (PID $(cat "$pidfile"))"
}

stop_instance() {
  local idx="$1"
  local pidfile="$PID_DIR/ollama-gpu${idx}.pid"
  [ -f "$pidfile" ] || return 0
  local pid; pid=$(cat "$pidfile" || true)
  if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" || true
    sleep 1
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pidfile"
}

status_instance() {
  local idx="$1"
  local port=$((BASE_PORT + idx))
  local pidfile="$PID_DIR/ollama-gpu${idx}.pid"
  local up="down"
  curl -fsS "http://$HOST:$port/api/tags" >/dev/null 2>&1 && up="up"
  printf "GPU %d | port %d | %s" "$idx" "$port" "$up"
  [ -f "$pidfile" ] && printf " | PID %s" "$(cat "$pidfile")"
  echo
}

pull_model_once() {
  local url="http://${HOST}:${BASE_PORT}/api/pull"
  echo "Pull do modelo '${MODEL}' em ${url} ..."
  curl -fsS -N -X POST "$url" -d "{\"name\":\"${MODEL}\"}" || true
}

test_instance() {
  local port="$1"
  curl -fsS -X POST "http://$HOST:$port/api/generate" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"${MODEL}\",
      \"prompt\": \"Responda 'ok' em uma palavra.\",
      \"stream\": false
    }" | sed 's/.*\"response\":\"\([^\"]*\)\".*/\1/' || echo "falhou"
}

start_all() {
  require nvidia-smi
  require ollama
  require curl
  require ss

  if command -v systemctl >/dev/null && systemctl is-active --quiet ollama; then
    echo "Parando systemd service 'ollama' (temporário)..."
    sudo systemctl stop ollama || true
  fi

  local gcount; gcount=$(gpu_count)
  [ "$NUM_INSTANCES" -le "$gcount" ] || die "GPUs disponíveis: $gcount; requisitado: $NUM_INSTANCES"

  for i in $(seq 0 $((NUM_INSTANCES-1))); do
    start_instance "$i"
  done

  wait_http "http://${HOST}:${BASE_PORT}/api/tags" || die "Instância 0 não respondeu"
  pull_model_once

  for i in $(seq 0 $((NUM_INSTANCES-1))); do
    local port=$((BASE_PORT + i))
    wait_http "http://${HOST}:${port}/api/tags" || die "Instância $i não respondeu"
  done

  echo "Todas as instâncias ativas."
}

stop_all() {
  for i in $(seq 0 $((NUM_INSTANCES-1))); do
    stop_instance "$i"
  done
  echo "Todas encerradas."
}

status_all() {
  local gcount; gcount=$(gpu_count || echo 0)
  local n=$(( NUM_INSTANCES > gcount && gcount > 0 ? gcount : NUM_INSTANCES ))
  for i in $(seq 0 $((n-1))); do
    status_instance "$i"
  done
}

test_all() {
  echo "Testando /api/generate em cada instância com modelo: ${MODEL}"
  for i in $(seq 0 $((NUM_INSTANCES-1))); do
    local port=$((BASE_PORT + i))
    echo -n "GPU $i (porta $port): "
    test_instance "$port"
  done
}

cmd="${1:-}"
case "$cmd" in
  start)  start_all ;;
  stop)   stop_all ;;
  status) status_all ;;
  test)   test_all ;;
  *)
    echo "Uso: $0 {start|stop|status|test}"
    echo "Ex.: MODEL='deepseek-r1:32b-q4_K_M' NUM_INSTANCES=4 BASE_PORT=11434 $0 start"
    exit 1
    ;;
esac
