"""قاعدة البيانات (SQLite + FTS5). لا تعتمد على FastAPI حتى يسهل اختبارها."""
import os
import sqlite3
from contextlib import closing

DATA_DIR = os.getenv("SOFYAN_DATA_DIR", "./data")
DB_PATH = os.getenv("SOFYAN_DB", os.path.join(DATA_DIR, "sofyan.db"))
LIB_DIR = os.path.join(DATA_DIR, "library")

SCHEMA = """
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT UNIQUE NOT NULL, name TEXT NOT NULL,
  pw_hash TEXT NOT NULL, created REAL NOT NULL);
CREATE TABLE IF NOT EXISTS history(
  id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, created REAL, subject TEXT, track TEXT,
  task TEXT DEFAULT 'exam', mode TEXT, question TEXT, answer TEXT, review TEXT,
  sources TEXT, review_sources TEXT, tokens_in INT, tokens_out INT);
CREATE TABLE IF NOT EXISTS documents(
  id INTEGER PRIMARY KEY AUTOINCREMENT, owner_id INTEGER NOT NULL, shared INTEGER NOT NULL DEFAULT 0,
  title TEXT NOT NULL, subject TEXT, track TEXT, year TEXT, source_note TEXT,
  filename TEXT, pages INTEGER DEFAULT 0, chunks INTEGER DEFAULT 0, created REAL NOT NULL);
CREATE TABLE IF NOT EXISTS chunks(
  id INTEGER PRIMARY KEY AUTOINCREMENT, doc_id INTEGER NOT NULL, page INTEGER, text TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(doc_id);
CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(norm, tokenize='unicode61');
"""

# أعمدة أضيفت بعد نسخة MVP الأصلية: تُضاف لقواعد بيانات قديمة إن لزم.
MIGRATIONS = [
    ("history", "user_id", "INTEGER"),
    ("history", "task", "TEXT DEFAULT 'exam'"),
    ("history", "sources", "TEXT"),
    ("history", "review_sources", "TEXT"),
]


def connect(path: str | None = None) -> sqlite3.Connection:
    p = path or DB_PATH
    if p != ":memory:":
        os.makedirs(os.path.dirname(os.path.abspath(p)), exist_ok=True)
    c = sqlite3.connect(p, timeout=30)
    c.row_factory = sqlite3.Row
    return c


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA)
    for table, col, decl in MIGRATIONS:
        cols = {r["name"] for r in conn.execute(f"PRAGMA table_info({table})")}
        if col not in cols:
            conn.execute(f"ALTER TABLE {table} ADD COLUMN {col} {decl}")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_history_user ON history(user_id, id)")
    conn.commit()


def init_default() -> None:
    os.makedirs(LIB_DIR, exist_ok=True)
    with closing(connect()) as c:
        c.execute("PRAGMA journal_mode=WAL")
        init_db(c)
