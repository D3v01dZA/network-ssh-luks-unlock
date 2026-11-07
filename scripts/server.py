import http.server
import socketserver
from cgi import parse_header, parse_multipart
from os.path import exists
from urllib.parse import parse_qs
import json

PORT = 8000
FILE = '/tmpfs/password-file'
TOKEN_FILE = '/tmpfs/token-file'

class MyHttpRequestHandler(http.server.BaseHTTPRequestHandler):

    def page(self, set):
        text = 'Password Set' if set else 'Password Not Set'
        status = 'set' if set else 'unset'
        submit = 'Replace' if set else 'Set'
        return f'''
            <!doctype html>
            <html>
                <head>
                    <meta charset="utf-8" />
                    <meta name="viewport" content="width=device-width, initial-scale=1" />
                    <title>Luks Network Unlock</title>
                    <style>
                        body {{ font-family: system-ui, sans-serif; background: #f2f2f2; color: #222; margin: 0; padding: 16px; }}
                        main {{ max-width: 360px; margin: 48px auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 24px; }}
                        h1 {{ font-size: 20px; margin: 0 0 16px; }}
                        .status {{ padding: 8px 12px; border-radius: 4px; margin: 0 0 16px; }}
                        .set {{ background: #e3f4e5; color: #1d6b2a; }}
                        .unset {{ background: #fbe9e7; color: #a12a1a; }}
                        label {{ display: block; margin-bottom: 4px; }}
                        input[type=password] {{ width: 100%; box-sizing: border-box; padding: 8px; border: 1px solid #bbb; border-radius: 4px; margin-bottom: 16px; }}
                        input[type=submit] {{ padding: 8px 16px; border: 0; border-radius: 4px; background: #2b5797; color: #fff; cursor: pointer; }}
                    </style>
                </head>
                <body>
                    <main>
                        <h1>Luks Network Unlock</h1>
                        <p class="status {status}">{text}</p>
                        <form method="post" action="/">
                            <label for="password">Password</label>
                            <input id="password" name="password" value="" type="password" />
                            <input type="submit" value="{submit}" />
                        </form>
                    </main>
                </body>
            </html>
        '''.encode('ascii')
    
    def parse_POST(self):
        ctype, pdict = parse_header(self.headers['content-type'])
        if ctype == 'multipart/form-data':
            postvars = parse_multipart(self.rfile, pdict)
        elif ctype == 'application/x-www-form-urlencoded':
            length = int(self.headers['content-length'])
            postvars = parse_qs(
                    self.rfile.read(length), 
                    keep_blank_values=1
            )
        else:
            postvars = {}
        return postvars

    def do_GET(self):
        if self.path == '/token':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            with open(TOKEN_FILE, 'r', encoding='utf-8') as f:
                content = f.read()
            response = {
                "token": content.strip()
            }
            response_bytes = json.dumps(response).encode('utf-8')
            self.wfile.write(response_bytes)
        elif self.path == '/exists':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "exists": exists(FILE)
            }
            response_bytes = json.dumps(response).encode('utf-8')
            self.wfile.write(response_bytes)
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.page(exists(FILE)))

    def do_POST(self):
        postvars = self.parse_POST()
        print('Reading password from headers')
        password = ''.join(str.decode('utf-8') for str in postvars[b'password'])
        print('Writing password to file')
        file = open(FILE, 'w')
        file.write(password)
        file.close()
        if self.path == '/password':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "success": True
            }
            response_bytes = json.dumps(response).encode('utf-8')
            self.wfile.write(response_bytes)
        else:
            self.do_GET()
        
with socketserver.TCPServer(('0.0.0.0', PORT), MyHttpRequestHandler) as httpd:
    print('Server started at port: ' + str(PORT))
    httpd.serve_forever()
