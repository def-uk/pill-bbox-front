from io import BytesIO

from PIL import Image, UnidentifiedImageError

_MAX_SIDE = 4096
_ORIENTATION = 0x0112


class PhotoError(ValueError):
    pass


def clean_jpeg(data: bytes, width: int, height: int) -> bytes:
    """사진이 [width]×[height] JPEG인지 보고, EXIF·XMP(위치 등)가 있으면 지운 JPEG를 돌려준다.

    앱이 올리기 전에 지우지만(backend/README.md 4.2) 서버에도 남지 않게 한 번 더 지운다.
    회전 정보가 남은 사진은 받지 않는다.
    박스 좌표가 회전 전 기준인지 후 기준인지 알 수 없기 때문이다.
    """
    try:
        image = Image.open(BytesIO(data))
        if image.format != "JPEG":
            raise PhotoError("사진은 JPEG여야 합니다")
        if max(image.size) > _MAX_SIDE:
            raise PhotoError(f"사진의 긴 변은 {_MAX_SIDE}px 이하여야 합니다")
        image.load()
    except (UnidentifiedImageError, OSError) as e:
        raise PhotoError("사진을 읽을 수 없습니다") from e

    if image.size != (width, height):
        raise PhotoError(
            f"사진 크기 {image.size[0]}×{image.size[1]}가 meta의 {width}×{height}와 다릅니다"
        )
    exif = image.getexif()
    if exif.get(_ORIENTATION, 1) != 1:
        raise PhotoError(
            "회전 정보(EXIF Orientation)가 남은 사진입니다. 회전을 적용해 다시 써서 올려 주세요"
        )
    if not exif and "xmp" not in image.info:
        return data

    # quality="keep"은 원래 양자화 표를 그대로 써서 화질이 거의 그대로다.
    out = BytesIO()
    image.save(
        out,
        "JPEG",
        quality="keep",
        subsampling="keep",
        icc_profile=image.info.get("icc_profile"),
    )
    return out.getvalue()
