#!/bin/bash

# Configuração dos dispositivos
declare -A DEVICES=(
    ["CREATIVE"]="Creative Stage SE|60%"
    ["HYPERX"]="HyperX Cloud Stinger Core Wireless + 7.1|90%"
)

# Função para obter ID de um dispositivo de saída pelo nome
get_device_id_by_name() {
    local device_name="$1"
    wpctl status \
      | awk '/Sinks:/{flag=1;next}/Sources:/{flag=0}flag' \
      | grep -F "$device_name" \
      | head -n1 \
      | sed -E 's/[^0-9]*([0-9]+).*/\1/'
}

# Obter IDs e informações dos dispositivos
CREATIVE_INFO="${DEVICES[CREATIVE]}"
HYPERX_INFO="${DEVICES[HYPERX]}"
DEVICE_CREATIVE=$(get_device_id_by_name "${CREATIVE_INFO%%|*}")
DEVICE_HYPERX=$(get_device_id_by_name "${HYPERX_INFO%%|*}")

# Verificar se os dispositivos foram encontrados
if [[ -z "$DEVICE_CREATIVE" ]]; then
    notify-send "Erro: Dispositivo '${CREATIVE_INFO%%|*}' não encontrado!"
    exit 1
fi
if [[ -z "$DEVICE_HYPERX" ]]; then
    notify-send "Erro: Dispositivo '${HYPERX_INFO%%|*}' não encontrado!"
    exit 1
fi

# Obter o dispositivo atual
CURRENT_DEVICE=$(wpctl status | awk '/Sinks:/{flag=1;next}/Sources:/{flag=0}flag' | grep '\*' | sed -E 's/[^0-9]*([0-9]+).*/\1/')

# Se não conseguir detectar, usar o dispositivo padrão
if [[ -z "$CURRENT_DEVICE" ]]; then
    CURRENT_DEVICE=$(wpctl status | grep "Default sink:" | sed -E 's/.*\[([0-9]+)\].*/\1/')
fi

# Determinar qual dispositivo usar baseado no atual
if [[ "$CURRENT_DEVICE" == "$DEVICE_CREATIVE" ]]; then
    # Está no Creative, alternar para HyperX
    NEW_DEVICE="$DEVICE_HYPERX"
    NEW_NAME="${HYPERX_INFO%%|*}"
    NEW_VOLUME="${HYPERX_INFO##*|}"
else
    # Está no HyperX ou não detectado, usar Creative
    NEW_DEVICE="$DEVICE_CREATIVE"
    NEW_NAME="${CREATIVE_INFO%%|*}"
    NEW_VOLUME="${CREATIVE_INFO##*|}"
fi

# Se já está no dispositivo de destino, não fazer nada
if [[ "$CURRENT_DEVICE" == "$NEW_DEVICE" ]]; then
    exit 0
fi

notify-send "$NEW_NAME | v $NEW_VOLUME"

# Alterar o dispositivo de saída padrão
wpctl set-default "$NEW_DEVICE"

# Ajustar volume e desmutar
wpctl set-volume "$NEW_DEVICE" "$NEW_VOLUME"
wpctl set-mute "$NEW_DEVICE" 0

# Mover fluxos ativos para o novo dispositivo
for STREAM_ID in $(wpctl status | grep -Eo 'Stream\s+[0-9]+' | awk '{print $2}'); do
    wpctl move "$STREAM_ID" "$NEW_DEVICE"
done

echo "Saída de áudio alternada com sucesso para o dispositivo $NEW_DEVICE."
