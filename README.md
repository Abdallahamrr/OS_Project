🖥️ OS System Monitor (Cross-Platform)
A lightweight, containerized monitoring solution that provides a real-time web dashboard for system health. This tool bridges the gap between raw hardware metrics (from Prometheus exporters) and a human-readable interface, supporting both Windows and Linux/WSL hosts.

🚀 Quick Start
1. Prerequisites
Ensure your host machine is running a metrics exporter:

Windows: windows_exporter (Enable collectors: cpu,memory,thermalzone,gpu,logical_disk).

Linux: node_exporter.

2. Run with Docker
Deploy the monitor using Docker Hub:

Bash

docker run -d \
  --name system-monitor \
  -p 8080:80 \
  -v $(pwd)/logs:/app/logs \
  --add-host=host.docker.internal:host-gateway \
  abdallahamrr/os_system_monitor:latest
📊 Features
Live Dashboard: Auto-refreshing HTML interface with dynamic, color-coded health bars.

Cross-Platform: Automatic detection and normalization of metrics for both Windows and Linux.

Hardware Tracking: Real-time monitoring of CPU Load, Temperature, GPU Utilization, Memory, and Disk I/O.

Session Reports: Built-in JavaScript engine to generate instant summary reports (Min/Max/Avg) with a single click.

Zero-Dependency UI: No heavy databases required; uses an efficient flat-file logging system.

🛠️ System Architecture
The project follows a modular 3-tier design:

The Source (Host): Prometheus-style exporters expose hardware data at :9182 (Win) or :9100 (NIX).

The Collector (Bash): A Dockerized script polls the host, calculates deltas (for live load accuracy), and handles OS-specific metric naming.

The Reporter (HTML/JS): A secondary script converts logs into a CSS-styled dashboard and generates historical session data.

📂 Project Structure
Plaintext

.
├── monitor.sh          # Primary data collection engine
├── reporter.sh         # HTML dashboard & report generator
├── Dockerfile          # Container configuration
├── docker-compose.yml  # Multi-container orchestration
└── logs/
    ├── system_metrics.log  # Flat-file database (History)
    └── dashboard.html      # Live web interface
