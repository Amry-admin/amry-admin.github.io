#!/usr/bin/env bash
# Works out the GitHub Pages address from the repository name and writes
# BASE_HREF and WEB_APP_URL to $GITHUB_ENV.
#   owner/owner.github.io  ->  https://owner.github.io/        base "/"
#   owner/anything         ->  https://owner.github.io/anything/  base "/anything/"
set -eu
owner=$(echo "$GITHUB_REPOSITORY_OWNER" | tr '[:upper:]' '[:lower:]')
repo="${GITHUB_REPOSITORY#*/}"
if [ "$(echo "$repo" | tr '[:upper:]' '[:lower:]')" = "$owner.github.io" ]; then
  base="/"
  url="https://$owner.github.io/"
else
  base="/$repo/"
  url="https://$owner.github.io/$repo/"
fi
echo "BASE_HREF=$base" >> "$GITHUB_ENV"
echo "WEB_APP_URL=$url" >> "$GITHUB_ENV"
echo "::notice title=Web app address::$url"
