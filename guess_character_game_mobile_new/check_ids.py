import json

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print(f'Total cards: {len(data)}')
print('First 10 card IDs:')
for c in data[:10]:
    cid = c.get('id', '')
    print(f'  {cid}')

print('\nChecking extra_cards.json:')
with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    extra_data = json.load(f)

print(f'Total extra cards: {len(extra_data)}')
print('First 10 extra card IDs:')
for c in extra_data[:10]:
    cid = c.get('id', '')
    print(f'  {cid}')
