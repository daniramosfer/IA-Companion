#!/bin/bash

LOG_FILE="$HOME/Library/Logs/Claude/main.log"

echo "Empezando a monitorizar los logs de Claude en: $LOG_FILE"

# Enviar estado inicial verde
curl -s -X POST http://localhost:50152/status -d '{"id": "claude", "name": "Claude", "status": "idle"}' > /dev/null

tail -F "$LOG_FILE" | while read -r line; do
    if echo "$line" | grep -q "Emitted tool permission request"; then
        # Claude está pidiendo permisos, se detuvo
        curl -s -X POST http://localhost:50152/status -d '{"id": "claude", "name": "Claude", "status": "waiting"}' > /dev/null
        echo "Claude está esperando permisos (Rojo)"
    elif echo "$line" | grep -q "Received permission response"; then
        # El usuario ha respondido en la app de Claude, vuelve a trabajar
        curl -s -X POST http://localhost:50152/status -d '{"id": "claude", "name": "Claude", "status": "working"}' > /dev/null
        echo "Claude vuelve a trabajar (Ámbar)"
    elif echo "$line" | grep -q "Sending message to session"; then
        # El usuario envió un mensaje, Claude empieza a pensar
        curl -s -X POST http://localhost:50152/status -d '{"id": "claude", "name": "Claude", "status": "working"}' > /dev/null
        echo "Claude está trabajando (Ámbar)"
    elif echo "$line" | grep -q "\[Stop hook\] Query completed"; then
        # Claude terminó de generar la respuesta
        curl -s -X POST http://localhost:50152/status -d '{"id": "claude", "name": "Claude", "status": "idle"}' > /dev/null
        echo "Claude ha terminado (Verde)"
    fi
done
