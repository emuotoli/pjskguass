import json

two_star_names = {
    'res001_no002': '精一杯の韻を踏んで',
    'res002_no002': '食べすぎはぷよぷよのもと',
    'res003_no002': '変わっていかなくちゃ',
    'res004_no002': '本当、これだから…',
    'res005_no002': 'キャッチフレーズノート！',
    'res006_no002': '全部、2個ずつください',
    'res007_no002': 'アンタは顔を隠しなさい！',
    'res008_no002': 'いつか胸をはれるように',
    'res009_no002': 'シャッターチャンスは逃さない',
    'res010_no002': '私のオススメ！',
    'res011_no002': 'とことん付き合ってもらうぞ',
    'res012_no002': 'お前がうらやましい',
    'res013_no002': 'シュッシュキレイ、ゴーゴー！',
    'res014_no002': 'フワフワがばばーんっ',
    'res015_no002': 'ネネロボがいてくれたから',
    'res016_no002': 'できてからのお楽しみさ',
    'res017_no002': '運命共同体',
    'res018_no002': '現実かは気にしちゃダメ',
    'res019_no002': '悪くはないかな',
    'res020_no002': '見てよこの出来ばえ！',
    'res021_no002': '嬉しいはくすぐったい',
}

with open('assets/data/extra_cards.json', 'r', encoding='utf-8') as f:
    extra_data = json.load(f)

updated_count = 0
for c in extra_data:
    cid = c.get('id', '')
    if cid in two_star_names:
        old_name = c.get('cardName', '')
        c['cardName'] = two_star_names[cid]
        updated_count += 1
        print(f"Updated: {cid} | {old_name} -> {two_star_names[cid]}")

with open('assets/data/extra_cards.json', 'w', encoding='utf-8') as f:
    json.dump(extra_data, f, ensure_ascii=False, indent=2)

print(f"\nTotal updated in extra_cards.json: {updated_count}")

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    cards_data = json.load(f)

updated_count_cards = 0
for c in cards_data:
    cid = c.get('id', '')
    if cid in two_star_names:
        old_name = c.get('cardName', '')
        c['cardName'] = two_star_names[cid]
        updated_count_cards += 1
        print(f"Updated: {cid} | {old_name} -> {two_star_names[cid]}")

with open('assets/data/cards.json', 'w', encoding='utf-8') as f:
    json.dump(cards_data, f, ensure_ascii=False, indent=2)

print(f"\nTotal updated in cards.json: {updated_count_cards}")
