#!/bin/bash

# Setup Script Permissions for Nestle PoC
# This script sets proper permissions for all deployment scripts

set -e

print_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_info "Setting up script permissions for Nestle PoC..."

# Check if we're in the right directory
if [ ! -d "scripts" ]; then
    echo "Error: Please run this script from the project root directory"
    exit 1
fi

# Make all shell scripts executable
chmod +x scripts/*.sh

# List the scripts that were made executable
print_info "Made the following scripts executable:"
ls -la scripts/*.sh | awk '{print "  " $1 " " $NF}'

print_success "Script permissions setup completed!"

print_info "Available deployment scripts:"
echo "  Phase 1 (Infrastructure): ./scripts/deploy.sh"
echo "  Phase 2 (Add-ons):       ./scripts/deploy-phase2.sh"
echo "  Windows users:           scripts/deploy.bat or scripts/deploy-phase2.bat" 