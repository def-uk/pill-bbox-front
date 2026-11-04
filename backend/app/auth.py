import hashlib
import secrets
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .db import get_session
from .models import Vault

# Crockford Base32. 헷갈리는 I, L, O, U를 뺀다.
_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_CODE_LENGTH = 20  # 약 100비트
_GROUP = 4
_LOOKALIKES = str.maketrans({"I": "1", "L": "1", "O": "0"})


def new_code() -> str:
    """`7K3Q-M9XD-2HWB-PF4R-ZC8N` 같은 동기화 코드."""
    raw = "".join(secrets.choice(_ALPHABET) for _ in range(_CODE_LENGTH))
    return "-".join(raw[i : i + _GROUP] for i in range(0, _CODE_LENGTH, _GROUP))


def normalize(code: str) -> str | None:
    """손으로 넣은 코드를 맞춘다. 소문자, 하이픈·공백, 닮은 글자(I·L→1, O→0)를 받는다."""
    raw = "".join(code.split()).replace("-", "").upper().translate(_LOOKALIKES)
    if len(raw) != _CODE_LENGTH or any(c not in _ALPHABET for c in raw):
        return None
    return raw


def hash_code(code: str) -> str:
    raw = normalize(code)
    if raw is None:
        raise ValueError("동기화 코드 형식이 아닙니다")
    return hashlib.sha256(raw.encode()).hexdigest()


def current_vault(
    session: Annotated[Session, Depends(get_session)],
    authorization: Annotated[str | None, Header()] = None,
) -> Vault:
    """`Authorization: Bearer <코드>`의 보관함. 없거나 틀리면 401."""
    scheme, _, code = (authorization or "").partition(" ")
    raw = normalize(code) if scheme.lower() == "bearer" else None
    vault = (
        session.scalar(select(Vault).where(Vault.code_hash == hash_code(raw)))
        if raw is not None
        else None
    )
    if vault is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "동기화 코드가 없거나 맞지 않습니다",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return vault


CurrentVault = Annotated[Vault, Depends(current_vault)]
