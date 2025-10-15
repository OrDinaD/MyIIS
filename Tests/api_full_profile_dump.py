#!/usr/bin/env python3
"""
Полный дамп всех данных профиля из API
"""

import requests
import json
import os

USERNAME = "42850012"
PASSWORD = "Bsuirinyouv.12_"
BASE_URL = "https://iis.bsuir.by/api/v1"

def main():
    print("=" * 80)
    print("🔍 ПОЛНЫЙ ДАМП ВСЕХ ДАННЫХ ПРОФИЛЯ")
    print("=" * 80)
    
    session = requests.Session()
    
    # Аутентификация
    print("\n📝 Аутентификация...")
    login_response = session.post(
        f"{BASE_URL}/auth/login",
        json={"username": USERNAME, "password": PASSWORD},
        headers={"Content-Type": "application/json"}
    )
    
    if login_response.status_code != 200:
        print(f"❌ Ошибка: {login_response.status_code}")
        return
    
    print("✅ Успешно!")
    login_data = login_response.json()
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 1. Login Response
    print("\n" + "=" * 80)
    print("1️⃣  LOGIN RESPONSE (/auth/login)")
    print("=" * 80)
    print(json.dumps(login_data, ensure_ascii=False, indent=2))
    
    # 2. Personal Information
    print("\n" + "=" * 80)
    print("2️⃣  PERSONAL INFORMATION (/personal-information)")
    print("=" * 80)
    personal_response = session.get(f"{BASE_URL}/personal-information")
    if personal_response.status_code == 200:
        personal_data = personal_response.json()
        print(json.dumps(personal_data, ensure_ascii=False, indent=2))
        
        # Сохраняем
        with open(os.path.join(script_dir, "full_personal_info.json"), "w", encoding="utf-8") as f:
            json.dump(personal_data, f, ensure_ascii=False, indent=2)
    else:
        print(f"❌ Ошибка: {personal_response.status_code}")
    
    # 3. Schedule Info
    print("\n" + "=" * 80)
    print("3️⃣  SCHEDULE INFO (/schedule?studentGroup=420603)")
    print("=" * 80)
    schedule_response = session.get(f"{BASE_URL}/schedule?studentGroup=420603")
    if schedule_response.status_code == 200:
        schedule_data = schedule_response.json()
        print("studentGroupDto:")
        print(json.dumps(schedule_data.get("studentGroupDto"), ensure_ascii=False, indent=2))
    else:
        print(f"❌ Ошибка: {schedule_response.status_code}")
    
    # 4. Проверка дополнительных эндпоинтов для даты рождения
    print("\n" + "=" * 80)
    print("4️⃣  ПОИСК ДАТЫ РОЖДЕНИЯ В ДРУГИХ ЭНДПОИНТАХ")
    print("=" * 80)
    
    endpoints_with_birthdate = [
        "/profile",
        "/me",
        "/user/profile",
        "/student/info",
        "/personal-info",
        "/user-info",
        "/account/info",
    ]
    
    for endpoint in endpoints_with_birthdate:
        try:
            resp = session.get(f"{BASE_URL}{endpoint}", timeout=3)
            if resp.status_code == 200:
                data = resp.json()
                print(f"\n✅ {endpoint}:")
                # Ищем дату рождения
                if isinstance(data, dict):
                    for key, value in data.items():
                        if 'birth' in key.lower() or 'day' in key.lower():
                            print(f"   🎯 {key}: {value}")
                    # Показываем первые 5 ключей
                    keys = list(data.keys())[:10]
                    print(f"   Keys: {keys}")
        except:
            pass
    
    print("\n" + "=" * 80)
    print("✅ ГОТОВО! Все данные собраны.")
    print("=" * 80)

if __name__ == "__main__":
    main()
