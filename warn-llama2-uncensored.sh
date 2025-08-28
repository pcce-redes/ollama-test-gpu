#!/bin/bash
set -euo pipefail

ollama pull llama2-uncensored:7b
ollama run llama2-uncensored:7b