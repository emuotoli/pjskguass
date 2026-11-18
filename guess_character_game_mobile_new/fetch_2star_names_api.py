import json
import urllib.request

two_star_site_ids = [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58, 62, 66, 70, 74, 78, 86]

res_mapping = {
    1: 'res001', 2: 'res002', 3: 'res003', 4: 'res004', 5: 'res005', 6: 'res006',
    7: 'res007', 8: 'res008', 9: 'res009', 10: 'res010', 11: 'res011', 12: 'res012',
    13: 'res013', 14: 'res014', 15: 'res015', 16: 'res016', 17: 'res017', 18: 'res018',
    19: 'res019', 20: 'res020', 21: 'res021', 22: 'res022', 23: 'res023', 24: 'res024',
    25: 'res025', 26: 'res026'
}

card_names = {}

try:
    url = "https://sekai.best/api/cards"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as response:
        data = json.loads(response.read().decode('utf-8'))
    
    print(f"Total cards from API: {len(data)}")
    
    for card in data:
        card_id = card.get('id', '')
        if card_id.endswith('_no002'):
            name = card.get('cardName', '') or card.get('name', '')
            if name and name != card_id and len(name) > 2:
                card_names[card_id] = name
                print(f"✓ {card_id} -> {name}")

except Exception as e:
    print(f"Error fetching API: {e}")

print(f"\nTotal found: {len(card_names)}")

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
