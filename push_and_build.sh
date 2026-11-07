#!/bin/bash
# Usage: GH_USER=<login> GH_TOKEN=<token with repo+workflow> ./push_and_build.sh
set -euo pipefail
REPO=${REPO:-madar-tv}
cd "$(dirname "$0")"
API=https://api.github.com
AUTH="Authorization: token $GH_TOKEN"
curl -sf -H "$AUTH" $API/repos/$GH_USER/$REPO >/dev/null || \
  curl -sf -H "$AUTH" -X POST $API/user/repos -d "{\"name\":\"$REPO\",\"private\":false,\"description\":\"مَدار TV — SwiftUI iOS app\"}" >/dev/null
rm -rf .git && git init -q -b main && git add -A && git -c user.name="Madar TV" -c user.email="alsalmi@mail.tab.bot" commit -qm "مَدار TV source"
git push -q -f "https://x-access-token:$GH_TOKEN@github.com/$GH_USER/$REPO.git" main
rm -rf .git
echo "pushed https://github.com/$GH_USER/$REPO"
