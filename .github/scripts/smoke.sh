#!/usr/bin/env bash
# 배포 뒤 바깥 주소(Cloudflare Tunnel 너머)로 새 버전이 떴는지 본다. 배포 워크플로가 GitHub 러너에서 부른다.
# 맥미니 안의 확인(127.0.0.1)은 터널, DNS, HTTPS가 깨져도 통과하므로 여기서 한 번 더 본다.
#
#   .github/scripts/smoke.sh api https://api.<도메인> <커밋>   # /health의 commit이 <커밋>인지
#   .github/scripts/smoke.sh web https://www.<도메인> <커밋>   # /commit.txt가 <커밋>이고 / 가 COOP/COEP와 함께 200인지
#
# 터널과 캐시가 따라오는 시간을 주려고 3초 간격으로 10번까지 다시 해 본다.
set -euo pipefail

kind=${1:?api 또는 web}
base=${2:?주소가 비어 있습니다. 저장소 Variables(API_BASE_URL, WEB_BASE_URL)를 확인하세요}
commit=${3:?커밋}
base=${base%/}

check_api() {
  local body
  body=$(curl -sf -m 10 "$base/health") || return 1
  echo "  $body"
  [[ $body == *"\"commit\":\"$commit\""* ]]
}

check_web() {
  local body headers
  # 쿼리를 붙여 Cloudflare가 예전 응답을 돌려주지 않게 한다.
  body=$(curl -sf -m 10 "$base/commit.txt?v=$commit") || return 1
  echo "  commit.txt: $body"
  [[ $body == "$commit" ]] || return 1
  headers=$(curl -sI -m 10 "$base/") || return 1
  grep -qE '^HTTP/[0-9.]+ 200' <<< "$headers" || { echo "  / 가 200이 아닙니다"; return 1; }
  grep -qi '^cross-origin-opener-policy: same-origin' <<< "$headers" || { echo "  COOP 없음"; return 1; }
  grep -qi '^cross-origin-embedder-policy: require-corp' <<< "$headers" || { echo "  COEP 없음"; return 1; }
}

for i in $(seq 1 10); do
  echo "[$i/10] $kind $base (기대: ${commit:0:7})"
  if "check_$kind"; then
    echo "통과: $base 가 ${commit:0:7}을 내보냅니다"
    exit 0
  fi
  sleep 3
done

echo "::error::$base 에서 ${commit:0:7}을 확인하지 못했습니다"
exit 1
