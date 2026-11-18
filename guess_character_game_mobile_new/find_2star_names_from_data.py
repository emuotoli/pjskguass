import json

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    cards_data = json.load(f)

character_cards = {}
for c in cards_data:
    char = c.get('character', '')
    if char not in character_cards:
        character_cards[char] = []
    character_cards[char].append((c.get('id', ''), c.get('star', 0