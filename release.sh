#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Release helper for optwifi
# Bumps version numbers and resets release counter

set -e

show_usage() {
	cat <<EOF
Usage: ./release.sh <command>

Commands:
  major         Bump major version (x.0.0)
  minor         Bump minor version (0.x.0)
  patch         Bump patch version (0.0.x)
  release       Increment release number only
  show          Show current version

Examples:
  ./release.sh patch     # 0.9.0 → 0.9.1, reset release to 1
  ./release.sh minor     # 0.9.1 → 0.10.0, reset release to 1
  ./release.sh major     # 0.10.0 → 1.0.0, reset release to 1
  ./release.sh release   # Keep version, increment release (1 → 2)
  ./release.sh show      # Display current version

After bumping version:
  1. Review changes: git diff VERSION
  2. Build package: ./build-package.sh
  3. Test the package
  4. Commit: git add VERSION && git commit -m "Release vX.Y.Z"
  5. Tag: git tag -a vX.Y.Z -m "Release version X.Y.Z"
EOF
}

# Source current version
if [ ! -f VERSION ]; then
	echo "ERROR: VERSION file not found"
	exit 1
fi
. ./VERSION

# Parse version components
MAJOR=$(echo "$PKG_VERSION" | cut -d. -f1)
MINOR=$(echo "$PKG_VERSION" | cut -d. -f2)
PATCH=$(echo "$PKG_VERSION" | cut -d. -f3)

case "$1" in
	major)
		MAJOR=$((MAJOR + 1))
		MINOR=0
		PATCH=0
		PKG_RELEASE=1
		NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
		echo "Bumping major version: ${PKG_VERSION} → ${NEW_VERSION}"
		;;
	minor)
		MINOR=$((MINOR + 1))
		PATCH=0
		PKG_RELEASE=1
		NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
		echo "Bumping minor version: ${PKG_VERSION} → ${NEW_VERSION}"
		;;
	patch)
		PATCH=$((PATCH + 1))
		PKG_RELEASE=1
		NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
		echo "Bumping patch version: ${PKG_VERSION} → ${NEW_VERSION}"
		;;
	release)
		PKG_RELEASE=$((PKG_RELEASE + 1))
		NEW_VERSION="${PKG_VERSION}"
		echo "Incrementing release: ${PKG_VERSION}-$((PKG_RELEASE - 1)) → ${PKG_VERSION}-${PKG_RELEASE}"
		;;
	show)
		echo "Current version: ${PKG_VERSION}-${PKG_RELEASE}"
		exit 0
		;;
	help|--help|-h|"")
		show_usage
		exit 0
		;;
	*)
		echo "ERROR: Unknown command '$1'"
		echo ""
		show_usage
		exit 1
		;;
esac

# Update VERSION file
cat > VERSION <<EOF
# optwifi version information
# This file is sourced by build-package.sh and release.sh
PKG_VERSION="${NEW_VERSION}"
PKG_RELEASE="${PKG_RELEASE}"
EOF

echo "Updated VERSION file:"
echo "  PKG_VERSION=${NEW_VERSION}"
echo "  PKG_RELEASE=${PKG_RELEASE}"
echo ""
echo "Next steps:"
echo "  1. Review: git diff VERSION"
echo "  2. Build: ./build-package.sh"
echo "  3. Test the package"
echo "  4. Commit: git add VERSION && git commit -m 'Release v${NEW_VERSION}'"
if [ "$1" != "release" ]; then
	echo "  5. Tag: git tag -a v${NEW_VERSION} -m 'Release version ${NEW_VERSION}'"
fi