#!/usr/bin/env bash
# 탐지 모델을 받아 assets/models/에 둔다 (docs/DESIGN.md 3.3).
#
#   scripts/fetch_model.sh                    assets/models/VERSION에 적힌 버전을 받는다
#   scripts/fetch_model.sh model-v1           def-uk/pill-bbox 릴리스 태그를 받는다
#   scripts/fetch_model.sh standin-yolo26n    모델 확정 전 연동 확인용 공식 YOLO26n(COCO 80종)
#
# 앱이 모델을 기기에 버전별 파일 이름으로 캐시하므로, 파일 이름에 버전을 넣는다.
set -euo pipefail

cd "$(dirname "$0")/.."
dir=assets/models
version=${1:-$(cat "$dir/VERSION")}

if [[ ! $version =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "버전 이름에는 영문, 숫자, . _ - 만 쓸 수 있습니다: $version" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [[ $version == standin-yolo26n ]]; then
  curl -fL --progress-bar -o "$tmp/pillbox.tflite" \
    https://github.com/ultralytics/yolo-flutter-app/releases/download/v0.7.0/yolo26n_w8a32.tflite
  curl -fL --progress-bar -o "$tmp/pillbox.mlpackage.zip" \
    https://github.com/ultralytics/yolo-ios-app/releases/download/v8.3.0/yolo26n.mlpackage.zip
  # COCO 80종. 실제 약과 겹치지 않게 category_id를 900000번대로 둔다.
  names=(person bicycle car motorcycle airplane bus train truck boat "traffic light"
    "fire hydrant" "stop sign" "parking meter" bench bird cat dog horse sheep cow
    elephant bear zebra giraffe backpack umbrella handbag tie suitcase frisbee
    skis snowboard "sports ball" kite "baseball bat" "baseball glove" skateboard surfboard "tennis racket" bottle
    "wine glass" cup fork knife spoon bowl banana apple sandwich orange
    broccoli carrot "hot dog" pizza donut cake chair couch "potted plant" bed
    "dining table" toilet tv laptop mouse remote keyboard "cell phone" microwave oven
    toaster sink refrigerator book clock vase scissors "teddy bear" "hair drier" toothbrush)
  {
    echo "["
    for i in "${!names[@]}"; do
      sep=$([[ $i -lt $((${#names[@]} - 1)) ]] && echo "," || echo "")
      printf '  {"yolo_idx": %d, "category_id": %d, "name": "%s"}%s\n' "$i" $((900000 + i)) "${names[$i]}" "$sep"
    done
    echo "]"
  } > "$tmp/labels.json"
else
  gh release download "$version" -R def-uk/pill-bbox -D "$tmp" \
    -p pillbox.tflite -p pillbox.mlpackage.zip -p labels.json
fi

# 이전 버전 파일을 지우고 새 버전으로 바꾼다.
find "$dir" -maxdepth 1 -name 'pillbox-*' -delete
mv "$tmp/pillbox.tflite" "$dir/pillbox-$version.tflite"
mv "$tmp/pillbox.mlpackage.zip" "$dir/pillbox-$version.mlpackage.zip"
mv "$tmp/labels.json" "$dir/pillbox-$version.labels.json"
echo "$version" > "$dir/VERSION"
ls -lh "$dir"
