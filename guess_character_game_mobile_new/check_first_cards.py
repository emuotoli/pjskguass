import json

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

first_cards = []
for c in data:
    cid = c.get('id', '')
    if cid.endswith('_no001'):
        first_cards.append((cid, c.get('star', 0), c.get('cardName', '')))

print(f'Found {len(first_cards)} cards ending with _no001:')
for cid, star, name in first_cards:
    print(f'  {cid} - Star: {star}, Name: {name}')
