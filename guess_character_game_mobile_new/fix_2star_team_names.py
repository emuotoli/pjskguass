import json

two_star_team_names = {
    'res001_no002': 'Leo/need',
    'res002_no002': 'Leo/need',
    'res003_no002': 'Leo/need',
    'res004_no002': 'Leo/need',
    'res005_no002': 'MORE MORE JUMP！',
    'res006_no002': 'MORE MORE JUMP！',
    'res007_no002': 'MORE MORE JUMP！',
    'res008_no002': 'MORE MORE JUMP！',
    'res009_no002': 'Vivid BAD SQUAD',
    'res010_no002': 'Vivid BAD SQUAD',
    'res011_no002': 'Vivid BAD SQUAD',
    'res012_no002': 'Vivid BAD SQUAD',
    'res013_no002': 'ワンダーランズ×ショウタイム',
    'res014_no002': 'ワンダーランズ×ショウタイム',
    'res015_no002': 'ワンダーランズ×ショウタイム',
    'res016_no002': 'ワンダーランズ×ショウタイム',
    'res017_no002': '25時、ナイトコードで。',
    'res018_no002': '25時、ナイトコードで。',
    'res019_no002': '25時、ナイトコードで。',
    'res020_no002': '25時、ナイトコードで。',
    'res021_no002': '誰もいないセカイ',
}

with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    extra_data = json.load(f)

updated_count = 0
for c in extra_data:
    cid = c.get('id', '')
    if cid in two_star_team_names:
        old_name = c.get('cardName', '')
        c['cardName'] = two_star_team_names[cid]
        updated_count += 1
        print(f"Updated: {cid} | {old_name} -> {two_star_team_names[cid]}")

with open('assets/data/extra_cards.json', 'w', encoding='utf-8') as f:
    json.dump(extra_data, f, ensure_ascii=False, indent=2)

print(f"\nTotal updated in extra_cards.json: {updated_count}")

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    cards_data = json.load(f)

updated_count_cards = 0
for c in cards_data:
    cid = c.get('id', '')
    if cid in two_star_team_names:
        old_name = c.get('cardName', '')
        c['cardName'] = two_star_team_names[cid]
        updated_count_cards += 1
        print(f"Updated: {cid} | {old_name} -> {two_star_team_names[cid]}")

with open('assets/data/cards.json', 'w', encoding='utf-8') as f:
    json.dump(cards_data, f, ensure_ascii=False, indent=2)

print(f"\nTotal updated in cards.json: {updated_count_cards}")
