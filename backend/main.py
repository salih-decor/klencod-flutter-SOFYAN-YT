"""SOFYAN YT — الخادم: حسابات + OCR (صور/PDF) + حل بالذكاء الاصطناعي + مراجعة + محادثة + مكتبة RAG + سجل."""
import json
import os
import re
import secrets
import time
from contextlib import closing
from typing import Literal

from dotenv import load_dotenv

load_dotenv()

from fastapi import Depends, FastAPI, File, Form, HTTPException, Request, UploadFile  # noqa: E402
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer  # noqa: E402
from pydantic import BaseModel, Field  # noqa: E402

import db as dbm  # noqa: E402
import llm  # noqa: E402
import ocr as ocrm  # noqa: E402
import prompts  # noqa: E402
import rag  # noqa: E402
import security as sec  # noqa: E402

MAX_BYTES, MAX_FILES = 10 * 1024 * 1024, 8
MAX_LIB_BYTES = 40 * 1024 * 1024
ADMIN_EMAILS = {e.strip().lower() for e in os.getenv("ADMIN_EMAILS", "").split(",") if e.strip()}
ALLOW_REGISTRATION = os.getenv("ALLOW_REGISTRATION", "true").lower() != "false"
JWT_SECRET = os.getenv("SOFYAN_JWT_SECRET", "")
if not JWT_SECRET or "غيّرني" in JWT_SECRET:
    JWT_SECRET = secrets.token_urlsafe(48)
    print("⚠️  SOFYAN_JWT_SECRET غير مضبوط: سُيستعمل سرّ مؤقت وستنتهي جلسات الدخول عند إعادة التشغيل.")

app = FastAPI(title="SOFYAN YT", version="0.2.0")
bearer = HTTPBearer(auto_error=False)
limiter = sec.LoginLimiter()
dbm.init_default()


def db():
    return dbm.connect()


# ───────────────────────── المصادقة ─────────────────────────
def user_dict(row) -> dict:
    return {"id": row["id"], "email": row["email"], "name": row["name"], "is_admin": row["email"] in ADMIN_EMAILS}


def current_user(cred: HTTPAuthorizationCredentials | None = Depends(bearer)) -> dict:
    if not cred:
        raise HTTPException(401, "يلزم تسجيل الدخول")
    try:
        uid = sec.decode_token(cred.credentials, JWT_SECRET)
    except Exception:
        raise HTTPException(401, "انتهت الجلسة، سجّل الدخول من جديد")
    with closing(db()) as c:
        row = c.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    if not row:
        raise HTTPException(401, "الحساب غير موجود")
    return user_dict(row)


class RegisterIn(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=2, max_length=60)


class LoginIn(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(max_length=128)


@app.get("/api/health")
def health():
    return {"ok": True, "llm_configured": bool(os.getenv("ANTHROPIC_API_KEY")) and "ضع_المفتاح" not in os.getenv("ANTHROPIC_API_KEY", ""),
            "registration_open": ALLOW_REGISTRATION, "version": app.version}


@app.post("/api/auth/register")
def register(p: RegisterIn):
    if not ALLOW_REGISTRATION:
        raise HTTPException(403, "إنشاء الحسابات مغلق على هذا الخادم")
    email = sec.normalize_email(p.email)
    if not sec.valid_email(email):
        raise HTTPException(422, "البريد الإلكتروني غير صالح")
    with closing(db()) as c:
        if c.execute("SELECT 1 FROM users WHERE email=?", (email,)).fetchone():
            raise HTTPException(409, "هذا البريد مسجّل من قبل")
        cur = c.execute("INSERT INTO users(email,name,pw_hash,created) VALUES(?,?,?,?)",
                        (email, p.name.strip(), sec.hash_password(p.password), time.time()))
        c.commit()
        row = c.execute("SELECT * FROM users WHERE id=?", (cur.lastrowid,)).fetchone()
    return {"token": sec.make_token(row["id"], JWT_SECRET), "user": user_dict(row)}


@app.post("/api/auth/login")
def login(p: LoginIn, request: Request):
    email = sec.normalize_email(p.email)
    key = f"{email}|{request.client.host if request.client else '?'}"
    if limiter.blocked(key):
        raise HTTPException(429, "محاولات كثيرة فاشلة، حاول بعد 15 دقيقة")
    with closing(db()) as c:
        row = c.execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()
    if not row or not sec.verify_password(p.password, row["pw_hash"]):
        limiter.fail(key)
        raise HTTPException(401, "البريد أو كلمة المرور غير صحيحة")
    limiter.reset(key)
    return {"token": sec.make_token(row["id"], JWT_SECRET), "user": user_dict(row)}


@app.get("/api/auth/me")
def me(u: dict = Depends(current_user)):
    return u


# ───────────────────────── OCR ─────────────────────────
@app.post("/api/ocr")
def ocr(files: list[UploadFile] = File(...), u: dict = Depends(current_user)):
    if not files:
        raise HTTPException(400, "لم تُرسل أي ملفات")
    if len(files) > MAX_FILES:
        raise HTTPException(400, f"الحد الأقصى {MAX_FILES} ملفات")
    texts, confs = [], []
    for f in files:
        data = f.file.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise HTTPException(413, f"الملف {f.filename} أكبر من 10MB")
        try:
            pages, conf = ocrm.extract(data)
        except ocrm.pytesseract.TesseractNotFoundError:
            raise HTTPException(500, "Tesseract غير مثبت على الخادم أو مساره خاطئ")
        except ocrm.pytesseract.TesseractError as e:
            raise HTTPException(500, f"فشل Tesseract (تأكد من تثبيت لغات ara/fra/eng): {e}")
        except Exception:
            raise HTTPException(400, f"الملف {f.filename} ليس صورة أو PDF صالحًا")
        texts.append("\n\n".join(p for p in pages if p.strip()))
        if conf is not None:
            confs.append(conf)
    mean = sum(confs) / len(confs) if confs else None
    warn = ("وضوح القراءة منخفض؛ راجع النص المستخرج بعناية أو أعد تصوير الورقة."
            if mean is not None and mean < 70 else None)
    return {"text": "\n\n".join(t for t in texts if t), "mean_conf": round(mean, 1) if mean is not None else None,
            "warning": warn, "from_text_layer": mean is None}


# ───────────────────────── الحل والمراجعة ─────────────────────────
class SolveIn(BaseModel):
    text: str = Field(min_length=5, max_length=30000)
    subject: str = Field(max_length=60)
    track: str = Field(max_length=60)
    mode: Literal["model", "teacher"] = "model"
    task: str = "exam"
    use_rag: bool = False


def retrieve(c, user_id: int, query: str, subject: str | None, enabled: bool) -> list[dict]:
    if not enabled:
        return []
    return rag.make_sources(rag.search(c, user_id, query[:800], limit=6, subject=subject))


def llm_call(system: str, messages: list[dict], max_tokens: int = 4000):
    try:
        return llm.call_model(system, messages, max_tokens)
    except llm.LLMError as e:
        raise HTTPException(e.status, e.message)


@app.post("/api/solve")
def solve(p: SolveIn, u: dict = Depends(current_user)):
    if p.task not in prompts.TASKS:
        raise HTTPException(422, "نوع المهمة غير معروف")
    system = prompts.system_for(p.task, p.subject, p.mode)
    with closing(db()) as c:
        sources = retrieve(c, u["id"], p.text, p.subject, p.use_rag)
        ctx = prompts.rag_context(sources, rag.passages_block(sources), p.use_rag)
        user_msg = (f"الشعبة: {p.track}\nالمادة: {p.subject}\n\n"
                    f"نص الاختبار (مستخرج وقد يحتوي أخطاء OCR):\n{p.text}")
        if ctx:
            user_msg = ctx + "\n\n" + user_msg
        ans, tin, tout = llm_call(system, [{"role": "user", "content": user_msg}])
        cur = c.execute(
            "INSERT INTO history(user_id,created,subject,track,task,mode,question,answer,sources,tokens_in,tokens_out)"
            " VALUES(?,?,?,?,?,?,?,?,?,?,?)",
            (u["id"], time.time(), p.subject, p.track, p.task, p.mode, p.text, ans, rag.sources_json(sources), tin, tout))
        c.commit()
        return {"id": cur.lastrowid, "answer": ans, "sources": sources, "usage": {"in": tin, "out": tout}}


class VerifyIn(BaseModel):
    use_rag: bool = True


@app.post("/api/verify/{hid}")
def verify(hid: int, p: VerifyIn | None = None, u: dict = Depends(current_user)):
    use_rag = True if p is None else p.use_rag
    with closing(db()) as c:
        row = c.execute("SELECT * FROM history WHERE id=? AND user_id=?", (hid, u["id"])).fetchone()
        if not row:
            raise HTTPException(404, "غير موجود")
        sources = retrieve(c, u["id"], row["question"], row["subject"], use_rag)
        passages = rag.passages_block(sources)
        user_msg = f"المادة: {row['subject']} — الشعبة: {row['track']}\n\nالأسئلة:\n{row['question']}\n\n"
        if passages:
            user_msg += f"مراجع مسترجعة من مكتبة التطبيق:\n{passages}\n\n"
        else:
            user_msg += "لا توجد مراجع مسترجعة من مكتبة التطبيق؛ كل ما لا يمكن التأكد منه اذكره «غير موثّق».\n\n"
        user_msg += f"الإجابة المراد مراجعتها:\n{row['answer']}"
        rev, tin, tout = llm_call(prompts.VERIFY, [{"role": "user", "content": user_msg}], 5000)
        c.execute("UPDATE history SET review=?, review_sources=?, tokens_in=tokens_in+?, tokens_out=tokens_out+? WHERE id=?",
                  (rev, rag.sources_json(sources), tin, tout, hid))
        c.commit()
    return {"id": hid, "review": rev, "sources": sources}


# ───────────────────────── المحادثة ─────────────────────────
class ChatMsg(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=8000)


class ChatIn(BaseModel):
    messages: list[ChatMsg] = Field(min_length=1, max_length=30)
    subject: str | None = Field(default=None, max_length=60)
    track: str | None = Field(default=None, max_length=60)
    use_rag: bool = False


@app.post("/api/chat")
def chat(p: ChatIn, u: dict = Depends(current_user)):
    msgs = [m.model_dump() for m in p.messages]
    while msgs and msgs[0]["role"] != "user":
        msgs.pop(0)
    if not msgs or msgs[-1]["role"] != "user":
        raise HTTPException(422, "آخر رسالة يجب أن تكون من المستخدم")
    system = prompts.CHAT
    if p.subject:
        system += "\n" + prompts.SUBJECT_GUIDES.get(p.subject, f"المادة: {p.subject}.")
    if p.track:
        system += f"\nشعبة التلميذ: {p.track}."
    with closing(db()) as c:
        sources = retrieve(c, u["id"], msgs[-1]["content"], p.subject, p.use_rag)
    ctx = prompts.rag_context(sources, rag.passages_block(sources), p.use_rag)
    if ctx:
        system += "\n\n" + ctx
    ans, tin, tout = llm_call(system, msgs, 2500)
    return {"answer": ans, "sources": sources, "usage": {"in": tin, "out": tout}}


# ───────────────────────── السجل (لكل مستخدم) ─────────────────────────
@app.get("/api/history")
def history(u: dict = Depends(current_user)):
    with closing(db()) as c:
        rows = c.execute("SELECT id,created,subject,track,COALESCE(task,'exam') AS task,mode FROM history"
                         " WHERE user_id=? ORDER BY id DESC LIMIT 100", (u["id"],)).fetchall()
    return [dict(r) for r in rows]


def _load_sources(raw):
    try:
        return json.loads(raw) if raw else []
    except Exception:
        return []


@app.get("/api/history/{hid}")
def history_item(hid: int, u: dict = Depends(current_user)):
    with closing(db()) as c:
        row = c.execute("SELECT * FROM history WHERE id=? AND user_id=?", (hid, u["id"])).fetchone()
    if not row:
        raise HTTPException(404, "غير موجود")
    d = dict(row)
    d["task"] = d.get("task") or "exam"
    d["sources"] = _load_sources(d.get("sources"))
    d["review_sources"] = _load_sources(d.get("review_sources"))
    return d


@app.delete("/api/history/{hid}")
def history_delete(hid: int, u: dict = Depends(current_user)):
    with closing(db()) as c:
        c.execute("DELETE FROM history WHERE id=? AND user_id=?", (hid, u["id"]))
        c.commit()
    return {"ok": True}


# ───────────────────────── مكتبة المراجع (RAG) ─────────────────────────
@app.get("/api/library")
def library(u: dict = Depends(current_user)):
    with closing(db()) as c:
        return rag.list_documents(c, u["id"])


@app.get("/api/library/search")
def library_search(q: str, subject: str | None = None, u: dict = Depends(current_user)):
    if len(q.strip()) < 2:
        raise HTTPException(422, "اكتب كلمتين أو أكثر للبحث")
    with closing(db()) as c:
        return rag.make_sources(rag.search(c, u["id"], q[:300], limit=10, subject=subject), max_chars=600)


def _safe_name(name: str) -> str:
    return re.sub(r"[^\w.\-]", "_", os.path.basename(name or "file"))[:80] or "file"


@app.post("/api/library")
def library_add(file: UploadFile = File(...), title: str = Form(..., max_length=160), subject: str = Form("", max_length=60),
                track: str = Form("", max_length=60), year: str = Form("", max_length=20),
                source_note: str = Form("", max_length=300), shared: bool = Form(False),
                u: dict = Depends(current_user)):
    if shared and not u["is_admin"]:
        raise HTTPException(403, "إضافة ملفات مشتركة للجميع متاحة للمشرف فقط")
    data = file.file.read(MAX_LIB_BYTES + 1)
    if len(data) > MAX_LIB_BYTES:
        raise HTTPException(413, "الملف أكبر من 40MB")
    name = file.filename or "file"
    is_pdf = ocrm.is_pdf(data)
    try:
        if is_pdf:
            pages, _ = ocrm.extract(data, max_pages=int(os.getenv("LIB_MAX_PAGES", "80")))
        elif name.lower().endswith((".txt", ".md")):
            pages = [data.decode("utf-8", errors="replace")]
        else:
            pages, _ = ocrm.extract(data)
    except Exception:
        raise HTTPException(400, "تعذّر قراءة الملف (المسموح: PDF، صورة، txt، md)")
    if not any(p.strip() for p in pages):
        raise HTTPException(422, "لم يُستخرج أي نص من الملف")
    meta = {"title": title.strip(), "subject": subject.strip(), "track": track.strip(), "year": year.strip(),
            "source_note": source_note.strip(), "filename": _safe_name(name)}
    with closing(db()) as c:
        doc_id, n = rag.add_document(c, u["id"], shared, meta, pages)
        if not is_pdf:  # لا معنى لرقم الصفحة خارج PDF
            c.execute("UPDATE chunks SET page=NULL WHERE doc_id=?", (doc_id,))
            c.execute("UPDATE documents SET pages=0 WHERE id=?", (doc_id,))
            c.commit()
    with open(os.path.join(dbm.LIB_DIR, f"{doc_id}_{_safe_name(name)}"), "wb") as fh:
        fh.write(data)
    return {"id": doc_id, "chunks": n}


@app.delete("/api/library/{doc_id}")
def library_delete(doc_id: int, u: dict = Depends(current_user)):
    with closing(db()) as c:
        row = c.execute("SELECT * FROM documents WHERE id=?", (doc_id,)).fetchone()
        if not row:
            raise HTTPException(404, "غير موجود")
        if row["owner_id"] != u["id"] and not u["is_admin"]:
            raise HTTPException(403, "لا يمكنك حذف ملف غيرك")
        rag.delete_document(c, doc_id)
    prefix = f"{doc_id}_"
    for f in os.listdir(dbm.LIB_DIR):
        if f.startswith(prefix):
            os.remove(os.path.join(dbm.LIB_DIR, f))
    return {"ok": True}
