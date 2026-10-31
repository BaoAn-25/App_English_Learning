import io
import json
import sqlite3
import sys

sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8', errors='replace')
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
connections = {}


def execute(method, args):
    if method == "getDatabasesPath":
        return ":memory:"
    if method == "openDatabase":
        identifier = len(connections) + 1
        connections[identifier] = sqlite3.connect(":memory:", isolation_level=None)
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
