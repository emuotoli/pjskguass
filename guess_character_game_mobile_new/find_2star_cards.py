import json

two_star_site_ids = [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58, 62, 66, 70, 74, 78, 86]

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    cards_data = json.load(f)

with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    extra_data = json.load(f)

print("Looking for 2-star cards (rarity=2) without proper names:")
print("=" * 80)

all_cards = cards_data + extra_data
found_2star = []

for c in all_cards:
    if c.get('star', 0) == 2 or c.get('rarity', 0) == 2:
        name = c.get('cardName', '')
        if name == '二星' or name.startswith('2星') and len(name) <= 5:
            found_2star.append((c.get('id', ''), name, c.get('character', '')))

print(f"Found {len(found_2star)} 2-star cards with generic names:")
for cid, name, char in found_2star:
    print(f"  {cid} | {name} | {char}")

print("\n\nChecking cards ending with _no002 (2nd card of each character):")
print("=" * 80)
for c in all_cards:
    cid = c.get('id', '')
    if cid.endswith('_no002'):
        print(f"  {cid} | Star: {c.get('star', c.get('rarity', 0))} | Name: {c.get('cardName', '')} | {c.get('character', '')}")
