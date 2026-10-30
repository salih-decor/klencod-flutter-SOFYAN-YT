"""اختبارات المنطق الأساسي (لا تحتاج FastAPI ولا مفاتيح API). التشغيل:  python -m unittest discover -s tests -v"""
import os
import sqlite3
import sys
import time
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
os.environ.setdefault("OCR_LANGS", "eng")  # في الاختبار نحتاج eng فقط

import db as dbm  # noqa: E402
import prompts  # noqa: E402
import rag  # noqa: E402
import security as sec  # noqa: E402


def fresh():
    c = dbm.connect(":memory:")
    dbm.init_db(c)
    return c


class RagTests(unittest.TestCase):
    def test_normalize_arabic(self):
        self.assertEqual(rag.normalize("الفَلْسَفَةُ"), "الفلسفه")
        self.assertEqual(rag.normalize("أَحْمَد إبراهيم آمن"), "احمد ابراهيم امن")
        self.assertEqual(rag.normalize("Révolution"), "revolution")

    def test_stem_prefix(self):
        self.assertEqual(rag.tokens("الثورة"), ["ثوره"])
        self.assertIn("ثوره", rag.tokens("للثورة"))
        self.assertEqual(rag.tokens("و في"), ["في"])  # الحرف المفرد يُهمل

    def test_chunking(self):
        text = "\n\n".join(f"فقرة رقم {i} " + "كلمة " * 80 for i in range(10))
        chunks = rag.chunk_text(text, size=900, overlap=100)
        self.assertGreater(len(chunks), 2)
        self.assertTrue(all(len(c) <= 1200 for c in chunks))
        self.assertEqual(rag.chunk_text("   \n\n  "), [])

    def test_add_search_scope_and_delete(self):
        c = fresh()
        meta = {"title": "ملف أ", "subject": "التاريخ", "filename": "a.pdf"}
        d1, n1 = rag.add_document(c, 1, False, meta, ["اندلعت الثورة التحريرية الجزائرية في الفاتح من نوفمبر 1954", "نص آخر عن الجغرافيا"])
        self.assertGreater(n1, 0)
        hits = rag.search(c, 1, "الثورة التحريرية")
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["page"], 1)
        # مستخدم آخر لا يرى الملف الخاص
        self.assertEqual(rag.search(c, 2, "الثورة التحريرية"), [])
        # ملف مشترك يراه الجميع
        d2, _ = rag.add_document(c, 1, True, {"title": "مشترك", "subject": "التاريخ"}, ["معاهدة إيفيان وقف إطلاق النار 1962"])
        self.assertEqual(len(rag.search(c, 2, "معاهدة ايفيان")), 1)
        self.assertEqual(len(rag.list_documents(c, 2)), 1)
        # مرشّح المادة
        self.assertEqual(rag.search(c, 1, "الثورة", subject="الرياضيات"), [])
        self.assertEqual(len(rag.search(c, 1, "الثورة", subject="التاريخ")), 1)
        # الحذف يزيل الفهرس
        rag.delete_document(c, d1)
        self.assertEqual(rag.search(c, 1, "الثورة التحريرية"), [])
        self.assertEqual(c.execute("SELECT COUNT(*) FROM chunks_fts").fetchone()[0], 1)

    def test_query_injection_safe(self):
        c = fresh()
        rag.add_document(c, 1, False, {"title": "t"}, ["hello world"])
        # رموز FTS الخاصة لا تكسر الاستعلام
        self.assertIsInstance(rag.search(c, 1, 'hello" OR NEAR( * ) -x'), list)
        self.assertEqual(rag.search(c, 1, "!!! ???"), [])

    def test_sources_and_block(self):
        c = fresh()
        rag.add_document(c, 1, False, {"title": "كتاب", "source_note": "مصدر تجريبي"}, ["alpha beta gamma"])
        src = rag.make_sources(rag.search(c, 1, "alpha"))
        self.assertEqual(src[0]["ref"], "م1")
        self.assertIn("[م1] «كتاب»", rag.passages_block(src))
        self.assertEqual(rag.passages_block([]), "")


class SecurityTests(unittest.TestCase):
    def test_password(self):
        h = sec.hash_password("كلمة-سر-قوية-123")
        self.assertTrue(sec.verify_password("كلمة-سر-قوية-123", h))
        self.assertFalse(sec.verify_password("خطأ", h))
        self.assertFalse(sec.verify_password("x", "garbage"))

    def test_token(self):
        t = sec.make_token(7, "s3cret")
        self.assertEqual(sec.decode_token(t, "s3cret"), 7)
        with self.assertRaises(Exception):
            sec.decode_token(t, "other")
        with self.assertRaises(Exception):
            sec.decode_token(sec.make_token(7, "s3cret", days=-1), "s3cret")

    def test_email(self):
        self.assertTrue(sec.valid_email("a@b.dz"))
        self.assertFalse(sec.valid_email("a@b"))
        self.assertEqual(sec.normalize_email("  A@B.DZ "), "a@b.dz")

    def test_limiter(self):
        l = sec.LoginLimiter(max_fail=3, window=100)
        for _ in range(3):
            l.fail("k", now=1000)
        self.assertTrue(l.blocked("k", now=1010))
        self.assertFalse(l.blocked("k", now=1200))
        l.reset("k")
        self.assertFalse(l.blocked("k", now=1010))


class DbTests(unittest.TestCase):
    def test_migrate_original_mvp_db(self):
        c = sqlite3.connect(":memory:")
        c.row_factory = sqlite3.Row
        c.execute("""CREATE TABLE history(id INTEGER PRIMARY KEY AUTOINCREMENT, created REAL, subject TEXT, track TEXT,
            mode TEXT, question TEXT, answer TEXT, review TEXT, tokens_in INT, tokens_out INT)""")
        c.execute("INSERT INTO history(created,subject,track,mode,question,answer) VALUES(1,'الفلسفة','x','model','q','a')")
        dbm.init_db(c)
        cols = {r["name"] for r in c.execute("PRAGMA table_info(history)")}
        self.assertTrue({"user_id", "task", "sources", "review_sources"} <= cols)
        dbm.init_db(c)  # idempotent


class PromptTests(unittest.TestCase):
    def test_every_task_has_prompt(self):
        for k in ("exam", "phil_text", "phil_essay", "phil_wad", "phil_raf", "lit_text"):
            self.assertIn(k, prompts.TASKS)
            self.assertIn("المهمة", prompts.system_for(k, "الفلسفة", "model"))

    def test_rag_context(self):
        self.assertEqual(prompts.rag_context([], "", False), "")
        self.assertIn("لم يُعثر", prompts.rag_context([], "", True))
        s = [{"ref": "م1", "title": "t", "page": 1, "text": "x"}]
        self.assertIn("[م1]", prompts.rag_context(s, "[م1] x", True))


class OcrTests(unittest.TestCase):
    def test_english_ocr_roundtrip(self):
        try:
            import pytesseract
            from PIL import Image, ImageDraw, ImageFont
            import ocr
            pytesseract.get_tesseract_version()
        except Exception as e:  # pragma: no cover
            self.skipTest(f"Tesseract/PIL غير متاح: {e}")
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 48) if os.path.exists(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf") else ImageFont.load_default()
        img = Image.new("RGB", (900, 160), "white")
        ImageDraw.Draw(img).text((20, 40), "Baccalaureat 2026 Algeria", fill="black", font=font)
        text, conf = ocr.ocr_image(img)
        self.assertIn("2026", text)
        self.assertGreater(conf, 50)
        self.assertFalse(ocr.is_pdf(b"\x89PNG"))
        self.assertTrue(ocr.is_pdf(b"%PDF-1.7"))


if __name__ == "__main__":
    unittest.main()
