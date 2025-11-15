# DevProxy

DevProxy is a simple, reusable project for running local development web apps behind HTTPS using a Docker-based nginx proxy. It automatically generates SSL certificates and nginx configuration per project, making it easy to access your app on a LAN IP securely.


## Benefits

* Provides local HTTPS for your app, enabling secure origins.

  * Access APIs that require HTTPS (Geolocation, WebRTC, Payment APIs, etc.)
* Project-contained SSL and nginx config (.devproxy/)
* LAN IP detection or manual input
* Start/stop nginx proxy using Docker container
* Works on Linux, macOS, and Windows (Docker required)
* Easy to collaborate and share across teams


## Quick Start

### Prerequisites

* Docker installed and running
* bash shell (Linux/macOS terminal or Git Bash / WSL on Windows)

### Setup & Run

# Clone repository
git clone <repo-url>
cd <repo-name>

# Make script executable (Linux/macOS)
chmod +x script.sh

# Initialize project (generate SSL, nginx config, Dockerfile)
./script.sh init

# Start nginx proxy
./script.sh start

# Access your app securely on LAN
https://<LAN-IP>

# Stop proxy
./script.sh stop

# Check proxy status
./script.sh status

# Regenerate SSL/config (if IP changes)
./script.sh regen

> Ensure your backend (e.g., Vite/Bun) is running with --host so the container can forward traffic.


## Collaboration

* Developers can clone the repo and run init to set up .devproxy/
* Use start/stop to run the HTTPS proxy locally
* Optional: commit .devproxy if sharing SSL & config is desired


## Cross-Platform

| OS      | Notes                                               |
| ------- | --------------------------------------------------- |
| Linux   | Bash script runs natively; Docker required          |
| macOS   | Bash script runs natively; Docker required          |
| Windows | Use Git Bash or WSL; Docker Desktop must be running |

