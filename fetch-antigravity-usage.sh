#!/bin/bash

set -e

convert_utc_to_local() {
    local utc_time="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$utc_time" "+%s" 2>/dev/null)
        if [ -n "$ts" ]; then
            date -j -f "%s" "$ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$utc_time"
        else
            echo "$utc_time"
        fi
    else
        date -d "${utc_time} UTC" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$utc_time"
    fi
}

PROCESS_LINE=$(ps aux | grep -i antigravity | grep -E '(language-server|lsp|server)' | grep -v grep | head -1)

if [ -z "$PROCESS_LINE" ]; then
    echo "Error: Antigravity process not found. Make sure Antigravity is running." >&2
    exit 1
fi

CSRF_TOKEN=$(echo "$PROCESS_LINE" | grep -oE '\-\-csrf_token[= ]+[^ ]+' | sed 's/--csrf_token[= ]*//' | tr -d "'" | tr -d '"')
PID=$(echo "$PROCESS_LINE" | awk '{print $2}')
PORTS=$(lsof -Pan -p "$PID" -i 2>/dev/null | grep LISTEN | awk '{print $9}' | cut -d: -f2 | sort -u)

if [ -z "$PORTS" ]; then
    echo "Error: No listening ports found." >&2
    exit 1
fi

for PORT in $PORTS; do
    RESULT=$(curl -sk --max-time 1 \
        -X POST "https://127.0.0.1:$PORT/exa.language_server_pb.LanguageServerService/GetUserStatus" \
        -H "Content-Type: application/json" \
        -H "Connect-Protocol-Version: 1" \
        -H "X-Codeium-Csrf-Token: $CSRF_TOKEN" \
        -d '{"metadata":{"ideName":"antigravity","extensionName":"antigravity","locale":"en"}}' 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
        EMAIL=$(echo "$RESULT" | jq -r '.userStatus.email // "N/A"')
        AVAILABLE=$(echo "$RESULT" | jq -r '.userStatus.planStatus.availablePromptCredits // "N/A"')
        MONTHLY=$(echo "$RESULT" | jq -r '.userStatus.planStatus.planInfo.monthlyPromptCredits // "N/A"')
        
        echo "Account: $EMAIL"
        echo "Prompt Credits: $AVAILABLE / $MONTHLY"
        echo ""
        
        {
            printf "%s\t%s\t%s\t%s\n" "Model" "Remaining" "Reset Time" "Status"
            printf "%s\t%s\t%s\t%s\n" "----------------------------------------" "----------" "--------------------" "--------"
            
            while read -r model; do
                LABEL=$(echo "$model" | jq -r '.label // "Unknown"')
                FRACTION=$(echo "$model" | jq -r '.quotaInfo.remainingFraction // empty')
                RESET=$(echo "$model" | jq -r '.quotaInfo.resetTime // empty')
                
                if [ -n "$FRACTION" ]; then
                    PERCENT=$(echo "$FRACTION" | awk '{printf "%.0f", $1 * 100}')
                    REMAINING="${PERCENT}%"
                else
                    REMAINING="N/A"
                fi
                
                if [ -n "$RESET" ]; then
                    LOCAL_TIME=$(convert_utc_to_local "${RESET:0:19}")
                    RESET_DISPLAY="$LOCAL_TIME"
                else
                    RESET_DISPLAY="-"
                fi
                
                if [ -n "$FRACTION" ] && [ "$PERCENT" -eq 0 ]; then
                    STATUS="Exhausted"
                elif [ -n "$FRACTION" ] && [ "$PERCENT" -le 20 ]; then
                    STATUS="Low"
                else
                    STATUS="OK"
                fi
                
                printf "%s\t%s\t%s\t%s\n" "$LABEL" "$REMAINING" "$RESET_DISPLAY" "$STATUS"
            done < <(echo "$RESULT" | jq -c '.userStatus.cascadeModelConfigData.clientModelConfigs[]?')
        } | column -t -s $'\t'
        
        exit 0
    fi
done

echo "Error: Unable to connect to Connect API." >&2
exit 1
