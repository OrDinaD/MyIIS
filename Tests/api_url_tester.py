#!/usr/bin/env python3
"""
Тестирование различных URL эндпоинтов API БГУИР для аутентификации
"""

import requests
import json
from typing import Dict, Tuple

# Учетные данные для тестирования
USERNAME = "42850012"
PASSWORD = "Bsuirinyouv.12_"

# Список возможных базовых URL и путей
BASE_URLS = [
    "https://iis.bsuir.by/api/v1",
    "https://iis.bsuir.by/api",
    "https://iis.bsuir.by",
    "https://api.bsuir.by/v1",
    "https://api.bsuir.by",
    "https://students.bsuir.by/api/v1",
    "https://students.bsuir.by/api",
]

AUTH_PATHS = [
    "/auth",
    "/auth/login",
    "/login",
    "/authentication",
    "/authenticate",
]

def test_auth_endpoint(base_url: str, path: str) -> Tuple[bool, int, Dict]:
    """
    Тестирует эндпоинт аутентификации
    
    Returns:
        (success, status_code, response_data)
    """
    full_url = f"{base_url}{path}"
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    
    payload = {
        "username": USERNAME,
        "password": PASSWORD
    }
    
    print(f"\n🔍 Тестирую: {full_url}")
    print(f"   Payload: {json.dumps(payload, ensure_ascii=False)}")
    
    try:
        response = requests.post(
            full_url,
            json=payload,
            headers=headers,
            timeout=10,
            verify=True
        )
        
        status_code = response.status_code
        
        try:
            response_data = response.json()
        except:
            response_data = {"raw": response.text[:200]}
        
        print(f"   Status: {status_code}")
        
        # Проверяем cookies
        if response.cookies:
            print(f"   🍪 Cookies: {dict(response.cookies)}")
            response_data["_cookies"] = dict(response.cookies)
        
        # Проверяем headers
        auth_headers = {}
        for header_name in ['Authorization', 'X-Auth-Token', 'X-Token', 'Set-Cookie']:
            if header_name in response.headers:
                auth_headers[header_name] = response.headers[header_name]
        
        if auth_headers:
            print(f"   🔑 Auth Headers: {auth_headers}")
            response_data["_headers"] = auth_headers
        
        print(f"   Response Body: {json.dumps(response_data, ensure_ascii=False, indent=2)[:500]}")
        
        # Успех если 200 (с токеном или без - может быть JWT в cookies)
        if status_code == 200:
            return (True, status_code, response_data)
        
        return (False, status_code, response_data)
        
    except requests.exceptions.RequestException as e:
        print(f"   ❌ Ошибка: {str(e)}")
        return (False, 0, {"error": str(e)})

def main():
    print("=" * 80)
    print("🚀 Поиск правильного API эндпоинта для аутентификации БГУИР")
    print("=" * 80)
    
    successful_endpoints = []
    
    for base_url in BASE_URLS:
        for path in AUTH_PATHS:
            success, status_code, response_data = test_auth_endpoint(base_url, path)
            
            if success:
                successful_endpoints.append({
                    "url": f"{base_url}{path}",
                    "base_url": base_url,
                    "path": path,
                    "response": response_data
                })
                print(f"   ✅ УСПЕХ! Найден рабочий эндпоинт!")
    
    print("\n" + "=" * 80)
    print("📊 РЕЗУЛЬТАТЫ")
    print("=" * 80)
    
    if successful_endpoints:
        print(f"\n✅ Найдено {len(successful_endpoints)} рабочих эндпоинта(ов):\n")
        for i, endpoint in enumerate(successful_endpoints, 1):
            print(f"{i}. URL: {endpoint['url']}")
            print(f"   Base URL: {endpoint['base_url']}")
            print(f"   Path: {endpoint['path']}")
            if "token" in endpoint["response"]:
                token = endpoint["response"]["token"]
                print(f"   Token (первые 50 символов): {token[:50]}...")
            print()
        
        # Сохраняем результат в файл
        with open("Tests/api_test_results.json", "w", encoding="utf-8") as f:
            json.dump(successful_endpoints, f, ensure_ascii=False, indent=2)
        
        print("✅ Результаты сохранены в Tests/api_test_results.json")
        
    else:
        print("\n❌ Не найдено ни одного рабочего эндпоинта")
        print("\nВозможные причины:")
        print("  1. Требуется VPN или доступ из сети БГУИР")
        print("  2. Неверные учетные данные")
        print("  3. API изменился или недоступен")
        print("  4. Требуется другой метод аутентификации")

if __name__ == "__main__":
    main()
