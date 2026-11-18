import json

with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

fixed_count = 0
for c in data:
    cid = c.get('id', '')
    if cid.endswith('_no001'):
        if c.get('rarity', 0) == 0:
            c['rarity'] = 1
            fixed_count += 1
            print(f'Fixed: {cid} - rarity changed from 0 to 1')

with open('assets/data/extra_cards.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f'\nTotal fixed: {fixed_count} cards')
