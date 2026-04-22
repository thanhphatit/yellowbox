# 📦 Yellowbox Distribution Hub

Welcome to the **Yellowbox Distribution Hub**. This is the official repository for hosting and distributing automation tools (CI/CD, Git utilities) and Helm Charts for the Yellowbox infrastructure.

All files hosted here are production-ready compiled binaries or packaged charts, available for immediate download and usage across multiple platforms (Linux, macOS, Windows).

---

## 🚀 Quick Start

### 1. Using Helm Charts
To deploy services to your Kubernetes cluster, add this repository to your Helm client:

```bash
# Add the Yellowbox Helm Repo
helm repo add yellowbox https://<your-username>.github.io/yellowbox/charts/

# Update the repository list
helm repo update

# Search for available charts
helm search repo yellowbox

2. Installing Tools (Binaries)

You can automatically download and install Yellowbox CLI tools using our quick installation script (supported on Linux and macOS):
Bash

curl -sSL https://<your-username>.github.io/yellowbox/scripts/install.sh | bash

For Windows users: Please navigate directly to the /bin directory to download the .exe executables manually.
📂 Repository Structure

This repository is organized following standard Distribution Hub practices to ensure stability and accessibility:

    bin/: Contains standalone pre-compiled executables (Binaries). Organized by tool name and platform architecture (darwin-arm64, linux-amd64, windows-amd64).

    charts/: The Helm Repository containing packaged .tgz charts and the index.yaml manifest.

    scripts/: Contains automation scripts for environment setup and tool installation.

🧰 Available Tools
1. cicd-manager

A multi-functional CI/CD lifecycle management suite. It includes the following independent controllers:

    config-controller: Centralized configuration management.

    docker-controller: Handles image build and push pipelines.

    helm-controller: Manages Helm templates and releases.

    k8s-controller: Interacts directly with Kubernetes clusters.

    release-controller: Manages versioning and semantic releases.

    terraform-controller: Infrastructure as Code (IaC) automation.

2. git-push

A utility tool designed to standardize commit workflows and push source code to remote repositories seamlessly.
3. Helm Charts

    oblivion-sentinel: (v0.0.10) - [Insert a brief description of what this chart does here]

🛠 Maintainer's Guide

This section outlines the basic operations for updating this distribution hub:

Updating the Helm Repository:
After adding a new .tgz package to the charts/ directory, run the following command at the repository root to rebuild the index:
Bash

helm repo index charts/ --url https://<your-username>.github.io/yellowbox/charts/

Adding a New Tool or Version:

    Compile the binary for the target platforms.

    Place the executable in the correct path: bin/<tool-name>/<platform-architecture>/.

    (For Windows) Always ensure the file has an .exe extension.

    If a completely new tool is added, update the scripts/install.sh accordingly.

Maintained and developed by the Yellowbox Project. Internal source codes are managed in separate private repositories.