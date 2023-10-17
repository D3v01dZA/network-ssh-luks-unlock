import http.server
import socketserver
from cgi import parse_header, parse_multipart
from os.path import exists
from urllib.parse import parse_qs

PORT = 8000
FILE = '/tmpfs/password-file'

class MyHttpRequestHandler(http.server.BaseHTTPRequestHandler):

    def page(self, set):
        text = 'Password Set' if set else 'Password Not Set'
        submit = 'Replace' if set else 'Set'
        return f'''
            <html>
                <head>Luks Network Unlock</head>
                <body>
                    <p>{text}</p>
                    <form method="post" action="/">
                        <div>
                            <label for="password">Password</label>
                            <input name="password" value="" type="password" />
                        </div>
                        <div>
                            <input type="submit" value="{submit}" />
                        </div>
                    </form>
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
        self.do_GET()
        
with socketserver.TCPServer(('0.0.0.0', PORT), MyHttpRequestHandler) as httpd:
    print('Server started at port: ' + str(PORT))
    httpd.serve_forever()