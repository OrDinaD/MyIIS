#!/usr/bin/env python3
import os
import json
import zipfile
import io
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8080

class PassHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path in ["/api/pass", "/pass.pkpass"]:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            try:
                data = json.loads(body) if body else {}
            except Exception:
                data = {}

            last_name = data.get("lastName", "Василевский")
            first_name = data.get("firstName", "Владислав")
            middle_name = data.get("middleName", "Валерьевич")
            faculty = data.get("faculty", "ФИТУ")
            group = data.get("group", "428503")
            dorm_num = data.get("dormitoryNumber", "5")
            room_num = data.get("roomNumber", "401 - а")

            # Формируем pass.json для Apple Wallet
            pass_json = {
                "formatVersion": 1,
                "passTypeIdentifier": "pass.by.bsuir.myiis.dormitory",
                "serialNumber": f"DORM-{dorm_num}-{room_num}-{last_name}",
                "teamIdentifier": "BSUIRMYIIS",
                "webServiceURL": "https://iis.bsuir.by",
                "authenticationToken": "secrettoken123",
                "organizationName": "БГУИР",
                "description": "Пропуск в общежитие БГУИР",
                "logoText": f"Общежитие № {dorm_num}",
                "foregroundColor": "rgb(0, 0, 0)",
                "backgroundColor": "rgb(246, 237, 171)",
                "labelColor": "rgb(60, 60, 60)",
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
                            "value": "30.06.2025"
                        }
                    ]
                }
            }

            # Генерируем zip архив .pkpass
            zip_buffer = io.BytesIO()
            with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
                zf.writestr("pass.json", json.dumps(pass_json, ensure_ascii=False, indent=2))
                # Добавляем пустой манифест для тестирования структуры
                manifest = {"pass.json": "test_hash"}
                zf.writestr("manifest.json", json.dumps(manifest))

            pkpass_data = zip_buffer.getvalue()

            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.apple.pkpass")
            self.send_header("Content-Disposition", 'attachment; filename="dormitory.pkpass"')
            self.send_header("Content-Length", str(len(pkpass_data)))
            self.end_headers()
            self.wfile.write(pkpass_data)
        else:
            self.send_error(404, "Not Found")

    def do_GET(self):
        if self.path in ["/", "/health"]:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "service": "MyIIS Pass Backend"}).encode('utf-8'))
        else:
            self.send_error(404, "Not Found")

def run():
    server_address = ('', PORT)
    httpd = HTTPServer(server_address, PassHandler)
    print(f"🚀 Локальный сервер подписи Wallet карт запущен на http://localhost:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nСервер остановлен.")

if __name__ == "__main__":
    run()
