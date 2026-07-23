import requests
import re

def translate_word_skarnik(word):
    url = f"https://skarnik.by/search"
    params = {"q": word}
    headers = {"User-Agent": "Mozilla/5.0"}
    
    response = requests.get(url, params=params, headers=headers)
    
    if response.status_code == 200:
        match = re.search(r'<div id="tgt"[^>]*>(.*?)</div>', response.text, re.DOTALL)
        if match:
            text = re.sub(r'<[^>]+>', '', match.group(1))
            return text.strip()
    return None

print(f"учеба -> {translate_word_skarnik('учеба')}")
