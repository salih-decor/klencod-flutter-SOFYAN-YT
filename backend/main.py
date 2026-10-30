"""SOFYAN YT — الخادم: OCR + حل بالذكاء الاصطناعي + مراجعة + سجل (SQLite)."""
import io, os, sqlite3, time
from contextlib import closing

import httpx
import pytesseract
from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, ImageOps
from pydantic import BaseModel, Field

load_dotenv()
API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
MODEL = os.getenv("SOFYAN_MODEL", "claude-sonnet-5-5")
DB = os.getenv("SOFYAN_DB", "sofyan.db")
MAX_BYTES, MAX_FILES = 10 * 1024 * 1024, 8
if os.getenv("TESSERACT_CMD"):
    pytesseract.pytesseract.tesseract_cmd = os.environ["TESSERACT_CMD"]

app = FastAPI(title="SOFYAN YT")


def db():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


with closing(db()) as c:
    c.execute("""CREATE TABLE IF NOT EXISTS history(
        id INTEGER PRIMARY KEY AUTOINCREMENT, created REAL, subject TEXT, track TEXT,
        mode TEXT, question TEXT, answer TEXT, review TEXT, tokens_in INT, tokens_out INT)""")
    c.commit()

BASE_RULES = """أنت «SOFYAN YT»، مساعد دراسي متخصص في منهاج البكالوريا الجزائرية (السنة الثالثة ثانوي).
القواعد الصارمة:
- أجب عن كل سؤال بحسب ترتيبه في الورقة، مع احترام النقاط والمنهجية المطلوبة.
- لا تختلق اقتباسات أو أبياتًا أو آيات أو أحاديث أو تواريخ أو مصادر. ميّز بين الاقتباس الحرفي وتلخيص الفكرة.
- إن كان نص السؤال ناقصًا أو غامضًا أو بدا خطأ OCR، اذكر ذلك صراحة واطلب توضيحه بدل التخمين.
- لا تعرض نسب ثقة رقمية. عند الشك وضّح سببه.
- التزم بمصطلحات المقرر الجزائري ومستوى السنة الثالثة ثانوي، ولا تخلط بين المناهج.
- في الفلسفة اتبع المنهجيات الجزائرية (تحليل نص، مقالة جدلية، استقصاء بالوضع/الرفع) ولا تنسب للنص حججًا غير موجودة فيه."""

MODES = {
    "model": "الوضع: الإجابة النموذجية. قدّم إجابة منظمة ومباشرة تشبه سلم التصحيح النموذجي.",
    "teacher": "الوضع: الأستاذ الذكي. اشرح خطوات الحل ليفهم التلميذ الدرس، ثم اقترح سؤالين تدريبيين في النهاية.",
}


def call_model(system: str, user: str, max_tokens: int = 4000):
    if not API_KEY:
        raise HTTPException(503, "مفتاح ANTHROPIC_API_KEY غير مضبوط في backend/.env")
    body = {"model": MODEL, "max_tokens": max_tokens, "system": system,
            "messages": [{"role": "user", "content": user}]}
    headers = {"x-api-key": API_KEY, "anthropic-version": "2023-06-01"}
    last = ""
    for attempt in range(3):  # إعادة المحاولة عند الضغط/الأخطاء المؤقتة
        try:
            r = httpx.post("https://api.anthropic.com/v1/messages", json=body,
                           headers=headers, timeout=120)
        except httpx.HTTPError as e:
            last = f"تعذر الاتصال: {e}"
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
    raise HTTPException(502, last)


def ocr_image(img: Image.Image):
    img = ImageOps.autocontrast(ImageOps.exif_transpose(img).convert("L"))
    d = pytesseract.image_to_data(img, lang="ara+fra+eng", output_type=pytesseract.Output.DICT)
    lines, confs = {}, []
    for i, w in enumerate(d["text"]):
        if not w.strip():
            continue
        lines.setdefault((d["block_num"][i], d["par_num"][i], d["line_num"][i]), []).append(w)
        if float(d["conf"][i]) >= 0:
            confs.append(float(d["conf"][i]))
    return "\n".join(" ".join(v) for v in lines.values()), (sum(confs) / len(confs) if confs else 0.0)


@app.post("/api/ocr")
def ocr(files: list[UploadFile] = File(...)):
    if len(files) > MAX_FILES:
        raise HTTPException(400, f"الحد الأقصى {MAX_FILES} صور")
    texts, confs = [], []
    for f in files:
        data = f.file.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise HTTPException(413, f"الملف {f.filename} أكبر من 10MB")
        try:
            img = Image.open(io.BytesIO(data))
        except Exception:
            raise HTTPException(400, f"الملف {f.filename} ليس صورة صالحة (PDF غير مدعوم في هذه النسخة)")
        try:
            t, c = ocr_image(img)
        except pytesseract.TesseractError as e:
            raise HTTPException(500, f"فشل Tesseract (تأكد من تثبيت لغات ara/fra/eng): {e}")
        except pytesseract.TesseractNotFoundError:
            raise HTTPException(500, "Tesseract غير مثبت أو المسار TESSERACT_CMD خاطئ")
        texts.append(t)
        confs.append(c)
    mean = sum(confs) / len(confs)
    warn = ("وضوح القراءة منخفض؛ راجع النص المستخرج بعناية أو أعد تصوير الورقة."
            if mean < 70 else None)
    return {"text": "\n\n".join(texts), "mean_conf": round(mean, 1), "warning": warn}


class SolveIn(BaseModel):
    text: str = Field(min_length=5, max_length=30000)
    subject: str
    track: str
    mode: str = "model"


@app.post("/api/solve")
def solve(p: SolveIn):
    system = BASE_RULES + "\n" + MODES.get(p.mode, MODES["model"])
    user = f"الشعبة: {p.track}\nالمادة: {p.subject}\n\nنص الاختبار (مستخرج وقد يحتوي أخطاء OCR):\n{p.text}"
    ans, tin, tout = call_model(system, user)
    with closing(db()) as c:
        cur = c.execute("INSERT INTO history(created,subject,track,mode,question,answer,tokens_in,tokens_out)"
                        " VALUES(?,?,?,?,?,?,?,?)",
                        (time.time(), p.subject, p.track, p.mode, p.text, ans, tin, tout))
        c.commit()
        return {"id": cur.lastrowid, "answer": ans, "usage": {"in": tin, "out": tout}}


VERIFY = BASE_RULES + """
مهمتك الآن: مراجع مستقل. افحص الإجابة المعطاة: مطابقتها للسؤال، صحة المعلومات والحسابات،
الاقتباسات والأقوال (أي شيء لا تستطيع التأكد منه اذكره كغير موثّق)، الالتزام بالمنهجية، واكتمال الإجابة عن كل سؤال.
أخرج: (1) «ملاحظات المراجعة» بنقاط قصيرة، (2) «الإجابة المصححة» كاملة، ولا تغيّر ما هو صحيح."""


@app.post("/api/verify/{hid}")
def verify(hid: int):
    with closing(db()) as c:
        row = c.execute("SELECT * FROM history WHERE id=?", (hid,)).fetchone()
        if not row:
            raise HTTPException(404, "غير موجود")
        user = f"المادة: {row['subject']} — الشعبة: {row['track']}\n\nالأسئلة:\n{row['question']}\n\nالإجابة المراد مراجعتها:\n{row['answer']}"
        rev, tin, tout = call_model(VERIFY, user, 5000)
        c.execute("UPDATE history SET review=?, tokens_in=tokens_in+?, tokens_out=tokens_out+? WHERE id=?",
                  (rev, tin, tout, hid))
        c.commit()
    return {"id": hid, "review": rev}


@app.get("/api/history")
def history():
    with closing(db()) as c:
        rows = c.execute("SELECT id,created,subject,track,mode FROM history ORDER BY id DESC LIMIT 100").fetchall()
    return [dict(r) for r in rows]


@app.get("/api/history/{hid}")
def history_item(hid: int):
    with closing(db()) as c:
        row = c.execute("SELECT * FROM history WHERE id=?", (hid,)).fetchone()
    if not row:
        raise HTTPException(404, "غير موجود")
    return dict(row)


@app.delete("/api/history/{hid}")
def history_delete(hid: int):
    with closing(db()) as c:
        c.execute("DELETE FROM history WHERE id=?", (hid,))
        c.commit()
    return {"ok": True}
