# HealthChecker
Comprehensive monitoring of HDD, CPU, RAM, and network on Debian-based systems, with recommendations and notifications.

## Overview
HealthChecker is a lightweight and flexible Bash script designed to monitor system health metrics (disk usage, CPU usage, memory usage, network traffic, and internet speed) on Debian-based systems. It sends alerts to Telegram if any metric exceeds a predefined threshold.

## Features

- **Lightweight**: Minimal system resource usage.
- **Flexible**: Easy to configure for different thresholds and monitoring parameters.
- **Real-time Alerts**: Sends notifications to Telegram when issues are detected.
- **Detailed Reports**: Provides detailed information about system health and network usage.
- **Easy to Set Up**: Simple installation and configuration process.

## Installation

### Prerequisites

- Debian-based system (e.g., Ubuntu, Debian).
- `vnstat`, `iftop`, `nethogs`, `speedtest-cli`, and `bc` installed.

### Step 1: Install Required Utilities

Run the following commands to install the required utilities:
```bash

sudo apt update
sudo apt install vnstat iftop nethogs speedtest-cli bc
```
### Step 2: Clone the Repository

Clone the HealthChecker repository to your local machine:
```bash
git clone https://github.com/Pavel-P09/HealthChecker
cd HealthChecker
```
### Step 3: Configure the Script

Edit the configuration file config/healthchecker.conf to set your thresholds and parameters:
```bash
nano config/healthchecker.conf
```
Replace the placeholders with your actual values:
```bash
# Telegram Bot Token (replace with your actual token)
TELEGRAM_BOT_TOKEN="your_telegram_bot_token"
# Telegram Chat ID (replace with your actual chat ID)
TELEGRAM_CHAT_ID="your_telegram_chat_id"
# Disk to monitor (replace with your actual disk, e.g., /dev/sda1)
DISK_TO_MONITOR="/dev/sda1"
# Critical disk usage threshold (in percentage)
DISK_CRITICAL=90
# Critical CPU usage threshold (in percentage)
CPU_CRITICAL=90
# Critical memory usage threshold (in percentage)
MEMORY_CRITICAL=90
# Critical network traffic threshold (in MiB)
NETWORK_CRITICAL=1000
# Critical internet speed threshold (in Mbps)
NETWORK_SPEED_CRITICAL=10
```
### Step 4: Make the Script Executable
Make the script executable:
```bash
chmod +x scripts/healthcheck.sh
```
### Step 5: Run the Script
Run the script manually to test it:
```bash
./scripts/healthcheck.sh
```
### Step 6: Schedule the Script (Optional)
To run the script periodically, add it to cron:
```bash
crontab -e
```
Add the following line to run the script every 5 minutes:
```bash
*/5 * * * * /path/to/HealthChecker/scripts/healthcheck.sh
```

## Important Notes
 **Edit Script Paths**: Before running the script, make sure to edit the following lines in `scripts/healthcheck.sh` to match your system configuration:
  ```bash
  # Load configuration variables (replace /home/your_username/HealthChecker/config/healthchecker.conf with your actual path)
  source /home/your_username/HealthChecker/config/healthchecker.conf

  # Define log file path with timestamp (replace /home/your_username/HealthChecker/logs/ with your actual path)
  LOG_FILE="/home/your_username/HealthChecker/logs/health_$(date +%Y%m%d_%H%M%S).log"
  mkdir -p "$(dirname "$LOG_FILE")"

# Clean up old logs, keep last 3 only
# This ensures that logs do not accumulate indefinitely.
# ! replace /home/your_username/HealthChecker/logs/ with your actual path
cd /home/your_username/HealthChecker/logs
ls -t | tail -n +4 | xargs rm -f
```

## Contributing
Contributions are welcome! Please open an issue or submit a pull request if you have any improvements or bug fixes.


## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.


