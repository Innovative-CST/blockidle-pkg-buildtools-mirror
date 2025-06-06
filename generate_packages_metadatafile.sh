#!/bin/bash

# Define color functions
green()  { echo -e "\033[32m$1\033[0m"; }
blue()   { echo -e "\033[34m$1\033[0m"; }
red()    { echo -e "\033[31m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
# === CONFIGURATION ===
ARCH_DIRS=("binary-aarch64" "binary-arm" "binary-i686" "binary-x86_64" "binary-all")
DIST_PATH="./dists/stable/main"
RELEASE_VERSION="v1.0.0"
GITHUB_REPO="https://github.com/Innovative-CST/blockidle-pkg-buildtools-mirror"
GITHUB_RELEASE_URL="$GITHUB_REPO/releases/download/$RELEASE_VERSION"

# Usage: ./check-package.sh <package-name>

PACKAGES=("apt-ftparchive" "dpkg-scanpackages" "xz-utils" "gzip")

for PACKAGE in "${PACKAGES[@]}"; do
    if dpkg -s "$PACKAGE" >/dev/null 2>&1; then
        green "Package '$PACKAGE' is installed."
    else
        red "Package '$PACKAGE' is NOT installed."
        yellow "Installing '$PACKAGE'..."
        apt update && apt install -y "$PACKAGE"
    fi
done

blue "[INFO] Generating Packages, updating links, compressing..."

for ARCH in "${ARCH_DIRS[@]}"; do
    ARCH_PATH="$DIST_PATH/$ARCH"
    PACKAGES_FILE="$ARCH_PATH/Packages"

    blue "[INFO] Processing $ARCH_PATH"

    # 1. Generate Packages
    dpkg-scanpackages -m "$ARCH_PATH" /dev/null > "$PACKAGES_FILE"

    # 2. Fix the Filename field to only include the .deb filename
    # For example: ./dists/stable/main/binary-aarch64/blk-utils_2.40.2-3_aarch64.deb
    # becomes:      https://github.com/.../blk-utils_2.40.2-3_aarch64.deb
    
    sed -i -E "s|^Filename: .*/([^/]+\.deb)$|Filename: \1|" "$PACKAGES_FILE"

    blue "Compressing $PACKAGES_FILE"
    
    # 3. Compress
    gzip -k -f "$PACKAGES_FILE"       # -> Packages.gz
    xz -k -f "$PACKAGES_FILE"         # -> Packages.xz
    # 4. Generate the Release file
    apt-ftparchive release "./dists/stable" > "./dists/stable/Release"
    
    gpg --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" --digest-algo SHA256 --clearsign -o "./dists/stable/InRelease" "./dists/stable/Release"
    gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" --armor --detach-sign -u "appdeveloper400@gmail.com" "./dists/stable/Release"
    mv './dists/stable/Release.asc' './dists/stable/Release.gpg'
    
    # (Optional) Sign the Release file (for signed APT repos)
    # gpg --default-key "$GPG_KEY_ID" -abs -o "$DIST_PATH/Release.gpg" "$DIST_PATH/Release"
    # gpg --default-key "$GPG_KEY_ID" --clearsign -o "$DIST_PATH/InRelease" "$DIST_PATH/Release"
        
    green "[OK] Done: $ARCH"
done

green "[DONE] All Packages generated and compressed."