import io
import json
import sqlite3
import sys

sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8', errors='replace')
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
connections = {}
database_directory = sys.argv[1] if len(sys.argv) > 1 else None
next_identifier = 0


def execute(method, args):
    global next_identifier
    if method == "getDatabasesPath":
        return database_directory or ":memory:"
    if method == "openDatabase":
        next_identifier += 1
        identifier = next_identifier
        path = args["path"] if database_directory else ":memory:"
        connections[identifier] = sqlite3.connect(path, isolation_level=None)
        return identifier
    if method == "closeDatabase":
        connections.pop(args["id"]).close()
        return None
    if method == "options":
        return None
    db = connections[args["id"]]
    if method == "batch":
        results = []
        for operation in args["operations"]:
            result = execute(operation["method"], {**operation, "id": args["id"]})
            results.append({"result": result})
        return None if args.get("noResult") else results
    cursor = db.execute(args["sql"], args.get("arguments") or [])
    if method == "query":
        return {"columns": [column[0] for column in cursor.description], "rows": cursor.fetchall()}
    if method == "insert":
        return cursor.lastrowid
    if method == "update":
        return cursor.rowcount
    if method == "execute":
        return None
    raise ValueError(f"Unsupported sqflite method: {method}")


for line in sys.stdin:
    request = json.loads(line)
    try:
        response = {"id": request["id"], "result": execute(request["method"], request.get("args") or {})}
    except Exception as error:
        response = {"id": request["id"], "error": str(error)}
    print(json.dumps(response), flush=True)
