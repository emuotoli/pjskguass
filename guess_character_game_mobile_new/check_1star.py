import json

one_star_ids = [165, 101, 97, 93, 89, 81, 77, 73, 69, 65, 61, 53, 49, 45, 41, 37, 33, 29, 25, 21, 17, 13, 9, 5, 1]

with open('assets/data/cards.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

found = []
for c in data:
    cid = c.get('id', '')
    if cid:
        try:
            num_id = int(cid.split('_')[-1]) if '_' in cid else int(cid)
            if num_id in one_star_ids:
                found.append((cid, c.get('star', 0), c.get('cardName', '')))
        except:
            pass

print(f'Found {len(found)} one-star cards:')
for cid, star, name in found:
    print(f'  ID: {cid}, Star: {star}, Name: {name}')
