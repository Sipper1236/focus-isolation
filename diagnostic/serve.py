"""Local static observer only. No uploads, page-content collection, or licensing."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Do not retain URLs or request headers.

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()


if __name__ == '__main__':
    handler = partial(Handler, directory=str(Path(__file__).parent))
    server = ThreadingHTTPServer(('127.0.0.1', 8765), handler)
    print('Observer: http://127.0.0.1:8765 (run inside guest for VM tests)')
    server.serve_forever()
