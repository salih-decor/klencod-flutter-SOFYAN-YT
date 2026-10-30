"""كلمات المرور، رموز الدخول (JWT)، وتحديد محاولات الدخول الفاشلة."""
import hashlib
import hmac
import os
import re
import time

import jwt

_ITER = 310_000
_EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def normalize_email(email: str) -> str:
    return email.strip().lower()


def valid_email(email: str) -> bool:
    return bool(_EMAIL.match(email)) and len(email) <= 254


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, _ITER)
    return f"pbkdf2_sha256${_ITER}${salt.hex()}${dk.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algo, it, salt, dk = stored.split("$")
        if algo != "pbkdf2_sha256":
            return False
        test = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), int(it))
        return hmac.compare_digest(test.hex(), dk)
    except Exception:
        return False


def make_token(user_id: int, secret: str, days: int = 30) -> str:
    now = int(time.time())
    return jwt.encode({"sub": str(user_id), "iat": now, "exp": now + days * 86400}, secret, algorithm="HS256")


def decode_token(token: str, secret: str) -> int:
    data = jwt.decode(token, secret, algorithms=["HS256"])
    return int(data["sub"])


class LoginLimiter:
    """حدّ بسيط في الذاكرة: max_fail محاولة فاشلة لكل مفتاح خلال window ثانية."""

    def __init__(self, max_fail: int = 8, window: int = 900):
        self.max_fail, self.window, self._fails = max_fail, window, {}

    def _recent(self, key: str, now: float):
        v = [t for t in self._fails.get(key, []) if now - t < self.window]
        self._fails[key] = v
        return v

    def blocked(self, key: str, now: float | None = None) -> bool:
        return len(self._recent(key, now or time.time())) >= self.max_fail

    def fail(self, key: str, now: float | None = None) -> None:
        n = now or time.time()
        self._recent(key, n).append(n)

    def reset(self, key: str) -> None:
        self._fails.pop(key, None)
