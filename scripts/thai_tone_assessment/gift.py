"""
Подарок Taika Pro: одноразовые коды → RevenueCat promotional entitlement.

Поток:
  1) Покупатель платит gift-SKU (или demo) → POST /gift/issue → код
  2) Получатель POST /gift/redeem → grant `pro` на его app_user_id

Почта не нужна. Код шарится через системный share sheet.
"""
from __future__ import annotations

import os
import secrets
import sqlite3
import string
import sys
import time
from pathlib import Path
from typing import Any

import requests

REVENUECAT_SECRET_API_KEY = (os.getenv("REVENUECAT_SECRET_API_KEY") or "").strip()
REVENUECAT_ENTITLEMENT = (os.getenv("TAIKA_RC_ENTITLEMENT") or "pro").strip() or "pro"
GIFT_DEMO = (os.getenv("GIFT_DEMO") or "").strip() in ("1", "true", "yes")


def _gift_db_path() -> Path:
    env = (os.getenv("TAIKA_GIFT_CACHE_DB") or "").strip()
    if env:
        return Path(env).expanduser().resolve()
    return (Path(__file__).resolve().parent / "gift_codes.db").resolve()


def init_gift_db() -> None:
    path = _gift_db_path()
    with sqlite3.connect(path) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS gift_codes (
                code TEXT PRIMARY KEY,
                status TEXT NOT NULL DEFAULT 'unused',
                buyer_rc_id TEXT,
                transaction_id TEXT,
                redeemed_rc_id TEXT,
                created_at INTEGER NOT NULL,
                redeemed_at INTEGER
            )
            """
        )
        conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_gift_tx ON gift_codes(transaction_id) "
            "WHERE transaction_id IS NOT NULL AND transaction_id != ''"
        )
        conn.commit()


def _new_code() -> str:
    alphabet = string.ascii_uppercase + string.digits
    alphabet = alphabet.replace("O", "").replace("0", "").replace("I", "").replace("1", "")
    parts = ["".join(secrets.choice(alphabet) for _ in range(4)) for _ in range(3)]
    return "TAIKA-" + "-".join(parts)


def _normalize_code(raw: str) -> str:
    s = (raw or "").strip().upper().replace(" ", "")
    s = s.replace("—", "-").replace("–", "-")
    return s


def issue_gift_code(
    *,
    buyer_rc_id: str | None,
    transaction_id: str | None,
    demo: bool = False,
) -> dict[str, Any]:
    """
    Создаёт одноразовый код.
    - demo=True только если GIFT_DEMO=1 на сервере (локальный/TF UX без gift-SKU).
    - иначе нужен transaction_id (StoreKit / RevenueCat).
    """
    init_gift_db()
    tx = (transaction_id or "").strip()
    buyer = (buyer_rc_id or "").strip() or None

    if demo:
        if not GIFT_DEMO:
            return {"ok": False, "error": "demo_disabled"}
    elif not tx:
        return {"ok": False, "error": "transaction_required"}

    if tx:
        with sqlite3.connect(_gift_db_path()) as conn:
            row = conn.execute(
                "SELECT code, status FROM gift_codes WHERE transaction_id = ?",
                (tx,),
            ).fetchone()
            if row:
                return {"ok": True, "code": row[0], "status": row[1], "reuse": True}

    for _ in range(8):
        code = _new_code()
        try:
            with sqlite3.connect(_gift_db_path()) as conn:
                conn.execute(
                    "INSERT INTO gift_codes (code, status, buyer_rc_id, transaction_id, created_at) "
                    "VALUES (?, 'unused', ?, ?, ?)",
                    (code, buyer, tx or None, int(time.time())),
                )
                conn.commit()
            print(f"[gift] issued {code} demo={demo} tx={tx[:12] if tx else '-'}", file=sys.stderr, flush=True)
            return {"ok": True, "code": code, "status": "unused", "reuse": False}
        except sqlite3.IntegrityError:
            continue
    return {"ok": False, "error": "code_collision"}


def _grant_promotional_entitlement(app_user_id: str) -> tuple[bool, str | None]:
    if not REVENUECAT_SECRET_API_KEY:
        return False, "revenuecat_secret_missing"
    uid = requests.utils.quote(app_user_id, safe="")
    ent = requests.utils.quote(REVENUECAT_ENTITLEMENT, safe="")
    url = f"https://api.revenuecat.com/v1/subscribers/{uid}/entitlements/{ent}/promotional"
    try:
        resp = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {REVENUECAT_SECRET_API_KEY}",
                "Content-Type": "application/json",
                "X-Platform": "ios",
            },
            json={"duration": "lifetime"},
            timeout=20,
        )
    except Exception as e:  # noqa: BLE001
        print(f"[gift] RC grant request failed: {e}", file=sys.stderr, flush=True)
        return False, "revenuecat_network"
    if resp.status_code >= 300:
        print(f"[gift] RC grant http {resp.status_code}: {resp.text[:200]}", file=sys.stderr, flush=True)
        return False, f"revenuecat_http_{resp.status_code}"
    return True, None


def redeem_gift_code(*, code_raw: str, app_user_id: str) -> dict[str, Any]:
    init_gift_db()
    code = _normalize_code(code_raw)
    uid = (app_user_id or "").strip()
    if not code or not uid:
        return {"ok": False, "error": "code_and_user_required"}
    if not code.startswith("TAIKA-"):
        return {"ok": False, "error": "invalid_format"}

    with sqlite3.connect(_gift_db_path()) as conn:
        row = conn.execute(
            "SELECT status, redeemed_rc_id FROM gift_codes WHERE code = ?",
            (code,),
        ).fetchone()
        if not row:
            return {"ok": False, "error": "not_found"}
        status, redeemed_uid = row[0], row[1]
        if status == "redeemed":
            if redeemed_uid == uid:
                return {"ok": True, "code": code, "status": "redeemed", "already": True}
            return {"ok": False, "error": "already_redeemed"}
        if status != "unused":
            return {"ok": False, "error": "unavailable"}

        granted, grant_err = _grant_promotional_entitlement(uid)
        if not granted and not GIFT_DEMO:
            return {"ok": False, "error": grant_err or "grant_failed"}
        if not granted and GIFT_DEMO:
            print(
                f"[gift] DEMO redeem without RC grant for {uid}: {grant_err}",
                file=sys.stderr,
                flush=True,
            )

        conn.execute(
            "UPDATE gift_codes SET status = 'redeemed', redeemed_rc_id = ?, redeemed_at = ? "
            "WHERE code = ? AND status = 'unused'",
            (uid, int(time.time()), code),
        )
        if conn.total_changes == 0:
            return {"ok": False, "error": "race_lost"}
        conn.commit()

    return {
        "ok": True,
        "code": code,
        "status": "redeemed",
        "entitlement_granted": bool(REVENUECAT_SECRET_API_KEY) or GIFT_DEMO,
        "demo_grant": bool(GIFT_DEMO and not REVENUECAT_SECRET_API_KEY),
    }


def gift_health() -> dict[str, Any]:
    return {
        "gift_demo": GIFT_DEMO,
        "revenuecat_secret": bool(REVENUECAT_SECRET_API_KEY),
        "entitlement": REVENUECAT_ENTITLEMENT,
    }
