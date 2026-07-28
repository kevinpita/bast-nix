#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="ellipse-software/bast"
readonly PACKAGE_FILE="package.nix"
readonly FAKE_HASH="lib.fakeHash"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

flake_ref() {
    echo "path:$(pwd -P)#bast"
}

flake_path() {
    echo "path:$(pwd -P)"
}

get_current_version() {
    sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$PACKAGE_FILE" | head -1
}

get_latest_version() {
    local tag
    tag=$(gh api "repos/$GITHUB_REPO/releases/latest" --jq '.tag_name' 2>/dev/null || echo "")
    if [ -z "$tag" ]; then
        log_error "Failed to fetch latest version from GitHub"
        exit 1
    fi
    echo "${tag#v}"
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "$PACKAGE_FILE" ]; then
        log_error "flake.nix or $PACKAGE_FILE not found. Run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v gh >/dev/null 2>&1 || { log_error "gh is required but not installed."; exit 1; }
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
    command -v perl >/dev/null 2>&1 || { log_error "perl is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION  Update to a specific version"
    echo "  --check            Only check for updates"
    echo "  --help             Show this help message"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                if [[ $# -lt 2 ]]; then
                    log_error "--version requires a value"
                    print_usage
                    exit 1
                fi
                target_version="$2"
                shift 2
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

ensure_valid_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version: $version (expected MAJOR.MINOR.PATCH)"
        exit 1
    fi
}

update_version() {
    local version="$1"
    VERSION="$version" perl -0pi -e 's/version = "[^"]+";/version = "$ENV{VERSION}";/' "$PACKAGE_FILE"
}

set_src_hash() {
    local hash="$1"
    perl -0pi -e "s|(src = fetchFromGitHub \\{.*?hash = )[^;]+;|\${1}\"$hash\";|s" "$PACKAGE_FILE"
}

set_src_fake_hash() {
    perl -0pi -e "s|(src = fetchFromGitHub \\{.*?hash = )[^;]+;|\${1}$FAKE_HASH;|s" "$PACKAGE_FILE"
}

set_vendor_hash() {
    local hash="$1"
    perl -0pi -e "s|vendorHash = [^;]+;|vendorHash = \"$hash\";|" "$PACKAGE_FILE"
}

set_vendor_fake_hash() {
    perl -0pi -e "s|vendorHash = [^;]+;|vendorHash = $FAKE_HASH;|" "$PACKAGE_FILE"
}

extract_got_hash() {
    local log_file="$1"
    sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+\/=]*\).*/\1/p' "$log_file" | tail -1
}

expect_hash_mismatch() {
    local label="$1"
    local log_file
    log_file=$(mktemp)

    set +e
    nix build "$(flake_ref)" --no-link --print-build-logs >"$log_file" 2>&1
    local status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        log_error "Expected a hash mismatch while updating $label, but the build succeeded"
        cat "$log_file"
        exit 1
    fi

    local hash
    hash=$(extract_got_hash "$log_file")
    if [ -z "$hash" ]; then
        log_error "Failed to extract replacement hash for $label"
        cat "$log_file"
        exit 1
    fi

    rm -f "$log_file"
    echo "$hash"
}

refresh_hashes() {
    log_info "Refreshing source hash"
    set_src_fake_hash
    set_src_hash "$(expect_hash_mismatch "source")"

    log_info "Refreshing Go dependency hash"
    set_vendor_fake_hash
    set_vendor_hash "$(expect_hash_mismatch "Go dependencies")"
}

verify_update() {
    log_info "Building Bast"
    nix build "$(flake_ref)" --print-build-logs
}

update_flake_lock() {
    log_info "Updating flake.lock"
    nix flake update --flake "$(flake_path)"
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat "$PACKAGE_FILE" flake.lock 2>/dev/null || true
}

update_to_version() {
    local current_version="$1"
    local new_version="$2"

    cp "$PACKAGE_FILE" "$PACKAGE_FILE.bak"

    log_info "Updating Bast from $current_version to $new_version"
    update_version "$new_version"
    update_flake_lock
    refresh_hashes
    verify_update
    rm -f "$PACKAGE_FILE.bak"
    show_changes
}

main() {
    ensure_in_repository_root
    ensure_required_tools_installed

    local target_version=""
    local check_only=false
    parse_arguments "$@"

    local current_version
    current_version=$(get_current_version)
    ensure_valid_version "$current_version"

    local latest_version
    if [ -n "$target_version" ]; then
        latest_version="$target_version"
    else
        latest_version=$(get_latest_version)
    fi
    ensure_valid_version "$latest_version"

    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version -> $latest_version"
        exit 1
    fi

    update_to_version "$current_version" "$latest_version"
}

main "$@"
