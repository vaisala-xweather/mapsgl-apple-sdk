#!/usr/bin/env bash

#
# Usage:
#   ./scripts/update-version <maps sem version number>
#

set -eou pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ $# -eq 0 ]; then
    echo "Usage: v<semantic version>"
    exit 1
fi

SEM_VERSION=$1
SEM_VERSION=${SEM_VERSION/#v}
SHORT_VERSION=${SEM_VERSION%%-*}

step() { >&2 echo -e "\033[1m\033[36m* $*\033[0m"; }
warning() { >&2 echo -e "\033[1m\033[33m! $*\033[0m"; }
finish() { >&2 echo -e "\033[1m\033[32m✔ $*\033[0m"; }

brew_install_if_needed() {
    local command=$1
    if [[ ! $(command -v "$command") ]]; then
        step "Homebrew: Install $command"
        HOMEBREW_NO_ENV_HINTS=1 brew install -q "$command"
    fi
}

brew_install_if_needed jq

step "Version ${SEM_VERSION}"

# Update Info.plist
# step "Update Info.plist"
# plutil -replace CFBundleShortVersionString -string "$SHORT_VERSION" Sources/MapboxMaps/Info.plist
# plutil -convert json -o - Sources/MapboxMaps/Info.plist | jq -r '.CFBundleVersion = ((.CFBundleVersion|tonumber + 1)|tostring)' | plutil -convert xml1 -o Sources/MapboxMaps/Info.plist -

# Update Package.swift
step "Update Package.swift"
sed -Ei '' "s@^(let version: [^=]+= )\"[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?\"@\1\"$SEM_VERSION\"@g" Package.swift
warning "Make sure checksums are updated in Package.swift from the latest release!"

# Update Carthage
step "Update Cartfile"
# sed -i '' s/"mapsgl-apple-sdk/.*/Carthage"/"mapsgl-apple-sdk/${SEM_VERSION}/Carthage"/ Cartfile
sed -Ei '' "s@(v)[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?@\1$SEM_VERSION@g; s@~> [0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?@~> $SEM_VERSION@g" Cartfile
sed -Ei '' "s@\"[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?\": \"https://cdn\.aerisapi\.com/sdk/ios/mapsgl/releases/[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?@\"$SEM_VERSION\": \"https://cdn.aerisapi.com/sdk/ios/mapsgl/releases/$SEM_VERSION@g" Carthage/MapsGLCore.json
sed -Ei '' "s@\"[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?\": \"https://cdn\.aerisapi\.com/sdk/ios/mapsgl/releases/[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?@\"$SEM_VERSION\": \"https://cdn.aerisapi.com/sdk/ios/mapsgl/releases/$SEM_VERSION@g" Carthage/MapsGLMaps.json
sed -Ei '' "s@\"[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?\": \"https://cdn\.aerisapi\.com/sdk/ios/mapsgl/releases/[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?@\"$SEM_VERSION\": \"https://cdn.aerisapi.com/sdk/ios/mapsgl/releases/$SEM_VERSION@g" Carthage/MapsGLRenderer.json

# Update MapsGL.podspec
step "Update Podspec"
sed -i '' s/"spec.version      = \".*\""/"spec.version      = \"${SEM_VERSION}\""/ MapsGL.podspec
warning "Make sure checksums are updated in MapsGL.podspec from the latest release!"

# Update MapsGL.json
# step "Update MapsGL.json"
# sed -i '' s/"\"version\" : \".*\""/"\"version\" : \"${SEM_VERSION}\""/ Sources/MapboxMaps/MapboxMaps.json

finish "Completed updating versions"