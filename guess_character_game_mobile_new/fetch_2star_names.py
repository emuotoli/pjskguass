import json
import urllib.request
import re

two_star_site_ids = [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58, 62, 66, 70, 74, 78, 86]

res_mapping = {
    1: 'res001', 2: 'res002', 3: 'res003', 4: 'res004', 5: 'res005', 6: 'res006',
    7: 'res007', 8: 'res008', 9: 'res009', 10: 'res010', 11: 'res011', 12: 'res012',
    13: 'res013', 14: 'res014', 15: 'res015', 16: 'res016', 17: 'res017', 18: 'res018',
    19: 'res019', 20: 'res020', 21: 'res021', 22: 'res022', 23: 'res023', 24: 'res024',
    25: 'res025', 26: 'res026'
}

card_names = {}

for idx, site_id in enumerate(two_star_site_ids):
    res_key = idx + 1
    card_id = f"{res_mapping[res_key]}_no002"
    
    try:
        url = f"https://pjsk.moe/cards/{site_id}"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')
        
        name_match = re.search(r'<h1[^>]*>([^<]+)</h1>', html)
        if name_match:
            name = name_match.group(1).strip()
            if name and not name.isdigit() and len(name) > 1:
                card_names[card_id] = name
                print(f"✓ {card_id} -> {name}")
            else:
                print(f"✗ {card_id} -> No valid name found")
        else:
            print(f"✗ {card_id} -> Name not found")
            
    except Exception as e:
        print(f"✗ {card_id} -> Error: {e}")

print(f"\nTotal fetched: {len(card_names)}")

with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    extra_data = json.load(f)

updated_count = 0
for c in extra_data:
    cid = c.get('id', '')
    if cid in card_names:
        old_name = c.get('cardName', '')
        c['cardName'] = card_names[cid]
        updated_count += 1
        print(f"Updated: {cid} | {old_name} -> {card_names[cid]}")

with open('assets/data/extra_cards.json', 'w', encoding='utf-8') as f:
    json.dump(extra_data, f, ensure_ascii=False, indent=2)

print(f"\nTotal updated in extra_cards.json: {updated_count}")

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    cards_data = json.load(f)

updated_count_cards = 0
for c in cards_data:
    cid = c.get('id', '')
    if cid in card_names:
        old_name = c.get('cardName', '')
        c['cardName'] = card_names[cid]
        updated_count_cards += 1
        print(f"Updated: {cid} | {old_name} -> {card_names[cid]}")

with open('assets/data/cards.json', 'w', encoding='utf-8') as f:
    json.dump(cards_data, f, ensure_ascii=False, indent=2)

print(f"\nTotal updated in cards.json: {updated_count_cards}")
