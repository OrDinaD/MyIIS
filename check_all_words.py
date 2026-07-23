import os
import re
import requests
import time

def parse_strings(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    pattern = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.MULTILINE)
    return dict(pattern.findall(content))

def translate_word_skarnik(word):
    url = "https://skarnik.by/search"
    params = {"q": word}
    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        response = requests.get(url, params=params, headers=headers, timeout=5)
        if response.status_code == 200:
            match = re.search(r'<div id="tgt"[^>]*>(.*?)</div>', response.text, re.DOTALL)
            if match:
                text = re.sub(r'<[^>]+>', '', match.group(1))
                return text.strip()
    except Exception:
        pass
    return None

ru_strings = parse_strings('./MyIIS/ru.lproj/Localizable.strings')
be_strings = parse_strings('./MyIIS/be.lproj/Localizable.strings')

md_content = "# Сравнение текущего перевода со словарем Skarnik\n\n"
md_content += "| Ключ | Оригинал (RU) | Текущий перевод (BE) | Skarnik |\n"
md_content += "|---|---|---|---|\n"

diff_count = 0

# Check only single words or short phrases to avoid spamming Skarnik with long sentences
count = 0
for k, ru_val in ru_strings.items():
    be_val = be_strings.get(k, "")
    
    # Check if it's a single word with no format specifiers and only Cyrillic characters
    # This ensures Skarnik dictionary can actually find it
    if re.fullmatch(r'[А-Яа-яЁё]+', ru_val):
        count += 1
        skarnik_text = translate_word_skarnik(ru_val)
        time.sleep(0.3) # prevent rate limiting
        
        if skarnik_text:
            # Skarnik returns the full dictionary entry, we just take the first line or first match
            # But the dictionary entry can be long, let's just grab the first 50 chars for the table
            skarnik_short = skarnik_text.replace('\n', ' ')[:100]
            
            # Simple heuristic to see if current translation is mentioned in Skarnik
            # Note: dictionary entries contain words, let's just check if current translation (lower) is in Skarnik output
            if be_val.lower() not in skarnik_text.lower():
                md_content += f"| `{k}` | {ru_val} | **{be_val}** | {skarnik_short}... |\n"
                diff_count += 1

if diff_count == 0:
    md_content += "\n*Различий для одиночных слов не найдено!*\n"

artifact_path = "/Users/vlad/.gemini/antigravity-cli/brain/5ac2e36d-63bd-4aff-9260-73caf29d9967/skarnik_differences.md"
with open(artifact_path, "w", encoding="utf-8") as f:
    f.write(md_content)

print(f"Processed {count} words. Found {diff_count} potential differences.")
