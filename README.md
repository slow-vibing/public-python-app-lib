# Python App Library (`python-app-lib`)

> [!CAUTION]
> **PROPRIETARY**
> This repository contains the static python library distributed to develop Python-based app

---

## 1. Architecture & Architecture Notice

This repository contains the ready-to-deploy python library.

---

## 2. Prerequisites

* **Python**: 3.11+
* **Database**: MySQL 8.0+ or MariaDB 10.5+
* **Operating System**: Linux (x86_64 or containerized via Docker)

---

## 3. Download Core Native Binaries (.so)

Download and install the precompiled native binaries for your operating system:

```bash
# Automatically detects host OS and installs matching .so binaries:
./scripts/download-core.sh

# Or explicitly select target OS:
./scripts/download-core.sh --os=_rhel_ootpa         # RHEL 8.10 / CentOS 8 / AlmaLinux
./scripts/download-core.sh --os=_debian_trixie-slim # Debian 13 / Ubuntu
./scripts/download-core.sh --os=_osx_arm            # macOS Apple Silicon (ARM64)
```

## 4. License Configuration

This library requires a valid, cryptographically signed enterprise license to run. You can provide your license in either of two ways:

### Option A: Via Environment Variable (Recommended for CI/CD & Docker)
Set the `LIB_LICENSE_KEY` environment variable in your `.env` or container environment:

```bash
export LIB_LICENSE_KEY="LIC-eyJjbGllbnQiOi...<your-token>"
```

### Option B: Via `license.lic` File
Place your issued `license.lic` file directly into the project root directory:

```bash
cp /path/to/issued/license.lic ./license.lic
```

> **Need a license or renewal?**
> Please contact us by creating GitHub ticket/issue or through our technical account representative to obtain a valid license key or renew an expired license.