"""Thin SQLite helper. All queries use parameterized placeholders — never f-strings."""

import sqlite3
from pathlib import Path

_DEFAULT_DB_PATH = str(Path(__file__).parent / "items.db")


def _db_path() -> str:
    """Return the database path from app config (supports :memory: in tests)."""
    from flask import current_app  # noqa: PLC0415 — intentional lazy import

    return current_app.config.get("DATABASE", _DEFAULT_DB_PATH)  # type: ignore[return-value]


def get_connection() -> sqlite3.Connection:
    path = _db_path()
    if path == ":memory:":
        # Shared-cache URI so init_db() and request handlers see the same in-memory tables
        # within the same process.  Each fresh process (new pytest session) starts clean.
        conn = sqlite3.connect(
            "file::memory:?cache=shared", uri=True, check_same_thread=False
        )
    else:
        conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create the items table if it does not exist.

    Using the connection as a context manager commits on success and rolls
    back on error, so no explicit ``commit()`` call is needed.
    """
    with get_connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS items (
                id   INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT    NOT NULL
            )
            """
        )


def get_items() -> list[dict]:
    """Return all items. Parameterized query — no user input in this call."""
    with get_connection() as conn:
        rows = conn.execute("SELECT id, name FROM items ORDER BY id").fetchall()
    return [dict(row) for row in rows]


def add_item(name: str) -> int:
    """Insert an item by name. Uses a parameterized query to prevent SQLi.

    The ``with`` block commits on exit; ``lastrowid`` is read before exit.
    """
    with get_connection() as conn:
        cursor = conn.execute(
            "INSERT INTO items (name) VALUES (?)",  # parameterized — NOT f-string
            (name,),
        )
        return cursor.lastrowid
