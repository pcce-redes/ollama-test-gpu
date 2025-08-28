#!/bin/bash

docker run -d --name open-webui --restart unless-stopped \
  --network host \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  -v openwebui-data:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
echo "Open WebUI is running at http://localhost:8080"
