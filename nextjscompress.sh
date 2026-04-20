#!/usr/bin/env bash
# =============================================================================
# pack-nextjs.sh
# Zips a Next.js project for upload/analysis, excluding:
#   - node_modules and other package directories
#   - Build output & cache directories (.next, .turbo, out, dist, build)
#   - Binary/executable files
#   - Configuration files (env, editor, CI, tooling configs)
#   - Version control metadata (.git)
#   - Log and lock files
#
# Usage:
#   ./pack-nextjs.sh [project-dir] [output-zip]
#
# Examples:
#   ./pack-nextjs.sh                          # zips current directory → nextjs-project.zip
#   ./pack-nextjs.sh ./my-app                 # zips ./my-app → nextjs-project.zip
#   ./pack-nextjs.sh ./my-app my-archive.zip  # zips ./my-app → my-archive.zip
# =============================================================================

set -euo pipefail

# ── Arguments ────────────────────────────────────────────────────────────────
PROJECT_DIR="${1:-.}"
OUTPUT_ZIP="${2:-nextjs-project.zip}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
SCRIPT_DIR="$(pwd)"

# Ensure output path is absolute
if [[ "$OUTPUT_ZIP" != /* ]]; then
  OUTPUT_ZIP="$SCRIPT_DIR/$OUTPUT_ZIP"
fi

echo "📦  Packing Next.js project..."
echo "    Source : $PROJECT_DIR"
echo "    Output : $OUTPUT_ZIP"
echo ""

# Remove stale archive if it exists
[[ -f "$OUTPUT_ZIP" ]] && rm -f "$OUTPUT_ZIP"

# ── Exclusion rules ───────────────────────────────────────────────────────────
# Each -x pattern is relative to the zip root (no leading slash).

EXCLUDES=(
  # ── Dependencies ──────────────────────────────────────────────────────────
  "*/node_modules/*"
  "node_modules/*"
  "*/.pnp.js"
  "*/.pnp.cjs"
  "*/.pnp.loader.mjs"

  # ── Build / cache / output ────────────────────────────────────────────────
  "*/.next/*"
  "*/out/*"
  "*/dist/*"
  "*/build/*"
  "*/.turbo/*"
  "*/.swc/*"
  "*/.cache/*"
  "*/__pycache__/*"

  # ── Environment & secrets ─────────────────────────────────────────────────
  "*.env"
  "*.env.*"
  ".env"
  ".env.*"

  # ── Editor & IDE ──────────────────────────────────────────────────────────
  "*/.vscode/*"
  "*/.idea/*"
  "*.suo"
  "*.user"
  "*/.vs/*"

  # ── Version control ───────────────────────────────────────────────────────
  "*/.git/*"
  "*/.gitignore"
  "*/.gitattributes"
  "*/.gitmodules"

  # ── Tooling & linting configs ─────────────────────────────────────────────
  "*.config.js"
  "*.config.ts"
  "*.config.mjs"
  "*.config.cjs"
  "next.config.*"
  "postcss.config.*"
  "tailwind.config.*"
  "jest.config.*"
  "vitest.config.*"
  "playwright.config.*"
  "cypress.config.*"
  "eslint.config.*"
  ".eslintrc*"
  ".eslintignore"
  ".prettierrc*"
  ".prettierignore"
  ".stylelintrc*"
  ".babelrc*"
  "babel.config.*"
  "tsconfig*.json"
  "jsconfig*.json"
  ".browserslistrc"
  ".nvmrc"
  ".node-version"

  # ── Package manager configs & lock files ─────────────────────────────────
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "pnpm-workspace.yaml"
  "bun.lockb"
  ".yarnrc*"
  ".npmrc"
  ".pnpmfile.cjs"

  # ── CI / deployment configs ───────────────────────────────────────────────
  ".github/*"
  "*/.github/*"
  ".circleci/*"
  ".travis.yml"
  "Dockerfile*"
  "docker-compose*"
  ".dockerignore"
  "vercel.json"
  "netlify.toml"
  ".vercel/*"

  # ── Logs & temporary files ────────────────────────────────────────────────
  "*.log"
  "npm-debug.log*"
  "yarn-debug.log*"
  "yarn-error.log*"
  "*.tmp"
  "*.temp"
  ".DS_Store"
  "Thumbs.db"

  # ── Binary & media files (keep source images, skip compiled/large blobs) ──
  "*.exe"
  "*.dll"
  "*.so"
  "*.dylib"
  "*.bin"
  "*.wasm"
  "*.node"
  "*.snap"
)

# Build the -x arguments array for zip
EXCLUDE_ARGS=()
for pattern in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=("-x" "$pattern")
done

# ── Create the zip ────────────────────────────────────────────────────────────
cd "$PROJECT_DIR"

zip -r "$OUTPUT_ZIP" . "${EXCLUDE_ARGS[@]}"

# ── Summary ───────────────────────────────────────────────────────────────────
SIZE=$(du -sh "$OUTPUT_ZIP" | cut -f1)
FILE_COUNT=$(unzip -l "$OUTPUT_ZIP" | tail -1 | awk '{print $2}')

echo ""
echo "✅  Done!"
echo "    Archive : $OUTPUT_ZIP"
echo "    Size    : $SIZE"
echo "    Files   : $FILE_COUNT"