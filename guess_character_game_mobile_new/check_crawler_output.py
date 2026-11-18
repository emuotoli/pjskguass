import json

with open('../sekai-crawler/output/cards.json', 'r', encoding='utf-8') as f:
    crawler_data = json.load(f)

print(f"Total cards from crawler: {len(crawler_data)}")
print("\nLooking for 2-star cards (no002):")
print("=" * 80)

for c in crawler_data:
    cid = c.get('id', '')
    if cid.endswith('_no002'):
        print(f"  {cid} | Star: {c.get('star', 0)} | Title: {c.get('title', '')}")
