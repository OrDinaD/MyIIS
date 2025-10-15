from pathlib import Path


def test_manual_login_script_uses_valid_properties():
    code = Path("Tests/APITests/LoginAPITest.swift").read_text(encoding="utf-8")

    # Скрипт ручного тестирования не должен обращаться к несуществующим полям.
    assert ".fullName" not in code
    assert ".academicGroup" not in code

    # Проверяем, что выводятся реальные поля ответа логина.
    assert "loginResponse.fio" in code
    assert "loginResponse.group" in code
    assert "loginResponse.email" in code
    assert "loginResponse.username" in code
