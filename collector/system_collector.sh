
#!/bin/bash


LOG_DIR="/app/logs"
LOG_FILE="/app/logs/system_metrics.log"

# Set this to 9182 for Windows (windows_exporter) or 9100 for WSL/Linux (node_exporter)
URL="http://host.docker.internal:9182/metrics"
# --- 1. INITIAL FETCH & OS DETECTION ---
RAW_DATA=$(curl -s "$URL" | tr -d '\r')
if [[ -z "$RAW_DATA" ]]; then
    echo "Error: Could not fetch data from $URL"
    exit 1
fi

# Detect OS based on metric prefixes
if echo "$RAW_DATA" | grep -q "windows_"; then
    OS="WIN"
    PREFIX="windows"
else
    OS="NIX"
    PREFIX="node"
fi

# Helper to handle scientific notation and rounding
clean_num() {
    if [[ -z "$1" || "$1" == "NaN" ]]; then echo "0"; else awk -v n="$1" 'BEGIN {printf "%.0f", n}'; fi
}

# --- 2. CPU LOAD (Live 1-Second Delta) ---
get_cpu_sums() {
    if [ "$OS" == "WIN" ]; then
        curl -s "$URL" | tr -d '\r' | awk '/windows_cpu_time_total{.*mode="idle"/ {i+=$2} /windows_cpu_time_total/ {t+=$2} END {print i "," t}'
    else
        curl -s "$URL" | tr -d '\r' | awk '/node_cpu_seconds_total{.*mode="idle"/ {i+=$2} /node_cpu_seconds_total/ {t+=$2} END {print i "," t}'
    fi
}

IFS=',' read -r IDLE1 TOTAL1 <<< "$(get_cpu_sums)"
sleep 1
IFS=',' read -r IDLE2 TOTAL2 <<< "$(get_cpu_sums)"

CPU_LOAD=$(awk -v i1="$IDLE1" -v t1="$TOTAL1" -v i2="$IDLE2" -v t2="$TOTAL2" 'BEGIN {
    td = t2 - t1; id = i2 - i1
    if (td > 0) printf "%.2f", 100 * (1 - (id / td))
    else printf "0.00"
}')

# --- 3. MEMORY (Bulletproof Fix) ---
if [ "$OS" == "WIN" ]; then
    # 1. Clean the raw data of all Windows-style line endings immediately
    CLEAN_DATA=$(echo "$RAW_DATA" | tr -d '\r')
    
    # 2. Extract and calculate in one go using AWK
    MEM_USAGE=$(echo "$CLEAN_DATA" | awk '
        /windows_memory_physical_total_bytes/ { total=$2 }
        /windows_memory_available_bytes/ { free=$2 }
        END {
            if (!total || total == 0) total = 16542089216;
            if (total > 0) {
                u = total - free;
                p = (u / total) * 100;
                if (p > 100) p = 100;
                if (p < 0) p = 0;
                printf "%.2f", p
            } else {
                print "0.00"
            }
        }')
else
    M_FREE=$(echo "$RAW_DATA" | grep "^node_memory_MemAvailable_bytes" | awk '{print $2}')
    M_TOTAL=$(echo "$RAW_DATA" | grep "^node_memory_MemTotal_bytes" | awk '{print $2}')
    MEM_USAGE=$(awk -v f="$M_FREE" -v t="$M_TOTAL" 'BEGIN {if(t>0) printf "%.2f", ((t-f)/t)*100; else print "0.00"}')
fi
# --- 4. DISK (C: for Win, / for Linux) ---
if [ "$OS" == "WIN" ]; then
    D_SIZE=$(echo "$RAW_DATA" | grep 'windows_logical_disk_size_bytes{volume="C:"}' | awk '{print $2}')
    D_FREE=$(echo "$RAW_DATA" | grep 'windows_logical_disk_free_bytes{volume="C:"}' | awk '{print $2}')
else
    D_SIZE=$(echo "$RAW_DATA" | grep 'node_filesystem_size_bytes{mountpoint="/"}' | awk '{print $2}')
    D_FREE=$(echo "$RAW_DATA" | grep 'node_filesystem_free_bytes{mountpoint="/"}' | awk '{print $2}')
fi

D_SIZE_C=$(clean_num "$D_SIZE")
D_FREE_C=$(clean_num "$D_FREE")
DISK_USAGE=$(awk -v f="$D_FREE_C" -v s="$D_SIZE_C" 'BEGIN {if(s>0) printf "%.2f", ((s-f)/s)*100; else print "0.00"}')

# --- 5. GPU LOAD (Smart Detection) ---
# Check for direct utilization first (NVIDIA Linux/Windows)
GPU_VAL=$(echo "$RAW_DATA" | grep -E "(windows_gpu_utilization|node_gpu_utilization)" | awk '{sum+=$2} END {print (sum?sum:0)}')

if [ "$(echo "$GPU_VAL < 0.01" | bc -l)" -eq 1 ]; then
    # Fallback to Engine Time Delta (Common on AMD/Integrated Windows)
    G1=$(echo "$RAW_DATA" | grep "gpu_engine_time_seconds" | awk '{sum+=$2} END {print (sum?sum:0)}')
    RAW_DATA_2=$(curl -s "$URL" | tr -d '\r')
    G2=$(echo "$RAW_DATA_2" | grep "gpu_engine_time_seconds" | awk '{sum+=$2} END {print (sum?sum:0)}')
    GPU_LOAD=$(awk -v g1="$G1" -v g2="$G2" 'BEGIN {l=(g2-g1)*100; if(l>100)l=100; printf "%.2f", (l<0?0:l)}')
else
    GPU_LOAD=$(printf "%.2f" "$GPU_VAL")
fi

# --- 6. TEMPERATURE ---
if [ "$OS" == "WIN" ]; then
    TEMP=$(echo "$RAW_DATA" | grep "^windows_thermalzone_temperature_celsius" | awk '{print $2}' | head -n 1)
else
    TEMP=$(echo "$RAW_DATA" | grep "node_hwmon_temp_celsius" | awk '{print $2}' | head -n 1)
fi
[[ -z "$TEMP" ]] && TEMP_STR="N/A" || TEMP_STR="$(clean_num "$TEMP")°C"

# --- 7. FINAL LOGGING & REPORT GENERATION ---
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
REPORT_LINE="[$OS] $TIMESTAMP | CPU: $CPU_LOAD% | Temp: $TEMP_STR | GPU: $GPU_LOAD% | Mem: $MEM_USAGE% | Disk: $DISK_USAGE%"

echo "$REPORT_LINE" >> "$LOG_FILE"

# Trigger your external report generator (HTML/Dashboards)
if [ -f "/app/collector/generate_report.sh" ]; then
    /app/collector/generate_report.sh
fi

echo "Success: $REPORT_LINE"