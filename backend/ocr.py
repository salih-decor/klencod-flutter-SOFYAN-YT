"""استخراج النص: صور (Tesseract ara+fra+eng) وPDF (طبقة النص أولًا ثم OCR للصفحات الممسوحة)."""
import io
import os

import pytesseract
from PIL import Image, ImageOps

if os.getenv("TESSERACT_CMD"):
    pytesseract.pytesseract.tesseract_cmd = os.environ["TESSERACT_CMD"]

LANGS = os.getenv("OCR_LANGS", "ara+fra+eng")
MIN_TEXT_LAYER = 30  # أقل عدد حروف لاعتبار صفحة PDF ذات نص حقيقي


def ocr_image(img: Image.Image):
    img = ImageOps.autocontrast(ImageOps.exif_transpose(img).convert("L"))
    d = pytesseract.image_to_data(img, lang=LANGS, output_type=pytesseract.Output.DICT)
    lines, confs = {}, []
    for i, w in enumerate(d["text"]):
        if not w.strip():
            continue
        lines.setdefault((d["block_num"][i], d["par_num"][i], d["line_num"][i]), []).append(w)
        if float(d["conf"][i]) >= 0:
            confs.append(float(d["conf"][i]))
    return "\n".join(" ".join(v) for v in lines.values()), (sum(confs) / len(confs) if confs else 0.0)


def is_pdf(data: bytes) -> bool:
    return data[:5] == b"%PDF-"


def pdf_pages(data: bytes, max_pages: int = 12, max_ocr_pages: int = 12):
    """يعيد قائمة (نص_الصفحة، ثقة_OCR أو None إن كانت من طبقة النص)."""
    import fitz  # PyMuPDF — يُستورد هنا حتى لا يلزم في بيئات الاختبار
    out, ocr_used = [], 0
    with fitz.open(stream=data, filetype="pdf") as doc:
        for i, page in enumerate(doc):
            if i >= max_pages:
                break
            txt = page.get_text().strip()
            if len(txt) >= MIN_TEXT_LAYER:
                out.append((txt, None))
            elif ocr_used < max_ocr_pages:
                pix = page.get_pixmap(dpi=200)
                img = Image.open(io.BytesIO(pix.tobytes("png")))
                t, c = ocr_image(img)
                out.append((t, c))
                ocr_used += 1
            else:
                out.append(("", 0.0))
    return out


def extract(data: bytes, max_pages: int = 12):
    """يعيد (صفحات: list[str]، متوسط ثقة OCR أو None إن لم يُستعمل OCR)."""
    if is_pdf(data):
        res = pdf_pages(data, max_pages=max_pages, max_ocr_pages=max_pages)
        confs = [c for _, c in res if c is not None]
        return [t for t, _ in res], (sum(confs) / len(confs) if confs else None)
    img = Image.open(io.BytesIO(data))
    t, c = ocr_image(img)
    return [t], c
