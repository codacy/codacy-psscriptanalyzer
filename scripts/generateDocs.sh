#!/usr/bin/env bash

set -e

VERSION="$(tr -d '\n' < psscriptanalyzer.version)"
FILE="$VERSION.tar.gz"
RESOURCES_DIR=".resources/"

# Remove possible old source
rm -rf PSScriptAnalyzer/
mkdir -p "$RESOURCES_DIR"
if [ ! -f "$RESOURCES_DIR/$FILE" ]; then
	wget -O "$RESOURCES_DIR/$FILE" "https://github.com/PowerShell/PSScriptAnalyzer/archive/$FILE"
	                            
fi
tar -zxvf "$RESOURCES_DIR/$FILE"
mv "PSScriptAnalyzer-$VERSION" PSScriptAnalyzer

pwsh -c "Install-Module PSScriptAnalyzer -RequiredVersion $VERSION -Force -Confirm:\$false"
pwsh install.ps1
