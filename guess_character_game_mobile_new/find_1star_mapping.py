import json

one_star_site_ids = [165, 101, 97, 93, 89, 81, 77, 73, 69, 65, 61, 53, 49, 45, 41, 37, 33, 29, 25, 21, 17, 13, 9, 5, 1]

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print("Looking for cards that are likely 1-star based on site IDs:")
print("-" * 60)

for c in data:
    cid = c.get('id', '')
    star = c.get('star', 0)
    
    if cid.endswith('_no001') or star == 1:
        no_part = cid.split('_no')[1] if '_no' in cid else ''
        res_part = cid.split('_no')[0] if '_no' in cid else ''
        
        print(f'{cid} | Star: {star} | {c.get("cardName", "")}')

print("\n\nTotal 1-star cards in cards.json:", sum(1 for c in data if c.get('star', 0) == 1))
