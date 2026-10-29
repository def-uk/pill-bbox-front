#!/usr/bin/env bash
# PreToolUse(Bash) 훅: main 브랜치에서의 커밋과 main으로의 푸시를 막는다.
# 막을 때는 이유를 stderr에 쓰고 exit 2 (Claude Code가 명령을 실행하지 않는다).

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
branch=$(git -C "${cwd:-.}" branch --show-current 2>/dev/null)

block() {
  echo "차단됨: $1 작업 브랜치를 만들어 커밋하고(git switch -c feat/...), 그 브랜치를 푸시한 뒤 PR로 합치세요." >&2
  exit 2
}

# git 다음에 오는 -C <경로>, -c <설정> 옵션을 건너뛰고 하위 명령을 찾는다.
git_sub='(^|[^[:alnum:]_/-])git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+'

# 1) main에서 커밋: 같은 명령 안에서 새 브랜치로 옮기는 경우는 허용한다.
if [[ $branch == main ]] && grep -Eq "${git_sub}commit([^[:alnum:]_-]|$)" <<<"$cmd"; then
  if ! grep -Eq "${git_sub}(switch[[:space:]]+(-c|-C|--create|--force-create)|checkout[[:space:]]+(-b|-B))[[:space:]]" <<<"$cmd"; then
    block "main 브랜치에 직접 커밋할 수 없습니다."
  fi
fi

# 2) main으로 푸시: 명령 안의 git push 마다 인자를 살핀다.
while IFS= read -r push; do
  [[ -z $push ]] && continue
  read -ra args <<<"${push#*push}"
  positional=0
  for arg in "${args[@]}"; do
    case $arg in
      --all | --mirror) block "모든 브랜치를 푸시하면 main도 함께 푸시됩니다." ;;
      -*) ;;
      *)
        positional=$((positional + 1))
        # main, +main, HEAD:main, :main, refs/heads/main
        if [[ $positional -ge 2 && $arg =~ ^\+?([^:]*:)?(refs/heads/)?main$ ]]; then
          block "main 브랜치로 푸시할 수 없습니다."
        fi
        # HEAD는 현재 브랜치를 가리킨다.
        if [[ $positional -ge 2 && $branch == main && $arg =~ ^\+?HEAD$ ]]; then
          block "현재 브랜치가 main이라 main으로 푸시됩니다."
        fi
        ;;
    esac
  done
  # refspec 없이 푸시하면 현재 브랜치가 올라간다.
  if [[ $positional -le 1 && $branch == main ]]; then
    block "현재 브랜치가 main이라 main으로 푸시됩니다."
  fi
done < <(grep -oE "${git_sub}push([[:space:]][^;&|]*)?" <<<"$cmd")

exit 0
