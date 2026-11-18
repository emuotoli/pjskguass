import json

with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print("Cards with rarity=0 (birthday cards):")
print("-" * 60)
count_0 = 0
for c in data:
    if c.get('rarity', 0) == 0:
        count_0 += 1
        print(f'{c["id"]} | {c.get("cardName", "")}')

print(f"\nTotal rarity=0 cards: {count_0}")

print("\n\nCards with rarity=1 (1-star cards):")
print("-" * 60)
count_1 = 0
for c in data:
    if c.get('rarity', 0) == 1:
        count_1 += 1
        print(f'{c["id"]} | {c.get("cardName", "")}')

print(f"\nTotal rarity=1 cards: {count_1}")

print("\n\nCards ending with _no001 in extra_cards.json:")
print("-" * 60)
for c in data:
    if c.get('id', '').endswith('_no001'):
        print(f'{c["id"]} | Rarity: {c.get("rarity", 0)} | {c.get("cardName", "")}')
