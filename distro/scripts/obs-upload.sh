#!/bin/bash
# Unified OBS upload script for dms packages
# Handles Debian and OpenSUSE builds for both x86_64 and aarch64
# Usage: ./distro/scripts/obs-upload.sh [distro] <package-name> [commit-message]
#
# Examples:
#   ./distro/scripts/obs-upload.sh dms "Update to v0.6.2"
#   ./distro/scripts/obs-upload.sh debian dms
#   ./distro/scripts/obs-upload.sh opensuse dms-git

set -e

UPLOAD_DEBIAN=true
UPLOAD_OPENSUSE=true
PACKAGE=""
MESSAGE=""

for arg in "$@"; do
    case "$arg" in
        debian)
            UPLOAD_DEBIAN=true
            UPLOAD_OPENSUSE=false
            ;;
        opensuse)
            UPLOAD_DEBIAN=false
            UPLOAD_OPENSUSE=true
            ;;
        *)
            if [[ -z "$PACKAGE" ]]; then
                PACKAGE="$arg"
            elif [[ -z "$MESSAGE" ]]; then
                MESSAGE="$arg"
            fi
            ;;
    esac
done

OBS_BASE_PROJECT="home:AvengeMedia"
OBS_BASE="$HOME/.cache/osc-checkouts"
AVAILABLE_PACKAGES=(dms dms-git)

if [[ -z "$PACKAGE" ]]; then
    echo "Available packages:"
    echo ""
    echo "  1. dms         - Stable DMS"
    echo "  2. dms-git     - Nightly DMS"
    echo "  a. all"
    echo ""
    read -p "Select package (1-${#AVAILABLE_PACKAGES[@]}, a): " selection
    
    if [[ "$selection" == "a" ]] || [[ "$selection" == "all" ]]; then
        PACKAGE="all"
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#AVAILABLE_PACKAGES[@]} ]]; then
        PACKAGE="${AVAILABLE_PACKAGES[$((selection-1))]}"
    else
        echo "Error: Invalid selection"
        exit 1
    fi
    
fi

if [[ -z "$MESSAGE" ]]; then
    MESSAGE="Update packaging"
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -d "distro/debian" ]]; then
    echo "Error: Run this script from the repository root"
    exit 1
fi

# Handle "all" option
if [[ "$PACKAGE" == "all" ]]; then
    echo "==> Uploading all packages"
    DISTRO_ARG=""
    if [[ "$UPLOAD_DEBIAN" == true && "$UPLOAD_OPENSUSE" == false ]]; then
        DISTRO_ARG="debian"
    elif [[ "$UPLOAD_DEBIAN" == false && "$UPLOAD_OPENSUSE" == true ]]; then
        DISTRO_ARG="opensuse"
    fi
    echo ""
    FAILED=()
    for pkg in "${AVAILABLE_PACKAGES[@]}"; do
        if [[ -d "distro/debian/$pkg" ]]; then
            echo "=========================================="
            echo "Uploading $pkg..."
            echo "=========================================="
            if [[ -n "$DISTRO_ARG" ]]; then
                if bash "$0" "$DISTRO_ARG" "$pkg" "$MESSAGE"; then
                    echo "✅ $pkg uploaded successfully"
                else
                    echo "❌ $pkg failed to upload"
                    FAILED+=("$pkg")
                fi
            else
                if bash "$0" "$pkg" "$MESSAGE"; then
                    echo "✅ $pkg uploaded successfully"
                else
                    echo "❌ $pkg failed to upload"
                    FAILED+=("$pkg")
                fi
            fi
            echo ""
        else
            echo "⚠️  Skipping $pkg (not found in distro/debian/)"
        fi
    done
    
    if [[ ${#FAILED[@]} -eq 0 ]]; then
        echo "✅ All packages uploaded successfully!"
        exit 0
    else
        echo "❌ Some packages failed: ${FAILED[*]}"
        exit 1
    fi
fi

# Check if package exists
if [[ ! -d "distro/debian/$PACKAGE" ]]; then
    echo "Error: Package '$PACKAGE' not found in distro/debian/"
    exit 1
fi

case "$PACKAGE" in
    dms)
        PROJECT="dms"
        ;;
    dms-git)
        PROJECT="dms-git"
        ;;
    *)
        echo "Error: Unknown package '$PACKAGE'"
        exit 1
        ;;
esac

OBS_PROJECT="${OBS_BASE_PROJECT}:${PROJECT}"

echo "==> Target: $OBS_PROJECT / $PACKAGE"
if [[ "$UPLOAD_DEBIAN" == true && "$UPLOAD_OPENSUSE" == true ]]; then
    echo "==> Distributions: Debian + OpenSUSE"
elif [[ "$UPLOAD_DEBIAN" == true ]]; then
    echo "==> Distribution: Debian only"
elif [[ "$UPLOAD_OPENSUSE" == true ]]; then
    echo "==> Distribution: OpenSUSE only"
fi

mkdir -p "$OBS_BASE"

if [[ ! -d "$OBS_BASE/$OBS_PROJECT/$PACKAGE" ]]; then
    echo "Checking out $OBS_PROJECT/$PACKAGE..."
    cd "$OBS_BASE"
    osc co "$OBS_PROJECT/$PACKAGE"
    cd "$REPO_ROOT"
fi

WORK_DIR="$OBS_BASE/$OBS_PROJECT/$PACKAGE"

echo "==> Preparing $PACKAGE for OBS upload"

find "$WORK_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tar.xz" -o -name "*.tar.bz2" -o -name "*.tar" -o -name "*.spec" -o -name "_service" -o -name "*.dsc" \) -delete 2>/dev/null || true

if [[ -f "distro/debian/$PACKAGE/_service" ]]; then
    echo "  - Copying _service (for binary downloads)"
    cp "distro/debian/$PACKAGE/_service" "$WORK_DIR/"
fi

CHANGELOG_VERSION=""
if [[ -d "distro/debian/$PACKAGE/debian" ]]; then
    CHANGELOG_VERSION=$(grep -m1 "^$PACKAGE" "distro/debian/$PACKAGE/debian/changelog" 2>/dev/null | sed 's/.*(\([^)]*\)).*/\1/' || echo "")
    if [[ -n "$CHANGELOG_VERSION" ]] && [[ "$CHANGELOG_VERSION" == *"-"* ]]; then
        SOURCE_FORMAT_CHECK=$(cat "distro/debian/$PACKAGE/debian/source/format" 2>/dev/null || echo "3.0 (quilt)")
        if [[ "$SOURCE_FORMAT_CHECK" == *"native"* ]]; then
            CHANGELOG_VERSION=$(echo "$CHANGELOG_VERSION" | sed 's/-[0-9]*$//')
        fi
    fi
fi

if [[ "$UPLOAD_OPENSUSE" == true ]] && [[ -f "distro/opensuse/$PACKAGE.spec" ]]; then
    echo "  - Copying $PACKAGE.spec for OpenSUSE"
    cp "distro/opensuse/$PACKAGE.spec" "$WORK_DIR/"

    if [[ -f "$WORK_DIR/.osc/$PACKAGE.spec" ]]; then
        NEW_VERSION=$(grep "^Version:" "$WORK_DIR/$PACKAGE.spec" | awk '{print $2}' | head -1)
        NEW_RELEASE=$(grep "^Release:" "$WORK_DIR/$PACKAGE.spec" | sed 's/^Release:[[:space:]]*//' | sed 's/%{?dist}//' | head -1)
        OLD_VERSION=$(grep "^Version:" "$WORK_DIR/.osc/$PACKAGE.spec" | awk '{print $2}' | head -1)
        OLD_RELEASE=$(grep "^Release:" "$WORK_DIR/.osc/$PACKAGE.spec" | sed 's/^Release:[[:space:]]*//' | sed 's/%{?dist}//' | head -1)

        if [[ "$NEW_VERSION" == "$OLD_VERSION" ]]; then
            if [[ "$OLD_RELEASE" =~ ^([0-9]+) ]]; then
                BASE_RELEASE="${BASH_REMATCH[1]}"
                NEXT_RELEASE=$((BASE_RELEASE + 1))
                echo "  - Detected rebuild of same version $NEW_VERSION (release $OLD_RELEASE -> $NEXT_RELEASE)"
                sed -i "s/^Release:[[:space:]]*${NEW_RELEASE}%{?dist}/Release:        ${NEXT_RELEASE}%{?dist}/" "$WORK_DIR/$PACKAGE.spec"
            fi
        else
            echo "  - New version detected: $OLD_VERSION -> $NEW_VERSION (keeping release $NEW_RELEASE)"
        fi
    else
        echo "  - First upload to OBS (no previous spec found)"
    fi
elif [[ "$UPLOAD_OPENSUSE" == true ]]; then
    echo "  - Warning: OpenSUSE spec file not found, skipping OpenSUSE upload"
fi

if [[ "$UPLOAD_OPENSUSE" == true ]] && [[ "$UPLOAD_DEBIAN" == false ]] && [[ -f "distro/opensuse/$PACKAGE.spec" ]]; then
    echo "  - OpenSUSE-only upload: creating source tarball"

    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    if [[ -f "distro/debian/$PACKAGE/_service" ]] && grep -q "tar_scm" "distro/debian/$PACKAGE/_service"; then
        GIT_URL=$(grep -A 5 'name="tar_scm"' "distro/debian/$PACKAGE/_service" | grep "url" | sed 's/.*<param name="url">\(.*\)<\/param>.*/\1/')
        GIT_REVISION=$(grep -A 5 'name="tar_scm"' "distro/debian/$PACKAGE/_service" | grep "revision" | sed 's/.*<param name="revision">\(.*\)<\/param>.*/\1/')

        if [[ -n "$GIT_URL" ]]; then
            echo "    Cloning git source from: $GIT_URL (revision: ${GIT_REVISION:-master})"
            SOURCE_DIR="$TEMP_DIR/dms-git-source"
            if git clone --depth 1 --branch "${GIT_REVISION:-master}" "$GIT_URL" "$SOURCE_DIR" 2>/dev/null || \
               git clone --depth 1 "$GIT_URL" "$SOURCE_DIR" 2>/dev/null; then
                cd "$SOURCE_DIR"
                if [[ -n "$GIT_REVISION" ]]; then
                    git checkout "$GIT_REVISION" 2>/dev/null || true
                fi
                rm -rf .git
                SOURCE_DIR=$(pwd)
                cd "$REPO_ROOT"
            fi
        fi
    fi

    if [[ -n "$SOURCE_DIR" && -d "$SOURCE_DIR" ]]; then
        SOURCE0=$(grep "^Source0:" "distro/opensuse/$PACKAGE.spec" | awk '{print $2}' | head -1)

        if [[ -n "$SOURCE0" ]]; then
            OBS_TARBALL_DIR=$(mktemp -d -t obs-tarball-XXXXXX)
            cd "$OBS_TARBALL_DIR"

            case "$PACKAGE" in
                dms)
                    DMS_VERSION=$(grep "^Version:" "$REPO_ROOT/distro/opensuse/$PACKAGE.spec" | sed 's/^Version:[[:space:]]*//' | head -1)
                    EXPECTED_DIR="DankMaterialShell-${DMS_VERSION}"
                    ;;
                dms-git)
                    EXPECTED_DIR="dms-git-source"
                    ;;
                *)
                    EXPECTED_DIR=$(basename "$SOURCE_DIR")
                    ;;
            esac

            echo "    Creating $SOURCE0 (directory: $EXPECTED_DIR)"
            cp -r "$SOURCE_DIR" "$EXPECTED_DIR"
            tar -czf "$WORK_DIR/$SOURCE0" "$EXPECTED_DIR"
            rm -rf "$EXPECTED_DIR"
            echo "    Created $SOURCE0 ($(stat -c%s "$WORK_DIR/$SOURCE0" 2>/dev/null || echo 0) bytes)"

            cd "$REPO_ROOT"
            rm -rf "$OBS_TARBALL_DIR"
        fi
    else
        echo "  - Warning: Could not obtain source for OpenSUSE tarball"
    fi
fi

# Generate .dsc file and handle source format (for Debian only)
if [[ "$UPLOAD_DEBIAN" == true ]] && [[ -d "distro/debian/$PACKAGE/debian" ]]; then
    # Use CHANGELOG_VERSION already set above, or get it if not set
    if [[ -z "$CHANGELOG_VERSION" ]]; then
        CHANGELOG_VERSION=$(grep -m1 "^$PACKAGE" distro/debian/$PACKAGE/debian/changelog 2>/dev/null | sed 's/.*(\([^)]*\)).*/\1/' || echo "0.1.11")
    fi
    
    # Determine source format
    SOURCE_FORMAT=$(cat "distro/debian/$PACKAGE/debian/source/format" 2>/dev/null || echo "3.0 (quilt)")
    
    # For native format, remove any Debian revision (-N) from version
    # Native format cannot have revisions, so strip them if present
    if [[ "$SOURCE_FORMAT" == *"native"* ]] && [[ "$CHANGELOG_VERSION" == *"-"* ]]; then
        # Remove Debian revision (everything from - onwards)
        CHANGELOG_VERSION=$(echo "$CHANGELOG_VERSION" | sed 's/-[0-9]*$//')
        echo "  Warning: Removed Debian revision from version for native format: $CHANGELOG_VERSION"
    fi
    
    if [[ "$SOURCE_FORMAT" == *"native"* ]]; then
        echo "  - Native format detected: creating combined tarball"

        VERSION="$CHANGELOG_VERSION"
        TEMP_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_DIR" EXIT
        COMBINED_TARBALL="${PACKAGE}_${VERSION}.tar.gz"
        SOURCE_DIR=""
        
        if [[ -f "distro/debian/$PACKAGE/_service" ]]; then
            if grep -q "tar_scm" "distro/debian/$PACKAGE/_service"; then
                GIT_URL=$(grep -A 5 'name="tar_scm"' "distro/debian/$PACKAGE/_service" | grep "url" | sed 's/.*<param name="url">\(.*\)<\/param>.*/\1/')
                GIT_REVISION=$(grep -A 5 'name="tar_scm"' "distro/debian/$PACKAGE/_service" | grep "revision" | sed 's/.*<param name="revision">\(.*\)<\/param>.*/\1/')
                
                if [[ -n "$GIT_URL" ]]; then
                    echo "    Cloning git source from: $GIT_URL (revision: ${GIT_REVISION:-master})"
                    SOURCE_DIR="$TEMP_DIR/dms-git-source"
                    if git clone --depth 1 --branch "${GIT_REVISION:-master}" "$GIT_URL" "$SOURCE_DIR" 2>/dev/null || \
                       git clone --depth 1 "$GIT_URL" "$SOURCE_DIR" 2>/dev/null; then
                        cd "$SOURCE_DIR"
                        if [[ -n "$GIT_REVISION" ]]; then
                            git checkout "$GIT_REVISION" 2>/dev/null || true
                        fi
                        rm -rf .git
                        SOURCE_DIR=$(pwd)
                        cd "$REPO_ROOT"
                    else
                        echo "Error: Failed to clone git repository"
                        exit 1
                    fi
                fi
            elif grep -q "download_url" "distro/debian/$PACKAGE/_service" && [[ "$PACKAGE" != "dms-git" ]]; then
                ALL_PATHS=$(grep -A 5 '<service name="download_url">' "distro/debian/$PACKAGE/_service" | \
                    grep '<param name="path">' | \
                    sed 's/.*<param name="path">\(.*\)<\/param>.*/\1/')
                
                SOURCE_PATH=""
                for path in $ALL_PATHS; do
                    if echo "$path" | grep -qE "(source|archive|\.tar\.(gz|xz|bz2))" && \
                       ! echo "$path" | grep -qE "(distropkg|binary)"; then
                        SOURCE_PATH="$path"
                        break
                    fi
                done
                
                if [[ -z "$SOURCE_PATH" ]]; then
                    for path in $ALL_PATHS; do
                        if echo "$path" | grep -qE "\.tar\.(gz|xz|bz2)$"; then
                            SOURCE_PATH="$path"
                            break
                        fi
                    done
                fi
                
                if [[ -n "$SOURCE_PATH" ]]; then
                    SOURCE_BLOCK=$(awk -v target="$SOURCE_PATH" '
                        /<service name="download_url">/ { in_block=1; block="" }
                        in_block { block=block"\n"$0 }
                        /<\/service>/ { 
                            if (in_block && block ~ target) {
                                print block
                                exit
                            }
                            in_block=0
                        }
                    ' "distro/debian/$PACKAGE/_service")
                    
                    URL_PROTOCOL=$(echo "$SOURCE_BLOCK" | grep "protocol" | sed 's/.*<param name="protocol">\(.*\)<\/param>.*/\1/' | head -1)
                    URL_HOST=$(echo "$SOURCE_BLOCK" | grep "host" | sed 's/.*<param name="host">\(.*\)<\/param>.*/\1/' | head -1)
                    URL_PATH="$SOURCE_PATH"
                fi
                
                if [[ -n "$URL_PROTOCOL" && -n "$URL_HOST" && -n "$URL_PATH" ]]; then
                    SOURCE_URL="${URL_PROTOCOL}://${URL_HOST}${URL_PATH}"
                    echo "    Downloading source from: $SOURCE_URL"
                    
                    if wget -q -O "$TEMP_DIR/source-archive" "$SOURCE_URL" 2>/dev/null || \
                       curl -L -f -s -o "$TEMP_DIR/source-archive" "$SOURCE_URL" 2>/dev/null; then
                        cd "$TEMP_DIR"
                        if [[ "$SOURCE_URL" == *.tar.xz ]]; then
                            tar -xJf source-archive
                        elif [[ "$SOURCE_URL" == *.tar.gz ]] || [[ "$SOURCE_URL" == *.tgz ]]; then
                            tar -xzf source-archive
                        fi
                        SOURCE_DIR=$(find . -maxdepth 1 -type d -name "DankMaterialShell-*" | head -1)
                        if [[ -z "$SOURCE_DIR" ]]; then
                            SOURCE_DIR=$(find . -maxdepth 1 -type d ! -name "." | head -1)
                        fi
                        if [[ -z "$SOURCE_DIR" || ! -d "$SOURCE_DIR" ]]; then
                            echo "Error: Failed to extract source archive or find source directory"
                            echo "Contents of $TEMP_DIR:"
                            ls -la "$TEMP_DIR"
                            cd "$REPO_ROOT"
                            exit 1
                        fi
                        SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)
                        cd "$REPO_ROOT"
                    else
                        echo "Error: Failed to download source from $SOURCE_URL"
                        echo "Tried both wget and curl. Please check the URL and network connectivity."
                        exit 1
                    fi
                fi
            fi
        fi
        
        if [[ -z "$SOURCE_DIR" || ! -d "$SOURCE_DIR" ]]; then
            echo "Error: Could not determine or obtain source for $PACKAGE"
            echo "SOURCE_DIR: $SOURCE_DIR"
            if [[ -d "$TEMP_DIR" ]]; then
                echo "Contents of temp directory:"
                ls -la "$TEMP_DIR"
            fi
            exit 1
        fi
        
        echo "    Found source directory: $SOURCE_DIR"

        # Vendor Go dependencies for dms-git 
        if [[ "$PACKAGE" == "dms-git" ]] && [[ -d "$SOURCE_DIR/core" ]]; then
            echo "  - Vendoring Go dependencies for offline OBS build..."
            cd "$SOURCE_DIR/core"

            if ! command -v go &> /dev/null; then
                echo "ERROR: Go not found. Install Go to vendor dependencies."
                echo "  Install: sudo apt-get install golang-go (Debian/Ubuntu)"
                echo "      or: sudo dnf install golang (Fedora)"
                exit 1
            fi

            # Vendor dependencies
            go mod vendor
            if [ ! -d "vendor" ]; then
                echo "ERROR: Failed to vendor Go dependencies"
                exit 1
            fi

            VENDOR_SIZE=$(du -sh vendor | cut -f1)
            echo "    ✓ Go dependencies vendored ($VENDOR_SIZE)"
            cd "$REPO_ROOT"
        fi

        # Create OpenSUSE-compatible source tarballs BEFORE adding debian/ directory
        if [[ "$UPLOAD_OPENSUSE" == true ]] && [[ -f "distro/opensuse/$PACKAGE.spec" ]]; then
            echo "  - Creating OpenSUSE-compatible source tarballs"
            
            SOURCE0=$(grep "^Source0:" "distro/opensuse/$PACKAGE.spec" | awk '{print $2}' | head -1)
            if [[ -z "$SOURCE0" && "$PACKAGE" == "dms-git" ]]; then
                SOURCE0="dms-git-source.tar.gz"
            fi

            if [[ -n "$SOURCE0" ]]; then
                OBS_TARBALL_DIR=$(mktemp -d -t obs-tarball-XXXXXX)
                cd "$OBS_TARBALL_DIR"
                
                case "$PACKAGE" in
                    dms)
                        if [[ -n "$CHANGELOG_VERSION" ]]; then
                            DMS_VERSION="$CHANGELOG_VERSION"
                        else
                            DMS_VERSION=$(grep "^Version:" "$REPO_ROOT/distro/opensuse/$PACKAGE.spec" | sed 's/^Version:[[:space:]]*//' | head -1)
                        fi
                        EXPECTED_DIR="DankMaterialShell-${DMS_VERSION}"
                        echo "    Creating $SOURCE0 (directory: $EXPECTED_DIR)"
                        cp -r "$SOURCE_DIR" "$EXPECTED_DIR"
                        if [[ "$SOURCE0" == *.tar.xz ]]; then
                            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -cJf "$WORK_DIR/$SOURCE0" "$EXPECTED_DIR"
                        elif [[ "$SOURCE0" == *.tar.bz2 ]]; then
                            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -cjf "$WORK_DIR/$SOURCE0" "$EXPECTED_DIR"
                        else
                            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -czf "$WORK_DIR/$SOURCE0" "$EXPECTED_DIR"
                        fi
                        rm -rf "$EXPECTED_DIR"
                        echo "    Created $SOURCE0 ($(stat -c%s "$WORK_DIR/$SOURCE0" 2>/dev/null || echo 0) bytes)"
                        ;;
                    dms-git)
                        EXPECTED_DIR="dms-git-source"
                        echo "    Creating $SOURCE0 (directory: $EXPECTED_DIR)"
                        cp -r "$SOURCE_DIR" "$EXPECTED_DIR"
                        if [[ "$SOURCE0" == *.tar.xz ]]; then
                            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -cJf "$WORK_DIR/$SOURCE0" "$EXPECTED_DIR"
                        elif [[ "$SOURCE0" == *.tar.bz2 ]]; then
                            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -cjf "$WORK_DIR/$SOURCE0" "$EXPECTED_DIR"
                        else
                            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -czf "$WORK_DIR/$SOURCE0" "$EXPECTED_DIR"
                        fi
                        rm -rf "$EXPECTED_DIR"
                        echo "    Created $SOURCE0 ($(stat -c%s "$WORK_DIR/$SOURCE0" 2>/dev/null || echo 0) bytes)"
                        ;;
                    *)
                        DIR_NAME=$(basename "$SOURCE_DIR")
                        echo "    Creating $SOURCE0 (directory: $DIR_NAME)"
                        cp -r "$SOURCE_DIR" "$DIR_NAME"
                        if [[ "$SOURCE0" == *.tar.xz ]]; then
                            tar --sort=name --mtime='2000-01-01 00:00:00' -cJf "$WORK_DIR/$SOURCE0" "$DIR_NAME"
                        elif [[ "$SOURCE0" == *.tar.bz2 ]]; then
                            tar --sort=name --mtime='2000-01-01 00:00:00' -cjf "$WORK_DIR/$SOURCE0" "$DIR_NAME"
                        else
                            tar --sort=name --mtime='2000-01-01 00:00:00' -czf "$WORK_DIR/$SOURCE0" "$DIR_NAME"
                        fi
                        rm -rf "$DIR_NAME"
                        echo "    Created $SOURCE0 ($(stat -c%s "$WORK_DIR/$SOURCE0" 2>/dev/null || echo 0) bytes)"
                        ;;
                esac
                cd "$REPO_ROOT"
                rm -rf "$OBS_TARBALL_DIR"
                echo "  - OpenSUSE source tarballs created"
            fi
            
            cp "distro/opensuse/$PACKAGE.spec" "$WORK_DIR/"
        fi
        
        if [[ "$UPLOAD_DEBIAN" == true ]]; then
            echo "    Copying debian/ directory into source"
            cp -r "distro/debian/$PACKAGE/debian" "$SOURCE_DIR/"
            
            # For dms, rename directory to match what debian/rules expects
            # debian/rules uses UPSTREAM_VERSION which is the full version from changelog
            if [[ "$PACKAGE" == "dms" ]]; then
                CHANGELOG_IN_SOURCE="$SOURCE_DIR/debian/changelog"
                if [[ -f "$CHANGELOG_IN_SOURCE" ]]; then
                    ACTUAL_VERSION=$(grep -m1 "^$PACKAGE" "$CHANGELOG_IN_SOURCE" 2>/dev/null | sed 's/.*(\([^)]*\)).*/\1/' || echo "$VERSION")
                    CURRENT_DIR=$(basename "$SOURCE_DIR")
                    EXPECTED_DIR="DankMaterialShell-${ACTUAL_VERSION}"
                    if [[ "$CURRENT_DIR" != "$EXPECTED_DIR" ]]; then
                        echo "    Renaming directory from $CURRENT_DIR to $EXPECTED_DIR to match debian/rules"
                        cd "$(dirname "$SOURCE_DIR")"
                        mv "$CURRENT_DIR" "$EXPECTED_DIR"
                        SOURCE_DIR="$(pwd)/$EXPECTED_DIR"
                        cd "$REPO_ROOT"
                    fi
                fi
            fi
            
            rm -f "$WORK_DIR/$COMBINED_TARBALL"
            
            echo "    Creating combined tarball: $COMBINED_TARBALL"
            cd "$(dirname "$SOURCE_DIR")"
            TARBALL_BASE=$(basename "$SOURCE_DIR")
            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -czf "$WORK_DIR/$COMBINED_TARBALL" "$TARBALL_BASE"
            cd "$REPO_ROOT"
            
            if [[ "$PACKAGE" == "dms" ]]; then
                TARBALL_DIR=$(tar -tzf "$WORK_DIR/$COMBINED_TARBALL" 2>/dev/null | head -1 | cut -d'/' -f1)
                EXPECTED_TARBALL_DIR="DankMaterialShell-${VERSION}"
                if [[ "$TARBALL_DIR" != "$EXPECTED_TARBALL_DIR" ]]; then
                    echo "    Warning: Tarball directory name mismatch: $TARBALL_DIR != $EXPECTED_TARBALL_DIR"
                    echo "    This may cause build failures. Recreating tarball..."
                    cd "$(dirname "$SOURCE_DIR")"
                    rm -f "$WORK_DIR/$COMBINED_TARBALL"
                    tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -czf "$WORK_DIR/$COMBINED_TARBALL" "$TARBALL_BASE"
                    cd "$REPO_ROOT"
                fi
            fi
            
            TARBALL_SIZE=$(stat -c%s "$WORK_DIR/$COMBINED_TARBALL" 2>/dev/null || stat -f%z "$WORK_DIR/$COMBINED_TARBALL" 2>/dev/null)
            TARBALL_MD5=$(md5sum "$WORK_DIR/$COMBINED_TARBALL" | cut -d' ' -f1)
            
            # Extract Build-Depends from debian/control using awk for proper multi-line parsing
            if [[ -f "$REPO_ROOT/distro/debian/$PACKAGE/debian/control" ]]; then
                BUILD_DEPS=$(awk '
                    /^Build-Depends:/ {
                        in_build_deps=1;
                        sub(/^Build-Depends:[[:space:]]*/, "");
                        printf "%s", $0;
                        next;
                    }
                    in_build_deps && /^[[:space:]]/ {
                        sub(/^[[:space:]]+/, " ");
                        printf "%s", $0;
                        next;
                    }
                    in_build_deps { exit; }
                ' "$REPO_ROOT/distro/debian/$PACKAGE/debian/control" | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')

                # If extraction failed or is empty, use default fallback
                if [[ -z "$BUILD_DEPS" ]]; then
                    BUILD_DEPS="debhelper-compat (= 13)"
                fi
            else
                BUILD_DEPS="debhelper-compat (= 13)"
            fi
            
            cat > "$WORK_DIR/$PACKAGE.dsc" << EOF
Format: 3.0 (native)
Source: $PACKAGE
Binary: $PACKAGE
Architecture: any
Version: $VERSION
Maintainer: Avenge Media <AvengeMedia.US@gmail.com>
Build-Depends: $BUILD_DEPS
Files:
 $TARBALL_MD5 $TARBALL_SIZE $COMBINED_TARBALL
EOF
            
            echo "  - Generated $PACKAGE.dsc for native format"
        fi
    else
        if [[ "$UPLOAD_DEBIAN" == true ]]; then
            if [[ "$CHANGELOG_VERSION" == *"-"* ]]; then
                VERSION="$CHANGELOG_VERSION"
            else
                VERSION="${CHANGELOG_VERSION}-1"
            fi
            
            echo "  - Quilt format detected: creating debian.tar.gz"
            tar -czf "$WORK_DIR/debian.tar.gz" -C "distro/debian/$PACKAGE" debian/
            
            echo "  - Generating $PACKAGE.dsc for quilt format"
            cat > "$WORK_DIR/$PACKAGE.dsc" << EOF
Format: 3.0 (quilt)
Source: $PACKAGE
Binary: $PACKAGE
Architecture: any
Version: $VERSION
Maintainer: Avenge Media <AvengeMedia.US@gmail.com>
Build-Depends: debhelper-compat (= 13), wget, gzip
DEBTRANSFORM-TAR: debian.tar.gz
Files:
 00000000000000000000000000000000 1 debian.tar.gz
EOF
        fi
    fi
fi

cd "$WORK_DIR"

echo "==> Updating working copy"
if ! osc up; then
    echo "Error: Failed to update working copy"
    exit 1
fi

# Only auto-increment on manual runs (REBUILD_RELEASE set or not in CI), not automated workflows
OLD_DSC_FILE=""
if [[ -f "$WORK_DIR/$PACKAGE.dsc" ]]; then
    OLD_DSC_FILE="$WORK_DIR/$PACKAGE.dsc"
elif [[ -f "$WORK_DIR/.osc/sources/$PACKAGE.dsc" ]]; then
    OLD_DSC_FILE="$WORK_DIR/.osc/sources/$PACKAGE.dsc"
fi

if [[ "$UPLOAD_DEBIAN" == true ]] && [[ "$SOURCE_FORMAT" == *"native"* ]] && [[ -n "$OLD_DSC_FILE" ]]; then
    OLD_DSC_VERSION=$(grep "^Version:" "$OLD_DSC_FILE" 2>/dev/null | awk '{print $2}' | head -1)
    
    IS_MANUAL=false
    if [[ -n "${REBUILD_RELEASE:-}" ]]; then
        IS_MANUAL=true
        echo "==> Manual rebuild detected (REBUILD_RELEASE=$REBUILD_RELEASE)"
    elif [[ -n "${FORCE_REBUILD:-}" ]] && [[ "${FORCE_REBUILD}" == "true" ]]; then
        IS_MANUAL=true
        echo "==> Manual workflow trigger detected (FORCE_REBUILD=true)"
    elif [[ -z "${GITHUB_ACTIONS:-}" ]] && [[ -z "${CI:-}" ]]; then
        IS_MANUAL=true
        echo "==> Local/manual run detected (not in CI)"
    fi
    
    if [[ -n "$OLD_DSC_VERSION" ]] && [[ "$OLD_DSC_VERSION" == "$CHANGELOG_VERSION" ]] && [[ "$IS_MANUAL" == true ]]; then
        echo "==> Detected rebuild of same version $CHANGELOG_VERSION, incrementing version"
        
        if [[ "$CHANGELOG_VERSION" =~ ^([0-9.]+)\+git$ ]]; then
            BASE_VERSION="${BASH_REMATCH[1]}"
            NEW_VERSION="${BASE_VERSION}+git1"
            echo "  Incrementing git number: $CHANGELOG_VERSION -> $NEW_VERSION"
        elif [[ "$CHANGELOG_VERSION" =~ ^([0-9.]+)\+git([0-9]+)$ ]]; then
            BASE_VERSION="${BASH_REMATCH[1]}"
            GIT_NUM="${BASH_REMATCH[2]}"
            NEW_GIT_NUM=$((GIT_NUM + 1))
            NEW_VERSION="${BASE_VERSION}+git${NEW_GIT_NUM}"
            echo "  Incrementing git number: $CHANGELOG_VERSION -> $NEW_VERSION"
        elif [[ "$CHANGELOG_VERSION" =~ ^([0-9.]+)ppa([0-9]+)$ ]]; then
            BASE_VERSION="${BASH_REMATCH[1]}"
            PPA_NUM="${BASH_REMATCH[2]}"
            NEW_PPA_NUM=$((PPA_NUM + 1))
            NEW_VERSION="${BASE_VERSION}ppa${NEW_PPA_NUM}"
            echo "  Incrementing PPA number: $CHANGELOG_VERSION -> $NEW_VERSION"
        elif [[ "$CHANGELOG_VERSION" =~ ^([0-9.]+)\+git([0-9]+)(\.[a-f0-9]+)?(ppa([0-9]+))?$ ]]; then
            BASE_VERSION="${BASH_REMATCH[1]}"
            GIT_NUM="${BASH_REMATCH[2]}"
            GIT_HASH="${BASH_REMATCH[3]}"
            PPA_NUM="${BASH_REMATCH[5]}"
            if [[ -n "$PPA_NUM" ]]; then
                NEW_PPA_NUM=$((PPA_NUM + 1))
                NEW_VERSION="${BASE_VERSION}+git${GIT_NUM}${GIT_HASH}ppa${NEW_PPA_NUM}"
                echo "  Incrementing PPA number: $CHANGELOG_VERSION -> $NEW_VERSION"
            else
                NEW_VERSION="${BASE_VERSION}+git${GIT_NUM}${GIT_HASH}ppa1"
                echo "  Adding PPA number: $CHANGELOG_VERSION -> $NEW_VERSION"
            fi
        elif [[ "$CHANGELOG_VERSION" =~ ^([0-9.]+)(-([0-9]+))?$ ]]; then
            BASE_VERSION="${BASH_REMATCH[1]}"
            NEW_VERSION="${BASE_VERSION}ppa1"
            echo "  Warning: Native format cannot have Debian revision, converting to PPA format: $CHANGELOG_VERSION -> $NEW_VERSION"
        else
            NEW_VERSION="${CHANGELOG_VERSION}ppa1"
            echo "  Warning: Could not parse version format, appending ppa1: $CHANGELOG_VERSION -> $NEW_VERSION"
        fi
        
        if [[ -z "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR" ]] || [[ ! -d "$SOURCE_DIR/debian" ]]; then
            echo "  Error: Source directory with debian/ not found for version increment"
            exit 1
        fi
        
        SOURCE_CHANGELOG="$SOURCE_DIR/debian/changelog"
        if [[ ! -f "$SOURCE_CHANGELOG" ]]; then
            echo "  Error: Changelog not found in source directory: $SOURCE_CHANGELOG"
            exit 1
        fi
        
        REPO_CHANGELOG="$REPO_ROOT/distro/debian/$PACKAGE/debian/changelog"
        TEMP_CHANGELOG=$(mktemp)
        {
            echo "$PACKAGE ($NEW_VERSION) unstable; urgency=medium"
            echo ""
            echo "  * Rebuild to fix repository metadata issues"
            echo ""
            echo " -- Avenge Media <AvengeMedia.US@gmail.com>  $(date -R)"
            echo ""
            if [[ -f "$REPO_CHANGELOG" ]]; then
                OLD_ENTRY_START=$(grep -n "^$PACKAGE (" "$REPO_CHANGELOG" | sed -n '2p' | cut -d: -f1)
                if [[ -n "$OLD_ENTRY_START" ]]; then
                    tail -n +$OLD_ENTRY_START "$REPO_CHANGELOG"
                fi
            fi
        } > "$TEMP_CHANGELOG"
        cp "$TEMP_CHANGELOG" "$SOURCE_CHANGELOG"
        rm -f "$TEMP_CHANGELOG"
        
        CHANGELOG_VERSION="$NEW_VERSION"
        VERSION="$NEW_VERSION"
        COMBINED_TARBALL="${PACKAGE}_${VERSION}.tar.gz"
        
        for old_tarball in "${PACKAGE}"_*.tar.gz; do
            if [[ -f "$old_tarball" ]] && [[ "$old_tarball" != "${PACKAGE}_${NEW_VERSION}.tar.gz" ]]; then
                echo "  Removing old tarball from OBS: $old_tarball"
                osc rm -f "$old_tarball" 2>/dev/null || rm -f "$old_tarball"
            fi
        done
        
        if [[ "$PACKAGE" == "dms" ]] && [[ -f "$WORK_DIR/dms-source.tar.gz" ]]; then
            echo "  Recreating dms-source.tar.gz with new directory name for incremented version"
            EXPECTED_SOURCE_DIR="DankMaterialShell-${NEW_VERSION}"
            TEMP_SOURCE_DIR=$(mktemp -d)
            cd "$TEMP_SOURCE_DIR"
            tar -xzf "$WORK_DIR/dms-source.tar.gz" 2>/dev/null || tar -xJf "$WORK_DIR/dms-source.tar.gz" 2>/dev/null || tar -xjf "$WORK_DIR/dms-source.tar.gz" 2>/dev/null
            EXTRACTED=$(find . -maxdepth 1 -type d -name "DankMaterialShell-*" | head -1)
            if [[ -n "$EXTRACTED" ]] && [[ "$EXTRACTED" != "./$EXPECTED_SOURCE_DIR" ]]; then
                echo "    Renaming $EXTRACTED to $EXPECTED_SOURCE_DIR"
                mv "$EXTRACTED" "$EXPECTED_SOURCE_DIR"
                rm -f "$WORK_DIR/dms-source.tar.gz"
                tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -czf "$WORK_DIR/dms-source.tar.gz" "$EXPECTED_SOURCE_DIR"
                ROOT_DIR=$(tar -tf "$WORK_DIR/dms-source.tar.gz" | head -1 | cut -d/ -f1)
                if [[ "$ROOT_DIR" != "$EXPECTED_SOURCE_DIR" ]]; then
                    echo "    Error: Recreated tarball has wrong root directory: $ROOT_DIR (expected $EXPECTED_SOURCE_DIR)"
                    exit 1
                fi
            fi
            cd "$REPO_ROOT"
            rm -rf "$TEMP_SOURCE_DIR"
        fi
        
        echo "  Recreating tarball with new version: $COMBINED_TARBALL"
        if [[ -n "$SOURCE_DIR" ]] && [[ -d "$SOURCE_DIR" ]] && [[ -d "$SOURCE_DIR/debian" ]]; then
            if [[ "$PACKAGE" == "dms" ]]; then
                cd "$(dirname "$SOURCE_DIR")"
                CURRENT_DIR=$(basename "$SOURCE_DIR")
                EXPECTED_DIR="DankMaterialShell-${NEW_VERSION}"
                if [[ "$CURRENT_DIR" != "$EXPECTED_DIR" ]]; then
                    echo "  Renaming directory from $CURRENT_DIR to $EXPECTED_DIR to match debian/rules"
                    if [[ -d "$CURRENT_DIR" ]]; then
                        mv "$CURRENT_DIR" "$EXPECTED_DIR"
                        SOURCE_DIR="$(pwd)/$EXPECTED_DIR"
                    else
                        echo "  Warning: Source directory $CURRENT_DIR not found, extracting from existing tarball"
                        OLD_TARBALL=$(ls "${PACKAGE}"_*.tar.gz 2>/dev/null | head -1)
                        if [[ -f "$OLD_TARBALL" ]]; then
                            EXTRACT_DIR=$(mktemp -d)
                            cd "$EXTRACT_DIR"
                            tar -xzf "$WORK_DIR/$OLD_TARBALL"
                            EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "DankMaterialShell-*" | head -1)
                            if [[ -n "$EXTRACTED_DIR" ]] && [[ "$EXTRACTED_DIR" != "./$EXPECTED_DIR" ]]; then
                                mv "$EXTRACTED_DIR" "$EXPECTED_DIR"
                                if [[ -f "$EXPECTED_DIR/debian/changelog" ]]; then
                                    ACTUAL_VER=$(grep -m1 "^$PACKAGE" "$EXPECTED_DIR/debian/changelog" 2>/dev/null | sed 's/.*(\([^)]*\)).*/\1/')
                                    if [[ "$ACTUAL_VER" != "$NEW_VERSION" ]]; then
                                        echo "  Updating changelog version in extracted directory"
                                        REPO_CHANGELOG="$REPO_ROOT/distro/debian/$PACKAGE/debian/changelog"
                                        TEMP_CHANGELOG=$(mktemp)
                                        {
                                            echo "$PACKAGE ($NEW_VERSION) unstable; urgency=medium"
                                            echo ""
                                            echo "  * Rebuild to fix repository metadata issues"
                                            echo ""
                                            echo " -- Avenge Media <AvengeMedia.US@gmail.com>  $(date -R)"
                                            echo ""
                                            if [[ -f "$REPO_CHANGELOG" ]]; then
                                                OLD_ENTRY_START=$(grep -n "^$PACKAGE (" "$REPO_CHANGELOG" | sed -n '2p' | cut -d: -f1)
                                                if [[ -n "$OLD_ENTRY_START" ]]; then
                                                    tail -n +$OLD_ENTRY_START "$REPO_CHANGELOG"
                                                fi
                                            fi
                                        } > "$TEMP_CHANGELOG"
                                        cp "$TEMP_CHANGELOG" "$EXPECTED_DIR/debian/changelog"
                                        rm -f "$TEMP_CHANGELOG"
                                    fi
                                fi
                                SOURCE_DIR="$(pwd)/$EXPECTED_DIR"
                                cd "$REPO_ROOT"
                            else
                                echo "  Error: Could not extract or find source directory"
                                rm -rf "$EXTRACT_DIR"
                                exit 1
                            fi
                        else
                            echo "  Error: No existing tarball found to extract"
                            exit 1
                        fi
                    fi
                fi
            fi
            cd "$(dirname "$SOURCE_DIR")"
            TARBALL_BASE=$(basename "$SOURCE_DIR")
            tar --sort=name --mtime='2000-01-01 00:00:00' --owner=0 --group=0 -czf "$WORK_DIR/$COMBINED_TARBALL" "$TARBALL_BASE"
            cd "$WORK_DIR"
            
            TARBALL_SIZE=$(stat -c%s "$WORK_DIR/$COMBINED_TARBALL" 2>/dev/null || stat -f%z "$WORK_DIR/$COMBINED_TARBALL" 2>/dev/null)
            TARBALL_MD5=$(md5sum "$WORK_DIR/$COMBINED_TARBALL" | cut -d' ' -f1)
            
            # Extract Build-Depends from debian/control using awk for proper multi-line parsing
            if [[ -f "$REPO_ROOT/distro/debian/$PACKAGE/debian/control" ]]; then
                BUILD_DEPS=$(awk '
                    /^Build-Depends:/ {
                        in_build_deps=1;
                        sub(/^Build-Depends:[[:space:]]*/, "");
                        printf "%s", $0;
                        next;
                    }
                    in_build_deps && /^[[:space:]]/ {
                        sub(/^[[:space:]]+/, " ");
                        printf "%s", $0;
                        next;
                    }
                    in_build_deps { exit; }
                ' "$REPO_ROOT/distro/debian/$PACKAGE/debian/control" | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')

                # If extraction failed or is empty, use default fallback
                if [[ -z "$BUILD_DEPS" ]]; then
                    BUILD_DEPS="debhelper-compat (= 13)"
                fi
            else
                BUILD_DEPS="debhelper-compat (= 13)"
            fi
            
            cat > "$WORK_DIR/$PACKAGE.dsc" << EOF
Format: 3.0 (native)
Source: $PACKAGE
Binary: $PACKAGE
Architecture: any
Version: $VERSION
Maintainer: Avenge Media <AvengeMedia.US@gmail.com>
Build-Depends: $BUILD_DEPS
Files:
 $TARBALL_MD5 $TARBALL_SIZE $COMBINED_TARBALL
EOF
            echo "  - Updated changelog and recreated tarball with version $NEW_VERSION"
        else
            echo "  Error: Source directory not found, cannot recreate tarball"
            exit 1
        fi
    fi
fi

find . -maxdepth 1 -type f \( -name "*.dsc" -o -name "*.spec" \) -exec grep -l "^<<<<<<< " {} \; 2>/dev/null | while read -r conflicted_file; do
    echo "  Removing conflicted text file: $conflicted_file"
    rm -f "$conflicted_file"
done

echo "==> Staging changes"
echo "Files to upload:"
if [[ "$UPLOAD_DEBIAN" == true ]] && [[ "$UPLOAD_OPENSUSE" == true ]]; then
    ls -lh *.tar.gz *.tar.xz *.tar *.spec *.dsc _service 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
elif [[ "$UPLOAD_DEBIAN" == true ]]; then
    ls -lh *.tar.gz *.dsc _service 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
elif [[ "$UPLOAD_OPENSUSE" == true ]]; then
    ls -lh *.tar.gz *.tar.xz *.tar *.spec _service 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
fi
echo ""

osc addremove 2>&1 | grep -v "Git SCM package" || true

SOURCE_TARBALL="${PACKAGE}-source.tar.gz"
if [[ -f "$SOURCE_TARBALL" ]]; then
    echo "==> Ensuring $SOURCE_TARBALL is tracked by OBS"
    osc add "$SOURCE_TARBALL" 2>&1 | grep -v "already added\|already tracked\|Git SCM package" || true
elif [[ -f "$WORK_DIR/$SOURCE_TARBALL" ]]; then
    echo "==> Copying $SOURCE_TARBALL from WORK_DIR and adding to OBS"
    cp "$WORK_DIR/$SOURCE_TARBALL" "$SOURCE_TARBALL"
    osc add "$SOURCE_TARBALL" 2>&1 | grep -v "already added\|already tracked\|Git SCM package" || true
fi
ADDREMOVE_EXIT=${PIPESTATUS[0]}
if [[ $ADDREMOVE_EXIT -ne 0 ]] && [[ $ADDREMOVE_EXIT -ne 1 ]]; then
    echo "Warning: osc addremove returned exit code $ADDREMOVE_EXIT"
fi

if osc status | grep -q '^C'; then
    echo "==> Resolving conflicts"
    osc status | grep '^C' | awk '{print $2}' | xargs -r osc resolved
fi

if ! osc status 2>/dev/null | grep -qE '^[MAD]|^[?]'; then
    echo "==> No changes to commit (package already up to date)"
else
    echo "==> Committing to OBS"
    set +e
    osc commit -m "$MESSAGE" 2>&1 | grep -v "Git SCM package" | grep -v "apiurl\|project\|_ObsPrj\|_manifest\|git-obs"
    COMMIT_EXIT=${PIPESTATUS[0]}
    set -e
    if [[ $COMMIT_EXIT -ne 0 ]]; then
        echo "Error: Upload failed with exit code $COMMIT_EXIT"
        exit 1
    fi
fi

osc results

echo ""
echo "✅ Upload complete!"
cd "$WORK_DIR"
osc results 2>&1 | head -10
cd "$REPO_ROOT"
echo ""
echo "Check build status with:"
echo "  ./distro/scripts/obs-status.sh $PACKAGE"
