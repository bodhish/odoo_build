#!/bin/bash

set -e

# Ensure required env vars are set
: "${THIRD_PARTY_ADDONS:?THIRD_PARTY_ADDONS environment variable must be set}"
: "${ODOO_TAG:?ODOO_TAG environment variable must be set}"

mkdir -p "${THIRD_PARTY_ADDONS}"

# Read and process each line from third-party-addons.txt
while IFS=' ' read -r repo_type repo_url || [[ -n "$repo_type" ]]; do
    # Skip empty lines and comments
    [[ -z "$repo_type" || "$repo_type" == \#* ]] && continue

    repo_name=$(basename -s .git "$repo_url")
    
    # Construct clone URL based on repo type
    case "$repo_type" in
        private)
            clone_url="https://${GITHUB_USER}:${GITHUB_ACCESS_TOKEN}@${repo_url#https://}"
            ;;
        enterprise)
            clone_url="https://${ENTERPRISE_USER}:${ENTERPRISE_ACCESS_TOKEN}@${repo_url#https://}"
            ;;
        public)
            clone_url="$repo_url"
            ;;
        *)
            echo "Unknown repo type: $repo_type, skipping..."
            continue
            ;;
    esac

    echo "Cloning ${repo_name} (tag: ${ODOO_TAG})..."
    git clone --depth 1 --branch "${ODOO_TAG}" --single-branch --no-tags "$clone_url" "/tmp/${repo_name}"

    # Copy all valid Odoo modules to THIRD_PARTY_ADDONS
    for module_dir in "/tmp/${repo_name}"/*/; do
        [[ ! -d "$module_dir" ]] && continue
        
        # Check if it's a valid Odoo module (has __manifest__.py or __openerp__.py)
        if [[ -f "${module_dir}__manifest__.py" || -f "${module_dir}__openerp__.py" ]]; then
            module_name=$(basename "$module_dir")
            echo "  Copying module: ${module_name}"
            cp -r "$module_dir" "${THIRD_PARTY_ADDONS}/${module_name}"
        fi
    done

    # Cleanup cloned repo
    rm -rf "/tmp/${repo_name}"

done < "third-party-addons.txt"

echo "Done! All modules copied to ${THIRD_PARTY_ADDONS}"