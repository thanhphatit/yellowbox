# 📦 YellowBox | Enterprise Distribution Registry

YellowBox is a centralized infrastructure resource management and distribution platform, designed to provide a "Single Source of Truth" for multi-platform executables (Binaries) and Kubernetes deployment packages (Helm Charts).

## 💎 Key Value Propositions

| Feature | Description |
| :--- | :--- |
| **Multi-Platform Support** | Consistent, native support for Windows (PowerShell), macOS, and Linux (Bash). |
| **Smart Architecture** | Auto-detects system architecture (x86_64, ARM64) to deliver the correct resource payload. |
| **High Availability** | Static-based distribution architecture ensures maximum download speed and ultra-low latency. |
| **Unified Registry** | Seamlessly combines a Binary Registry and a Helm Repository into a single, cohesive portal. |

---

## 🏗 Repository Architecture

The storage structure is standardized using a tiered model to optimize management:

```text
.
├── .github/
│   └── workflows/
│       └── update-dist.yml       # Core Orchestrator (Auto-sync manifests)
├── bin/                          # Cross-platform binary distribution
│   ├── <application-id>/         # Application identifier directory
│   │   ├── darwin-arm64/         # Builds for Apple Silicon (macOS)
│   │   ├── linux-amd64/          # Builds for Linux Server
│   │   └── windows-amd64/        # Builds for Windows Desktop
│   ├── index.html                # Binary management UI
│   └── manifest.json             # Resource metadata (System Managed)
├── charts/                       # Kubernetes Helm Repository
│   ├── index.html                # Helm management UI
│   ├── index.yaml                # Registry Index (Helm Standard)
│   └── *.tgz                     # Packaged Helm Charts
├── scripts/                      # System installation scripts
│   ├── install.sh / .ps1         # Installers for Unix and Windows
│   └── uninstall.sh / .ps1       # Uninstallers for Unix and Windows
├── index.html                    # Central portal gateway (Root Hub)
└── hub-manifest.json             # Overall system state tracking
```

---

## 🛠 Quick Start Guide

The system supports rapid command-line installation, making it incredibly easy to integrate into CI/CD pipelines or workstation setups.

### 1. For Unix Environments (macOS / Linux)
Use Bash to install the desired toolset:
```bash
curl -sSL [https://yellowbox.itblognote.com/scripts/install.sh](https://yellowbox.itblognote.com/scripts/install.sh) | bash -s -- <app_name>
```

### 2. For Windows Environments
Use PowerShell to perform the installation:
```powershell
$env:APP_NAME='<app_name>'; irm [https://yellowbox.itblognote.com/scripts/install.ps1](https://yellowbox.itblognote.com/scripts/install.ps1) | iex
```

### 3. Integrating the Helm Repository
Add YellowBox to your local repository list:
```bash
helm repo add yellowbox [https://yellowbox.itblognote.com/charts/](https://yellowbox.itblognote.com/charts/)
helm repo update
```

---

## 🔧 Administration & Scaling

The system is designed around a **"Zero Maintenance UI"** philosophy. Administrators only need to focus on managing resources, not front-end code.

### Adding a New Resource Category (e.g., `plugins/`)
1. Create a new directory at the root level.
2. Update the UI identifier (Color, Icon, Title, Description) in the `ui_config` section of the orchestration config file (`.github/workflows/update-dist.yml`).
3. Push the code. The central portal will automatically generate a new Category Card without any HTML intervention.

### Publishing Binary Applications
- Place the executables in the correct structure: `bin/<tool-name>/<platform>/`.
- Push to the `main` branch. The system will automatically update the Manifest and synchronize the installation commands on the web interface instantly.

---

## 🛡 Security & Compliance
- Supports installation at both the System level (`/usr/local/bin`) or Local level (`~/.local/bin`) depending on the user's execution privileges.
- Auto-path detection ensures users are warned if local binaries are not in their environment variables.

---
**YellowBox** - *Professional Infrastructure Delivery*