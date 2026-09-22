"""Регрессии gift codes (без сети / без RevenueCat)."""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

import gift


def _tmp_db(monkeypatch_path: Path):
    gift._gift_db_path = lambda: monkeypatch_path  # type: ignore[method-assign]
    gift.init_gift_db()


def test_issue_demo_requires_flag(tmp_path: Path):
    db = tmp_path / "g.db"
    _tmp_db(db)
    old = gift.GIFT_DEMO
    gift.GIFT_DEMO = False
    try:
        out = gift.issue_gift_code(buyer_rc_id="u1", transaction_id=None, demo=True)
        assert out["ok"] is False
        assert out["error"] == "demo_disabled"
    finally:
        gift.GIFT_DEMO = old


def test_issue_and_redeem_demo(tmp_path: Path):
    db = tmp_path / "g2.db"
    _tmp_db(db)
    old_demo, old_key = gift.GIFT_DEMO, gift.REVENUECAT_SECRET_API_KEY
    gift.GIFT_DEMO = True
    gift.REVENUECAT_SECRET_API_KEY = ""
    try:
        issued = gift.issue_gift_code(buyer_rc_id="buyer", transaction_id=None, demo=True)
        assert issued["ok"] is True
        code = issued["code"]
        assert code.startswith("TAIKA-")

        bad = gift.redeem_gift_code(code_raw="TAIKA-NOPE-NOPE-NOPE", app_user_id="recv")
        assert bad["ok"] is False

        ok = gift.redeem_gift_code(code_raw=code.lower(), app_user_id="recv")
        assert ok["ok"] is True
        assert ok["status"] == "redeemed"

        again = gift.redeem_gift_code(code_raw=code, app_user_id="other")
        assert again["ok"] is False
        assert again["error"] == "already_redeemed"

        same = gift.redeem_gift_code(code_raw=code, app_user_id="recv")
        assert same["ok"] is True
        assert same.get("already") is True
    finally:
        gift.GIFT_DEMO = old_demo
        gift.REVENUECAT_SECRET_API_KEY = old_key


def test_issue_reuses_transaction(tmp_path: Path):
    db = tmp_path / "g3.db"
    _tmp_db(db)
    a = gift.issue_gift_code(buyer_rc_id="b", transaction_id="tx-1", demo=False)
    b = gift.issue_gift_code(buyer_rc_id="b", transaction_id="tx-1", demo=False)
    assert a["ok"] and b["ok"]
    assert a["code"] == b["code"]
    assert b.get("reuse") is True
