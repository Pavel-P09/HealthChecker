#!/bin/bash

# This file contains all the necessary configuration like thresholds, Telegram bot token, etc.
# Load configuration variables (replace /home/your_username/HealthChecker/config/healthchecker.conf with your actual path)
source /home/your_username/HealthChecker/config/healthchecker.conf

# Define log file path with timestamp (replace /home/your_username/HealthChecker/logs/ with your actual path)
# Logs will be stored in a directory with a timestamped filename for easy tracking.
LOG_FILE="/home/your_username/HealthChecker/logs/health_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to send messages to Telegram
# This function uses the Telegram Bot API to send messages to a specified chat.
# It takes one argument: the message text.
send_telegram() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=$1" \
    -d parse_mode="MarkdownV2"
}

# Function to escape Markdown special characters for Telegram
# This ensures that special characters in messages are properly escaped to avoid formatting issues.
# It takes one argument: the text to be escaped.
escape_md() {
  echo "$1" | sed -e 's/[_*[\]()~`>#\+\-=|{}.!]/\\&/g' -e 's/%/%%/g'
}

# Start the health check process
echo "Starting Health Check..." | tee -a "$LOG_FILE"

# --- Disk Check ---
# This block checks the disk usage and filesystem errors.
# It monitors the specified disk and sends an alert if usage exceeds the critical threshold.
DISK_USAGE=$(df -h "$DISK_TO_MONITOR" | awk 'NR==2 {print $5}')
USAGE_INT=${DISK_USAGE%\%}
FS_ERRORS=$(sudo dmesg --ctime | grep -iE "EXT4-fs error|I/O error|failed" | grep -vE "vboxguest|CIFS|drm|vmwgfx" | tail -n 5)
[ -z "$FS_ERRORS" ] && FS_ERRORS="No filesystem errors detected."

echo "Disk Usage: $DISK_USAGE" | tee -a "$LOG_FILE"
echo -e "Filesystem Status:\n$FS_ERRORS" | tee -a "$LOG_FILE"

if [ "${USAGE_INT}" -ge "${DISK_CRITICAL}" ]; then
  MESSAGE=$(printf "⚠️ *Disk Usage Critical*\n📌 *Device:* \`%s\`\n💾 *Usage:* \`%s\`\n🔍 *Filesystem Status:*\n\`\`\`\n%s\n\`\`\`" \
    "$DISK_TO_MONITOR" "$(escape_md "$DISK_USAGE")" "$(escape_md "$FS_ERRORS")")
  send_telegram "$MESSAGE"
fi

# --- CPU Check ---
# This block checks the CPU usage and identifies the top process consuming CPU.
# It sends an alert if CPU usage exceeds the critical threshold.
CPU_IDLE=$(mpstat 1 1 | awk '/Average/ {print $NF}')
CPU_USAGE=$((100 - ${CPU_IDLE%.*}))

echo "CPU Usage: $CPU_USAGE%" | tee -a "$LOG_FILE"

if [ "$CPU_USAGE" -ge "$CPU_CRITICAL" ]; then
  TOP_PROCESS=$(ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head -n 2 | tail -n 1)
  MESSAGE=$(printf "⚠️ *CPU Usage Critical*\n📌 *Usage:* \`%s%%\`\n🔍 *Top Process:*\n\`\`\`\n%s\n\`\`\`" \
    "$CPU_USAGE" "$(escape_md "$TOP_PROCESS")")
  send_telegram "$MESSAGE"
fi

# --- Memory Check ---
# This block checks the memory usage and identifies the top process consuming memory.
# It sends an alert if memory usage exceeds the critical threshold.
MEM_USED=$(free | awk '/Mem/{printf("%.0f"), $3/$2 * 100}')
echo "Memory Usage: $MEM_USED%" | tee -a "$LOG_FILE"

if [ "$MEM_USED" -ge "$MEMORY_CRITICAL" ]; then
  TOP_PROCESS=$(ps -eo pid,ppid,cmd,%mem --sort=-%mem | head -n 2 | tail -n 1)
  MESSAGE=$(printf "⚠️ *Memory Usage Critical*\n📌 *Usage:* \`%s%%\`\n🔍 *Top Process:*\n\`\`\`\n%s\n\`\`\`" \
    "$MEM_USED" "$(escape_md "$TOP_PROCESS")")
  send_telegram "$MESSAGE"
fi

# --- Network Traffic Check ---
# This block checks the network traffic and identifies the top process consuming bandwidth.
# It sends an alert if network traffic exceeds the critical threshold.
NET_USAGE=$(vnstat -i "$NETWORK_INTERFACE" --oneline | awk -F';' '{print $4, $5}')
RX=$(echo "$NET_USAGE" | awk '{print $1}')
TX=$(echo "$NET_USAGE" | awk '{print $3}')

echo "Network RX: $RX MiB, TX: $TX MiB" | tee -a "$LOG_FILE"

RX_INT=${RX%.*}
TX_INT=${TX%.*}

if [ "$RX_INT" -ge "$NETWORK_CRITICAL" ] || [ "$TX_INT" -ge "$NETWORK_CRITICAL" ]; then
  # Use netstat to identify the top network-consuming process
  TOP_PROCESS=$(sudo netstat -tupn 2>/dev/null | awk '/ESTABLISHED/{print $7}' | cut -d'/' -f1 | xargs -I{} ps -p {} -o comm= | sort | uniq -c | sort -nr | head -n 1)
  [ -z "$TOP_PROCESS" ] && TOP_PROCESS="No significant network-consuming process detected."

  # Use iftop to get detailed traffic information
  TRAFFIC_DETAILS=$(sudo iftop -i "$NETWORK_INTERFACE" -t -s 60 -L 5 2>/dev/null)

  # Format the message with detailed traffic information
  MESSAGE=$(printf "⚠️ *Network Traffic Critical*\n📌 *Download:* \`%s MiB\`\n📌 *Upload:* \`%s MiB\`\n🔍 *Top Process:*\n\`\`\`\n%s\n\`\`\`\n\n🔎 *Detailed Traffic Analysis:*\n\`\`\`\n%s\n\`\`\`" \
    "$RX" "$TX" "$(escape_md "$TOP_PROCESS")" "$(escape_md "$TRAFFIC_DETAILS")")

  send_telegram "$MESSAGE"
fi


# --- Internet Speed Test ---
# This block checks the internet speed and identifies potential issues.
# It sends an alert if the internet speed is below the critical threshold.
echo "Measuring Internet speed..." | tee -a "$LOG_FILE"

# Run speedtest-cli and capture output
SPEEDTEST_OUTPUT=$(speedtest-cli --simple 2>&1)

# Check if speedtest-cli failed
if echo "$SPEEDTEST_OUTPUT" | grep -q "ERROR"; then
  echo "Speedtest failed: $SPEEDTEST_OUTPUT" | tee -a "$LOG_FILE"

  # Analyze local network and ISP issues
  PROVIDER_CHECK=$(ping -c 5 8.8.8.8)

  PACKET_LOSS=$(echo "$PROVIDER_CHECK" | grep -oP '\d+(?=% packet loss)')
  AVG_PING=$(echo "$PROVIDER_CHECK" | awk -F'/' '/rtt/{print $5}')

  if [ "$PACKET_LOSS" -gt 0 ] || (( $(echo "$AVG_PING > 100" | bc -l) )); then
    REASON="Problem from ISP side \(high ping or packet loss detected\)\."
  else
    REASON="High local network usage \(downloads or streaming activity\)\."
  fi

  # Get active network processes using netstat and ps
  NETWORK_PROCESSES=$(sudo netstat -tupn 2>/dev/null | awk '/ESTABLISHED/{print $7}' | cut -d'/' -f1 | xargs -I{} ps -p {} -o comm= | sort | uniq -c | sort -nr | head -n 5)

  if [ -z "$NETWORK_PROCESSES" ]; then
    NETWORK_PROCESSES="No active network-consuming processes detected."
  fi

  MESSAGE_SPEED=$(printf "🚨 *Internet Speed Test Failed*\n🔍 *Possible reason:* %s\n\n🔍 *Top Network Processes:*\n\`\`\`\n%s\n\`\`\`" \
    "$REASON" "$(escape_md "$NETWORK_PROCESSES")")

  send_telegram "$MESSAGE_SPEED"
else
  # Extract download and upload speeds from speedtest-cli output
  DOWNLOAD_SPEED=$(echo "$SPEEDTEST_OUTPUT" | awk '/Download/ {print $2}')
  UPLOAD_SPEED=$(echo "$SPEEDTEST_OUTPUT" | awk '/Upload/ {print $2}')

  echo "Download Speed: $DOWNLOAD_SPEED Mbps" | tee -a "$LOG_FILE"
  echo "Upload Speed: $UPLOAD_SPEED Mbps" | tee -a "$LOG_FILE"

  if (( $(echo "$DOWNLOAD_SPEED < $NETWORK_SPEED_CRITICAL" | bc -l) )) || (( $(echo "$UPLOAD_SPEED < $NETWORK_SPEED_CRITICAL" | bc -l) )); then
    # Check local network usage and ISP issues
    PROVIDER_CHECK=$(ping -c 5 8.8.8.8)

    PACKET_LOSS=$(echo "$PROVIDER_CHECK" | grep -oP '\d+(?=% packet loss)')
    AVG_PING=$(echo "$PROVIDER_CHECK" | awk -F'/' '/rtt/{print $5}')

    if [ "$PACKET_LOSS" -gt 0 ] || (( $(echo "$AVG_PING > 100" | bc -l) )); then
      REASON="Problem from ISP side \(high ping or packet loss detected\)\."
    else
      REASON="High local network usage \(downloads or streaming activity\)\."
    fi

    # Get active network processes using netstat and ps
    NETWORK_PROCESSES=$(sudo netstat -tupn 2>/dev/null | awk '/ESTABLISHED/{print $7}' | cut -d'/' -f1 | xargs -I{} ps -p {} -o comm= | sort | uniq -c | sort -nr | head -n 5)

    if [ -z "$NETWORK_PROCESSES" ]; then
      NETWORK_PROCESSES="No active network-consuming processes detected."
    fi

    MESSAGE_SPEED=$(printf "🚨 *Internet Speed Alert*\n📥 *Download:* \`%s Mbps\`\n📤 *Upload:* \`%s Mbps\`\n🔍 *Possible reason:* %s\n\n🔍 *Top Network Processes:*\n\`\`\`\n%s\n\`\`\`" \
      "$DOWNLOAD_SPEED" "$UPLOAD_SPEED" "$REASON" "$(escape_md "$NETWORK_PROCESSES")")

    send_telegram "$MESSAGE_SPEED"
  fi
fi

# Clean up old logs, keep last 3 only
# This ensures that logs do not accumulate indefinitely.
# ! replace /home/your_username/HealthChecker/logs/ with your actual path
cd /home/your_username/HealthChecker/logs
ls -t | tail -n +4 | xargs rm -f
