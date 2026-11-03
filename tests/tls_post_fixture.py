"""One-request loopback TLS fixture; only used by the optional integration test."""
import socket, ssl, sys
port, cert, key = int(sys.argv[1]), sys.argv[2], sys.argv[3]
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(cert, key)
with socket.socket() as listener:
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", port))
    listener.listen(1)
    raw, _ = listener.accept()
    with ctx.wrap_socket(raw, server_side=True) as conn:
        data = b""
        while b"\r\n\r\n" not in data:
            part = conn.recv(4096)
            if not part:
                raise RuntimeError("incomplete HTTP request")
            data += part
        headers, body = data.split(b"\r\n\r\n", 1)
        length = next((int(line.split(b":", 1)[1].strip()) for line in headers.split(b"\r\n") if line.lower().startswith(b"content-length:")), 0)
        while len(body) < length:
            body += conn.recv(4096)
        valid = headers.startswith(b"POST /ping ") and body == b"test=value"
        response = b"POST-OK" if valid else b"INVALID"
        conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: " + str(len(response)).encode() + b"\r\nConnection: close\r\n\r\n" + response)
