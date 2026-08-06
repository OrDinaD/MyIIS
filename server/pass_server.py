#!/usr/bin/env python3
import os
import sys
import json
import time
import hashlib
import zipfile
import subprocess
import tempfile
import io
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8080
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CERTS_DIR = os.path.join(BASE_DIR, "certs")
ASSETS_DIR = os.path.join(BASE_DIR, "assets")

class PassHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_POST(self):
        if self.path in ["/api/pass", "/pass.pkpass", "/"]:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else b"{}"
            
            try:
                data = json.loads(body.decode('utf-8'))
            except Exception:
                data = {}

            last_name = data.get("lastName", "Василевский")
            first_name = data.get("firstName", "Владислав")
            middle_name = data.get("middleName", "Валерьевич")
            faculty = data.get("faculty", "ФИТУ")
            group = data.get("group", "428503")
            dorm_num = data.get("dormitoryNumber", "5")
            room_num = data.get("roomNumber", "2002А")

            timestamp = int(time.time())

            pass_json = {
                "formatVersion": 1,
                "passTypeIdentifier": "pass.by.bsuir.myiis.dormitory",
                "serialNumber": f"DORM-{dorm_num}-{room_num}-{timestamp}",
                "teamIdentifier": "Y85TSUMM4F",
                "organizationName": "БГУИР",
                "description": "Пропуск в общежитие БГУИР",
                "logoText": f"Общежитие № {dorm_num}",
                "foregroundColor": "rgb(0, 0, 0)",
                "backgroundColor": "rgb(246, 237, 171)",
                "labelColor": "rgb(40, 40, 40)",
                "generic": {
                    "headerFields": [
                        {
                            "key": "room",
                            "label": "КОМНАТА",
                            "value": room_num
                        }
                    ],
                    "primaryFields": [
                        {
                            "key": "name",
                            "label": "ФИО СТУДЕНТА",
                            "value": f"{last_name} {first_name} {middle_name}"
                        }
                    ],
                    "secondaryFields": [
                        {
                            "key": "faculty",
                            "label": "ФАКУЛЬТЕТ",
                            "value": faculty
                        },
                        {
                            "key": "group",
                            "label": "ГРУППА",
                            "value": group
                        }
                    ],
                    "auxiliaryFields": [
                        {
                            "key": "validUntil",
                            "label": "ДЕЙСТВИТЕЛЬНО ДО",
                            "value": "30.06.2027"
                        }
                    ]
                }
            }

            pass_json_bytes = json.dumps(pass_json, ensure_ascii=False, indent=2).encode('utf-8')

            file_map = {
                "pass.json": pass_json_bytes
            }

            # Читаем валидные иконки из ASSETS_DIR
            asset_files = ["icon.png", "icon@2x.png", "icon@3x.png", "logo.png", "logo@2x.png"]
            for a_name in asset_files:
                a_path = os.path.join(ASSETS_DIR, a_name)
                if os.path.exists(a_path):
                    with open(a_path, "rb") as f:
                        file_map[a_name] = f.read()

            # Создаем manifest.json со всеми SHA-1 хешами
            manifest = {}
            for name, content in file_map.items():
                manifest[name] = hashlib.sha1(content).hexdigest()

            manifest_bytes = json.dumps(manifest, ensure_ascii=False, indent=2).encode('utf-8')
            file_map["manifest.json"] = manifest_bytes

            # Подписываем manifest.json через OpenSSL
            signature_bytes = self.sign_manifest(manifest_bytes)
            if signature_bytes:
                file_map["signature"] = signature_bytes

            zip_buffer = io.BytesIO()
            with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
                for name, content in file_map.items():
                    zf.writestr(name, content)

            pkpass_data = zip_buffer.getvalue()

            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/vnd.apple.pkpass")
            self.send_header("Content-Disposition", 'attachment; filename="dormitory.pkpass"')
            self.send_header("Content-Length", str(len(pkpass_data)))
            self.end_headers()
            self.wfile.write(pkpass_data)
        else:
            self.send_error(404, "Not Found")

    def sign_manifest(self, manifest_bytes):
        pass_cert = os.path.join(CERTS_DIR, "pass_cert.pem")
        pass_key = os.path.join(CERTS_DIR, "pass_key.pem")
        wwdr_cert = os.path.join(CERTS_DIR, "wwdr.pem")

        if not (os.path.exists(pass_cert) and os.path.exists(pass_key) and os.path.exists(wwdr_cert)):
            print("⚠️ Ошибка: Сертификаты не найдены в server/certs")
            return None

        with tempfile.NamedTemporaryFile(delete=False) as m_file:
            m_file.write(manifest_bytes)
            m_path = m_file.name

        sig_path = m_path + ".sig"

        cmd = [
            "openssl", "smime", "-sign",
            "-signer", pass_cert,
            "-inkey", pass_key,
            "-certfile", wwdr_cert,
            "-in", m_path,
            "-out", sig_path,
            "-outform", "DER",
            "-binary",
            "-nodetach"
        ]

        try:
            res = subprocess.run(cmd, capture_output=True)
            if res.returncode == 0 and os.path.exists(sig_path):
                with open(sig_path, "rb") as s_file:
                    sig_data = s_file.read()
                os.unlink(m_path)
                os.unlink(sig_path)
                return sig_data
            else:
                print(f"⚠️ Ошибка выполнения OpenSSL: {res.stderr.decode('utf-8')}")
        except Exception as e:
            print(f"⚠️ Исключение при подписи: {e}")

        if os.path.exists(m_path):
            os.unlink(m_path)
        if os.path.exists(sig_path):
            os.unlink(sig_path)
        return None

    def do_GET(self):
        if self.path in ["/", "/health", "/api/pass"]:
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "service": "MyIIS Signed Pass Backend", "port": PORT}).encode('utf-8'))
        else:
            self.send_error(404, "Not Found")

def run():
    server_address = ('0.0.0.0', PORT)
    httpd = HTTPServer(server_address, PassHandler)
    print(f"🚀 Локальный сервер подписи Wallet карт запущен на http://localhost:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nСервер остановлен.")
        sys.exit(0)

if __name__ == "__main__":
    run()
