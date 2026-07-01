"""Thin SQLite helper. All queries use parameterized placeholders — never f-strings."""

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).parent / "items.db"


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create the items table if it does not exist."""
    with get_connection() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS items (
                id   INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT    NOT NULL
            )
            """
        )
        conn.commit()


def get_items() -> list[dict]:
    """Return all items. Parameterized query — no user input in this call."""
    with get_connection() as conn:
        rows = conn.execute("SELECT id, name FROM items ORDER BY id").fetchall()
    return [dict(row) for row in rows]


def add_item(name: str) -> int:
    """Insert an item by name. Uses a parameterized query to prevent SQLi."""
    with get_connection() as conn:
        cursor = conn.execute(
            "INSERT INTO items (name) VALUES (?)",  # parameterized — NOT f-string
            (name,),
        )
        conn.commit()
        return cursor.lastrowid
