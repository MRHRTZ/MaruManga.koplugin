"""Four-request, loopback-only HTTPS fixture for MangaDex browsing."""
import json, os, socket, ssl, sys
port, cert, key = int(sys.argv[1]), sys.argv[2], sys.argv[3]
mid = "01234567-89ab-cdef-0123-456789abcdef"
cid = "12345678-89ab-cdef-0123-456789abcdef"
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(cert, key)
with socket.socket() as listener:
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", port)); listener.listen(4)
    for _ in range(8 if os.getenv("TEST_FULL") == "1" else 4):
        raw, _ = listener.accept()
        with ctx.wrap_socket(raw, server_side=True) as conn:
            data = b""
            while b"\r\n\r\n" not in data:
                part = conn.recv(8192)
                if not part: raise RuntimeError("incomplete request")
                data += part
            header, incoming = data.split(b"\r\n\r\n", 1)
            length = next((int(line.split(b":", 1)[1].strip()) for line in header.split(b"\r\n") if line.lower().startswith(b"content-length:")), 0)
            while len(incoming) < length:
                incoming += conn.recv(8192)
            path = data.split(b" ", 2)[1].decode("ascii")
            manga = {"id": mid, "attributes": {"title": {"en": "Fixture"}, "description": {"en": "Description"}}, "relationships": []}
            if path.startswith("/manga?"):
                result = {"data": [manga], "offset": 0, "total": 1}
            elif path.startswith("/manga/" + mid + "/feed?"):
                result = {"data": [{"id": cid, "attributes": {"chapter": "1"}, "relationships": [{"type": "scanlation_group", "attributes": {"name": "Group"}}]}], "offset": 0, "total": 1}
            elif path.startswith("/manga/" + mid + "?"):
                result = {"data": manga}
            elif path == "/at-home/server/" + cid:
                result = {"baseUrl": "https://node.mangadex.network:12345/token", "chapter": {"hash": "ab12", "data": ["1.jpg", "2.jpg"]}}
            elif path.startswith("/token/data/ab12/"):
                result = None
            elif path == "/report":
                report=json.loads(incoming)
                assert report["success"] is True and report["bytes"] > 0
                result = {}
            else:
                raise RuntimeError("unexpected path: " + path)
            body = b"\xff\xd8\xfffixture" if result is None else json.dumps(result).encode()
            mime = b"image/jpeg" if result is None else b"application/json"
            conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Type: " + mime + b"\r\nContent-Length: " + str(len(body)).encode() + b"\r\nConnection: close\r\n\r\n" + body)
