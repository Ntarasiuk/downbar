#!/usr/bin/env bash
# Deploys the static landing page in site/ to Cloudflare Pages (project "downbar",
# https://downbar.pages.dev). Must be run in an interactive terminal: `wrangler
# pages deploy` only accepts the OAuth login from a TTY, otherwise it demands a
# CLOUDFLARE_API_TOKEN. If it complains the token is stale, run `wrangler login`
# once to refresh, then re-run this.
set -euo pipefail
cd "$(dirname "$0")/.."

# Ntarasiuk@gmail.com's Cloudflare account.
export CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-c66b7e19a4bcf2d4461d55b6e2280ba1}"

npx -y wrangler@latest pages deploy site \
  --project-name=downbar \
  --branch=master \
  --commit-dirty=true
