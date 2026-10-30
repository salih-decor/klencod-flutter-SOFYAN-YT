"""نظام بحث RAG بسيط وصادق: فهرسة نصوص الملفات + استرجاع BM25 (SQLite FTS5).

- لا يستخدم embeddings، لذلك هو بحث بالكلمات (مع تطبيع عربي وتجذيع خفيف) لا بحث دلالي.
- لا يحتوي أي مراجع جاهزة: لا يعرف إلا الملفات التي تُرفع إلى المكتبة.
"""
import json
import re
import time
import unicodedata

_TOKEN = re.compile(r"\w+", re.UNICODE)
_PREFIXES = ("وال", "بال", "كال", "فال", "لل", "ال")


def normalize(text: str) -> str:
    t = unicodedata.normalize("NFKD", text)  # يفكّك أشكال العرض العربية ويفصل التشكيل/اللكنات
    t = "".join(ch for ch in t if unicodedata.category(ch) != "Mn" and ch != "\u0640")
    return t.replace("ى", "ي").replace("ة", "ه").lower()


def _stem(tok: str) -> str:
    for p in _PREFIXES:
        if tok.startswith(p) and len(tok) - len(p) >= 3:
            return tok[len(p):]
    return tok


def tokens(text: str) -> list[str]:
    return [_stem(t) for t in _TOKEN.findall(normalize(text)) if len(t) >= 2]


def fts_query(text: str, max_terms: int = 24) -> str:
    seen, out = set(), []
    for t in tokens(text):
        if t not in seen:
            seen.add(t)
            out.append('"' + t.replace('"', '') + '"')
        if len(out) >= max_terms:
            break
    return " OR ".join(out)


def chunk_text(text: str, size: int = 900, overlap: int = 150) -> list[str]:
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    pieces: list[str] = []
    for p in paras:
        while len(p) > size:
            cut = p.rfind(" ", 0, size)
            cut = cut if cut > size // 2 else size
            pieces.append(p[:cut].strip())
            p = p[cut:].strip()
        if p:
            pieces.append(p)
    chunks, cur = [], ""
    for p in pieces:
        if cur and len(cur) + len(p) + 1 > size:
            chunks.append(cur)
            tail = cur[-overlap:]
            sp = tail.find(" ")
            cur = (tail[sp + 1:] if sp != -1 else tail) + " " + p
        else:
            cur = (cur + "\n" + p) if cur else p
    if cur.strip():
        chunks.append(cur)
    return chunks


def add_document(conn, owner_id: int, shared: bool, meta: dict, pages: list[str]) -> tuple[int, int]:
    """pages: نص كل صفحة (قائمة). يعيد (doc_id, عدد المقاطع)."""
    cur = conn.execute(
        "INSERT INTO documents(owner_id,shared,title,subject,track,year,source_note,filename,pages,created)"
        " VALUES(?,?,?,?,?,?,?,?,?,?)",
        (owner_id, 1 if shared else 0, meta["title"], meta.get("subject") or None, meta.get("track") or None,
         meta.get("year") or None, meta.get("source_note") or None, meta.get("filename"), len(pages), time.time()))
    doc_id, n = cur.lastrowid, 0
    for pno, ptxt in enumerate(pages, start=1):
        for ch in chunk_text(ptxt):
            norm = " ".join(tokens(ch))
            if not norm:
                continue
            c = conn.execute("INSERT INTO chunks(doc_id,page,text) VALUES(?,?,?)", (doc_id, pno, ch))
            conn.execute("INSERT INTO chunks_fts(rowid,norm) VALUES(?,?)", (c.lastrowid, norm))
            n += 1
    conn.execute("UPDATE documents SET chunks=? WHERE id=?", (n, doc_id))
    conn.commit()
    return doc_id, n


def delete_document(conn, doc_id: int) -> None:
    ids = [r[0] for r in conn.execute("SELECT id FROM chunks WHERE doc_id=?", (doc_id,))]
    for i in ids:
        conn.execute("DELETE FROM chunks_fts WHERE rowid=?", (i,))
    conn.execute("DELETE FROM chunks WHERE doc_id=?", (doc_id,))
    conn.execute("DELETE FROM documents WHERE id=?", (doc_id,))
    conn.commit()


def list_documents(conn, user_id: int) -> list[dict]:
    rows = conn.execute(
        "SELECT id,owner_id,shared,title,subject,track,year,source_note,pages,chunks,created FROM documents"
        " WHERE shared=1 OR owner_id=? ORDER BY id DESC", (user_id,)).fetchall()
    return [{**dict(r), "shared": bool(r["shared"]), "mine": r["owner_id"] == user_id} for r in rows]


def search(conn, user_id: int, query: str, limit: int = 6, subject: str | None = None) -> list[dict]:
    q = fts_query(query)
    if not q:
        return []
    sql = ("SELECT c.id, c.doc_id, c.page, c.text, d.title, d.subject, d.year, d.source_note, bm25(chunks_fts) AS score"
           " FROM chunks_fts JOIN chunks c ON c.id = chunks_fts.rowid JOIN documents d ON d.id = c.doc_id"
           " WHERE chunks_fts MATCH ? AND (d.shared=1 OR d.owner_id=?)")
    args: list = [q, user_id]
    if subject and subject != "مادة أخرى":
        sql += " AND (d.subject IS NULL OR d.subject=''  OR d.subject=?)"
        args.append(subject)
    sql += " ORDER BY score LIMIT ?"
    args.append(limit)
    return [dict(r) for r in conn.execute(sql, args).fetchall()]


def make_sources(hits: list[dict], max_chars: int = 900) -> list[dict]:
    return [{"ref": f"م{i}", "doc_id": h["doc_id"], "title": h["title"], "page": h["page"],
             "year": h.get("year"), "source_note": h.get("source_note"), "text": h["text"][:max_chars]}
            for i, h in enumerate(hits, start=1)]


def passages_block(sources: list[dict]) -> str:
    if not sources:
        return ""
    parts = []
    for s in sources:
        head = f"[{s['ref']}] «{s['title']}»" + (f" — ص{s['page']}" if s.get("page") else "")
        if s.get("source_note"):
            head += f" — {s['source_note']}"
        parts.append(f"{head}\n{s['text']}")
    return "\n\n".join(parts)


def sources_json(sources: list[dict]) -> str:
    return json.dumps(sources, ensure_ascii=False)
