"""استدعاء Anthropic API. المفتاح يبقى هنا على الخادم فقط."""
import os
import time

import httpx

API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
MODEL = os.getenv("SOFYAN_MODEL", "claude-sonnet-5-5")


class LLMError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status, self.message = status, message


def call_model(system: str, messages: list[dict], max_tokens: int = 4000):
    key = os.getenv("ANTHROPIC_API_KEY", "") or API_KEY
    if not key or "ضع_المفتاح" in key:
        raise LLMError(503, "مفتاح ANTHROPIC_API_KEY غير مضبوط على الخادم")
    body = {"model": os.getenv("SOFYAN_MODEL", MODEL), "max_tokens": max_tokens,
            "system": system, "messages": messages}
    headers = {"x-api-key": key, "anthropic-version": "2023-06-01"}
    last = ""
    for attempt in range(3):  # إعادة المحاولة عند الضغط/الأخطاء المؤقتة
        try:
            r = httpx.post("https://api.anthropic.com/v1/messages", json=body, headers=headers, timeout=120)
        except httpx.HTTPError as e:
            last = f"تعذر الاتصال بمزود الذكاء الاصطناعي: {e}"
        else:
            if r.status_code == 200:
                d = r.json()
                text = "".join(b.get("text", "") for b in d["content"] if b["type"] == "text")
                u = d.get("usage", {})
                return text, u.get("input_tokens", 0), u.get("output_tokens", 0)
            last = f"خطأ من المزود ({r.status_code}): {r.text[:300]}"
            if r.status_code not in (429, 500, 502, 503, 529):
                break
        time.sleep(2 ** attempt)
    raise LLMError(502, last)
