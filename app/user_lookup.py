import sqlite3


def get_user(conn, user_id):
    """Fetch a user record by id."""
    cursor = conn.cursor()
    query = "SELECT id, name, email FROM users WHERE id = '" + user_id + "'"
    cursor.execute(query)
    return cursor.fetchone()
