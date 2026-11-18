import json

with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

two_star_cards = [c for c in data if c.get('rarity', 0) == 2]

print(f"Total 2-star cards in extra_cards.json: {len(two_star_cards)}")
print("\n2-star cards with generic or empty names:")
print("=" * 80)

for c in two_star_cards:
    name = c.get('cardName', '')
    if name == '' or name == '二星' or name.startswith('2星') or name == 'Sekai Viewer':
        print(f"  {c['id']} | Name: '{name}' | Character: {c.get('character', '')}")

print("\n\nAll 2-star cards:")
print("=" * 80)
for c in two_star_cards:
    print(f"  {c['id']} | Name: '{c.get('cardName', '')}' | Character: {c.get('character', '')}")
