from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

MONTHS_RU = {
    1: "января",
    2: "февраля",
    3: "марта",
    4: "апреля",
    5: "мая",
    6: "июня",
    7: "июля",
    8: "августа",
    9: "сентября",
    10: "октября",
    11: "ноября",
    12: "декабря",
}


def _format_birth_day_ru(value: str) -> str:
    """Replicates DateFormatter with the "d MMMM yyyy" format in ru_RU locale."""
    try:
        date = datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        return value

    month = MONTHS_RU.get(date.month)
    if month is None:
        return value
    return f"{date.day} {month} {date.year}"


def convert_to_user_py(
    login_response: Dict[str, Any],
    personal_info: Dict[str, Any],
    schedule_info: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    fio_parts = login_response.get("fio", "").split()
    last_name = fio_parts[0] if fio_parts else ""
    first_name = fio_parts[1] if len(fio_parts) > 1 else ""
    middle_name = fio_parts[2] if len(fio_parts) > 2 else ""

    birth_day_raw = personal_info.get("birthDay")
    formatted_birth_day = "Не указана"
    if isinstance(birth_day_raw, str) and birth_day_raw.strip():
        formatted_birth_day = _format_birth_day_ru(birth_day_raw)

    username_value = login_response.get("username", "")
    try:
        user_id = int(username_value)
    except (TypeError, ValueError):
        user_id = 0

    rating_value = personal_info.get("rating")
    rating = rating_value if isinstance(rating_value, int) else 0

    settings_info = personal_info.get("settings") or {}
    settings = {
        "isPublicProfile": settings_info.get("isPublicProfile", True),
        "isSearchJob": settings_info.get("isSearchJob", False),
        "isShowRating": settings_info.get("isShowRating", False),
    }

    if isinstance(schedule_info, dict):
        faculty = schedule_info.get("facultyAbbrev") or ""
        speciality = schedule_info.get("specialityAbbrev") or ""
    else:
        faculty = login_response.get("group", "")
        speciality = "Не указано"

    course_value = personal_info.get("course")
    course = course_value if isinstance(course_value, int) else 1

    user = {
        "id": user_id,
        "firstName": first_name,
        "lastName": last_name,
        "middleName": middle_name,
        "birthDay": formatted_birth_day,
        "email": login_response.get("email"),
        "phone": login_response.get("phone"),
        "photo": login_response.get("photoUrl"),
        "summary": personal_info.get("summary"),
        "rating": rating,
        "education": {
            "faculty": faculty,
            "course": course,
            "speciality": speciality,
            "group": login_response.get("group", ""),
        },
        "settings": settings,
    }

    full_name = f"{user['lastName']} {user['firstName']} {user['middleName']}".strip()
    user["fullName"] = full_name
    user["displayRating"] = rating if settings["isShowRating"] else 0
    return user


def _load_json(path: str) -> Dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def test_convert_to_user_with_schedule_info():
    login_response = _load_json("Tests/login_response.json")
    personal_info = _load_json("Tests/api_response_personal-information.json")
    schedule_response = _load_json(
        "Tests/api_response_schedule_studentGroup_420603.json"
    )
    schedule_info = schedule_response.get("studentGroupDto")

    user = convert_to_user_py(login_response, personal_info, schedule_info)

    assert user["firstName"] == "Владислав"
    assert user["lastName"] == "Василевский"
    assert user["middleName"] == "Валерьевич"
    assert user["birthDay"] == "Не указана"
    assert user["education"]["faculty"] == "ФИТУ"
    assert user["education"]["speciality"] == "СУИ (АСОИ)"
    assert user["education"]["group"] == "420603"
    assert user["education"]["course"] == 2
    assert user["settings"] == {
        "isPublicProfile": True,
        "isSearchJob": False,
        "isShowRating": False,
    }
    assert user["displayRating"] == 0
    assert user["fullName"] == "Василевский Владислав Валерьевич"


def test_convert_to_user_without_schedule_info():
    login_response = {
        "username": "12345",
        "fio": "Иванов Иван Иванович",
        "email": "ivan@example.com",
        "phone": "+375290000000",
        "group": "123456",
        "photoUrl": None,
    }
    personal_info = {
        "summary": "",
        "course": None,
        "rating": None,
        "settings": {},
    }

    user = convert_to_user_py(login_response, personal_info, schedule_info=None)

    assert user["education"]["faculty"] == "123456"
    assert user["education"]["speciality"] == "Не указано"
    assert user["education"]["course"] == 1
    assert user["displayRating"] == 0


def test_birth_day_formatting():
    login_response = {
        "username": "1",
        "fio": "Петров Петр Петрович",
        "email": None,
        "phone": None,
        "group": "111111",
        "photoUrl": None,
    }
    personal_info = {
        "birthDay": "2001-02-03",
        "course": 3,
        "rating": 10,
        "settings": {"isShowRating": True},
    }

    schedule_info = {
        "facultyAbbrev": "ФИТУ",
        "specialityAbbrev": "АСУ",
    }

    user = convert_to_user_py(login_response, personal_info, schedule_info)

    assert user["birthDay"] == "3 февраля 2001"
    assert user["displayRating"] == 10
