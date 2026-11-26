#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Platform — Download & Install Core Binaries (Step 2)
# ------------------------------------------------------------------------------
# Downloads the compiled .so binaries from public GitHub and installs them
# into the application.
#
# Supports OS-tagged binaries:
#   • RHEL 8.10 (Ootpa):         *_rhel_ootpa*.so
#   • Debian Trixie-Slim (13):   *_debian_trixie-slim*.so
#   • macOS (OSX on ARM):        *_osx_arm*.so / *_macos_arm*.so
#
# Usage:
#   ./scripts/download-core.sh [--repo=<git_url>] [--os=<os_tag>] [--tag=<version>]
#   ./scripts/download-core.sh --tarball=<url_to_tarball>
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Auto-detect host OS
detect_default_os() {
    # Check macOS / OSX
    if [ "$(uname -s)" = "Darwin" ]; then
        ARCH="$(uname -m)"
        if [ "${ARCH}" = "arm64" ]; then
            echo "_osx_arm"
            return
        fi
        echo "_osx_x86_64"
        return
    fi

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
            rhel|centos|almalinux|rocky)
                echo "_rhel_ootpa"
                return
                ;;
            debian|ubuntu)
                echo "_debian_trixie-slim"
                return
                ;;
        esac
        if [[ "${VERSION_ID:-}" =~ ^8 ]]; then
            echo "_rhel_ootpa"
            return
        fi
    fi
    # Default to RHEL 8.10 (Ootpa)
    echo "_rhel_ootpa"
}

DEFAULT_REPO_URL="${CORE_REPO_URL:-https://github.com/slow-vibing/public-python-app-lib.git}"
DEFAULT_TAG="${CORE_TAG:-main}"
DEFAULT_TARBALL_URL="${CORE_TARBALL_URL:-}"
DETECTED_OS="$(detect_default_os)"

REPO_URL="${DEFAULT_REPO_URL}"
TAG="${DEFAULT_TAG}"
TARBALL_URL="${DEFAULT_TARBALL_URL}"
OS_TAG="${CORE_OS_TAG:-${DETECTED_OS}}"

for arg in "$@"; do
    case "${arg}" in
        --repo=*)
            REPO_URL="${arg#*=}"
            ;;
        --tag=*)
            TAG="${arg#*=}"
            ;;
        --tarball=*)
            TARBALL_URL="${arg#*=}"
            ;;
        --os=*)
            RAW_OS="${arg#*=}"
            if [[ ! "${RAW_OS}" =~ ^_ ]]; then RAW_OS="_${RAW_OS}"; fi
            RAW_OS="${RAW_OS%_}"
            OS_TAG="${RAW_OS}"
            ;;
        --help|-h)
            echo "Usage: ./scripts/download-core.sh [options]"
            echo "Options:"
            echo "  --repo=<url>       Public GitHub repo URL (default: ${DEFAULT_REPO_URL})"
            echo "  --tag=<version>    Version tag or branch (default: ${DEFAULT_TAG})"
            echo "  --tarball=<url>    Download directly from release tarball URL"
            echo "  --os=<os_tag>      Target OS binary: '_rhel_ootpa', '_debian_trixie-slim', or '_osx_arm' (auto-detected: ${DETECTED_OS})"
            exit 0
            ;;
    esac
done

echo "======================================================================"
echo "Platform — Downloading Core Binaries (Step 2)"
echo "Target Application Directory: ${APP_DIR}"
echo "Selected OS Binary Tag:       ${OS_TAG}"
echo "======================================================================"

TMP_DIR="/tmp/core-download-$$"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

# 1. Download binaries (via Tarball or Git Clone)
if [ -n "${TARBALL_URL}" ]; then
    echo "[1/4] Downloading release tarball from: ${TARBALL_URL}..."
    if command -v curl &> /dev/null; then
        curl -sSL "${TARBALL_URL}" -o "${TMP_DIR}/core.tar.gz"
    elif command -v wget &> /dev/null; then
        wget -q "${TARBALL_URL}" -O "${TMP_DIR}/core.tar.gz"
    else
        echo "[ERROR] Neither curl nor wget is installed."
        exit 1
    fi
    echo "  Extracting tarball..."
    tar -xzf "${TMP_DIR}/core.tar.gz" -C "${TMP_DIR}"
else
    echo "[1/4] Cloning public binary repo: ${REPO_URL} (${TAG})..."
    git clone --depth 1 --branch "${TAG}" "${REPO_URL}" "${TMP_DIR}/repo"
    cp -r "${TMP_DIR}/repo"/* "${TMP_DIR}/" 2>/dev/null || true

    # If repository stores per-OS archives in dist/, unpack the matching one
    OS_ARCHIVE=$(find "${TMP_DIR}" -name "*${OS_TAG}*.tar.gz" 2>/dev/null | head -n 1 || true)
    if [ -z "${OS_ARCHIVE}" ]; then
        OS_ARCHIVE=$(find "${TMP_DIR}" -name "*.tar.gz" 2>/dev/null | head -n 1 || true)
    fi
    if [ -n "${OS_ARCHIVE}" ]; then
        echo "  Unpacking OS archive: $(basename "${OS_ARCHIVE}")..."
        tar -xzf "${OS_ARCHIVE}" -C "${TMP_DIR}"
    fi
fi

# 2. Verify that .so binaries exist in the downloaded package
echo "[2/4] Verifying downloaded .so binaries matching ${OS_TAG}..."
DOWNLOADED_SERVICES=$(find "${TMP_DIR}" -path "*/app/services/*${OS_TAG}*.so" 2>/dev/null || find "${TMP_DIR}" -path "*/app/services/*.so" 2>/dev/null || true)
DOWNLOADED_MIDDLEWARE=$(find "${TMP_DIR}" -path "*/app/middleware/*${OS_TAG}*.so" 2>/dev/null || find "${TMP_DIR}" -path "*/app/middleware/*.so" 2>/dev/null || true)

if [ -z "${DOWNLOADED_SERVICES}" ] || [ -z "${DOWNLOADED_MIDDLEWARE}" ]; then
    echo "[ERROR] Downloaded package does not contain expected .so files for ${OS_TAG}!"
    rm -rf "${TMP_DIR}"
    exit 1
fi

# 3. Install .so binaries into application
echo "[3/4] Installing .so binaries into ${APP_DIR}..."
mkdir -p "${APP_DIR}/app/services" "${APP_DIR}/app/middleware" "${APP_DIR}/bin"

# Copy OS-tagged files and create standard symlinks
for mod in "auth_service" "activity_logger" "license_manager" "email_service" "notification_scheduler"; do
    MATCH=$(find "${TMP_DIR}" -path "*/app/services/${mod}*${OS_TAG}*.so" 2>/dev/null | head -n 1 || true)
    if [ -z "${MATCH}" ]; then
        MATCH=$(find "${TMP_DIR}" -path "*/app/services/${mod}*.so" 2>/dev/null | head -n 1 || true)
    fi
    if [ -n "${MATCH}" ]; then
        FNAME=$(basename "${MATCH}")
        cp -v "${MATCH}" "${APP_DIR}/app/services/${FNAME}"
        # Create standard alias symlink for transparent Python importing
        ln -sf "${FNAME}" "${APP_DIR}/app/services/${mod}.so"
    fi
done

MID_MATCH=$(find "${TMP_DIR}" -path "*/app/middleware/activity_middleware*${OS_TAG}*.so" 2>/dev/null | head -n 1 || true)
if [ -z "${MID_MATCH}" ]; then
    MID_MATCH=$(find "${TMP_DIR}" -path "*/app/middleware/activity_middleware*.so" 2>/dev/null | head -n 1 || true)
fi
if [ -n "${MID_MATCH}" ]; then
    MID_FNAME=$(basename "${MID_MATCH}")
    cp -v "${MID_MATCH}" "${APP_DIR}/app/middleware/${MID_FNAME}"
    ln -sf "${MID_FNAME}" "${APP_DIR}/app/middleware/activity_middleware.so"
fi

# Copy client verification tool if present
if [ -f "${TMP_DIR}/bin/app-licverify" ]; then
    cp -v "${TMP_DIR}/bin/app-licverify" "${APP_DIR}/bin/"
    chmod +x "${APP_DIR}/bin/app-licverify"
elif [ -f "${TMP_DIR}/bin/app-licverify" ]; then
    cp -v "${TMP_DIR}/bin/app-licverify" "${APP_DIR}/bin/"
    chmod +x "${APP_DIR}/bin/app-licverify"
fi

# 4. Verify binary installation integrity
echo "[4/4] Verifying binary installation..."
MISSING=0
for mod in "auth_service" "activity_logger" "license_manager" "email_service" "notification_scheduler"; do
    if ! ls "${APP_DIR}/app/services/${mod}"*.so &>/dev/null; then
        echo "  ❌ Warning: app/services/${mod}*.so not found!"
        MISSING=1
    fi
done
if ! ls "${APP_DIR}/app/middleware/activity_middleware"*.so &>/dev/null; then
    echo "  ❌ Warning: app/middleware/activity_middleware*.so not found!"
    MISSING=1
fi

rm -rf "${TMP_DIR}"

if [ "${MISSING}" -eq 1 ]; then
    echo "[ERROR] One or more core .so binaries failed to install."
    exit 1
fi

echo ""
echo "======================================================================"
echo "✓ STEP 2 COMPLETE!"
echo "Core native .so binaries successfully installed into ${APP_DIR}."
echo ""
echo "Installed binaries (OS: ${OS_TAG}):"
ls -lh "${APP_DIR}"/app/services/*.so "${APP_DIR}"/app/middleware/*.so 2>/dev/null || true
echo "======================================================================"
