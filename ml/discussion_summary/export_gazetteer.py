"""Writes functions/planner/gazetteer.json - Voya's place database for AI Summarise.

The planner (functions/planner/) only puts a chat message into the plan when it names a
real place. Places come from, in order: the group's saved list, the app's catalog for the
destination (Firestore catalog_attractions), this file, and finally name patterns
("...路", "...寺", "... Temple"). This file is the built-in part: every destination in kb.py
plus a few extra, planner-only places and Chinese / Malay names (EXTRA below, never used to
generate training chats).

Each place: name, city, district (places in one district can share a day), area (shown as the
location), icon, slots (when it suits: B breakfast, L lunch, D dinner, M morning, A afternoon,
E evening, N night), hours (how long a visit takes), aliases (lower-case, any language).

  python export_gazetteer.py        # also run by export_model.py --deploy
"""

import json
from pathlib import Path

from kb import CITY_NAMES, DESTINATIONS

OUT = Path(__file__).resolve().parents[2] / "functions" / "planner" / "gazetteer.json"

# Planner-only additions: (name, area, district, icon, slots, hours, aliases)
EXTRA = {
    "Shanghai, China": [
        ("Huangpu River Cruise", "The Bund / Lujiazui", "Huangpu", "activity", "EN", 1.0,
         ["huangpu river cruise", "river cruise", "huangpu ferry", "黄浦江轮渡", "黄浦江游船", "浦江游览", "黄浦江", "轮渡"]),
        ("Nanxiang Steamed Bun Restaurant", "Yu Garden", "Huangpu", "food", "BLD", 1.0,
         ["nanxiang", "南翔馒头店", "南翔小笼", "南翔"]),
        ("Lujiazui", "Pudong", "Pudong", "place", "AEN", 1.5, ["lujiazui", "陆家嘴"]),
        ("City God Temple", "Yu Garden", "Huangpu", "place", "MA", 1.0, ["city god temple", "城隍庙"]),
        ("Jing'an Temple", "Jing'an", "Jing'an", "place", "MA", 1.0, ["jing'an temple", "jingan temple", "静安寺"]),
        ("Shanghai Zoo", "Changning", "Changning", "activity", "MA", 3.0, ["shanghai zoo", "上海动物园"]),
        ("Shanghai Natural History Museum", "Jing'an", "Jing'an", "place", "MA", 2.5,
         ["natural history museum", "自然博物馆"]),
        ("Qibao Ancient Town", "Minhang", "Minhang", "place", "MA", 2.5, ["qibao", "七宝古镇", "七宝"]),
        ("Shanghai Ocean Aquarium", "Lujiazui", "Pudong", "activity", "MA", 2.0, ["ocean aquarium", "海洋水族馆", "水族馆"]),
        ("Shouning Road Food Street", "Huangpu", "Huangpu", "food", "DN", 1.5, ["shouning road", "寿宁路美食街", "寿宁路"]),
        ("Seesaw Coffee", "Xintiandi", "Huangpu", "food", "BA", 1.0, ["seesaw coffee", "seesaw"]),
        ("Lady M Shanghai", "Huangpu", "Huangpu", "food", "A", 1.0, ["lady m"]),
        ("Raffles City Shanghai", "People's Square", "Huangpu", "shopping", "AE", 2.0, ["raffles city", "来福士"]),
        ("Dragon Fly Spa", "Xintiandi", "Huangpu", "activity", "AE", 1.5, ["dragon fly spa", "悠庭保健会所", "悠庭"]),
        ("Lao Zheng Xing", "People's Square", "Huangpu", "food", "LD", 1.0, ["lao zheng xing", "老正兴"]),
    ],
    # wishes people often name without a place ("night market", "massage", "street food"): a well-known one
    "Kuala Lumpur, Malaysia": [
        ("Taman Connaught Night Market", "Cheras", "Cheras", "shopping", "N", 2.0, ["connaught night market", "康乐夜市", "pasar malam connaught"]),
        ("Pavilion Kuala Lumpur", "Bukit Bintang", "Bukit Bintang", "shopping", "AE", 2.0, ["pavilion kl", "pavilion", "柏威年"]),
    ],
    "Bangkok, Thailand": [
        ("Asiatique The Riverfront", "Charoen Krung", "Bang Kho Laem", "shopping", "EN", 2.0, ["asiatique", "河畔夜市"]),
        ("Health Land Spa & Massage (Asoke)", "Sukhumvit", "Watthana", "activity", "AE", 2.0, ["health land", "healthland"]),
    ],
    "Singapore": [
        ("Chinatown Street Market", "Chinatown", "Outram", "shopping", "AEN", 1.5, ["chinatown street market", "牛车水夜市"]),
    ],
    "Ho Chi Minh City, Vietnam": [
        ("Ben Thanh Street Food Market", "District 1", "District 1", "food", "DN", 1.5, ["ben thanh street food", "ben thanh night market", "滨城夜市"]),
    ],
    "Seoul, South Korea": [
        ("Gwangjang Market", "Jongno", "Jongno", "food", "LD", 1.5, ["gwangjang market", "广藏市场", "广藏"]),
    ],
    "Bali, Indonesia": [
        ("Gianyar Night Market", "Gianyar", "Gianyar", "food", "DN", 1.5, ["gianyar night market", "pasar malam gianyar"]),
    ],
    "Kota Kinabalu, Malaysia": [
        ("KK Night Market (Filipino Market)", "Kota Kinabalu City", "Kota Kinabalu City", "food", "DN", 1.5,
         ["kk night market", "filipino market", "亚庇夜市", "pasar malam kk"]),
    ],
}
# What kind of place it is, for wishes without a place name (planner/needs.js): never matched in the
# chat as a name, only used to pick "a café" / "dessert" / "本帮菜" when nothing is saved.
TAGS = {
    "Seesaw Coffee": ["cafe", "coffee", "brunch"],
    "Lady M Shanghai": ["dessert", "cake"],
    "Lao Zheng Xing": ["shanghainese", "本帮菜"],
    "Shouning Road Food Street": ["street food"],
    "Raffles City Shanghai": ["mall"],
    "Pavilion Kuala Lumpur": ["mall"],
    "Health Land Spa & Massage (Asoke)": ["massage", "spa"],
    "Dragon Fly Spa": ["massage", "spa"],
    "Asiatique The Riverfront": ["night market"],
    "Chinatown Street Market": ["night market"],
    "Gwangjang Market": ["korean", "street food"],
}

# Districts for the kb.py places (the rest use their area as the district).
DISTRICT = {
    "Zhongshan East 1st Road": "Huangpu", "Huangpu": "Huangpu", "People's Square": "Huangpu",
    "Huanghe Road": "Huangpu", "Taikang Road": "Xuhui", "Former French Concession": "Xuhui",
    "Lujiazui": "Pudong", "Pudong": "Disneyland", "Qingpu": "Qingpu", "Putuo": "Putuo",
}
# Extra aliases for kb.py places (Chinese / casual names people type).
MORE_ALIASES = {
    "Petronas Twin Towers": ["双子塔", "吉隆坡双子塔", "twin towers", "menara berkembar"],
    "Shanghai Disneyland": ["上海迪士尼", "迪士尼乐园", "迪斯尼", "disney land"],
    "Yu Garden": ["豫园", "yuyuan garden", "yu yuan"],
    "Oriental Pearl Tower": ["东方明珠", "东方明珠塔", "pearl tower"],
    "Shanghai Tower Observation Deck": ["上海中心", "上海中心大厦", "上海中心观光厅", "shanghai tower"],
    "Nanjing Road": ["南京路", "南京东路", "南京路步行街", "nanjing east road"],
    "Zhujiajiao Water Town": ["朱家角", "朱家角古镇", "zhu jia jiao"],
    "Wukang Road": ["武康路", "武康大楼", "wukang mansion"],
    "Shanghai Museum": ["上海博物馆", "上博"],
    "Tianzifang": ["田子坊"],
    "Xintiandi": ["新天地"],
    "Jade Buddha Temple": ["玉佛寺"],
    "The Bund": ["外滩", "the bund", "bund"],
}
FULL_DAY = {"activity": 3.0}
HOURS = {"place": 2.0, "shopping": 2.0, "food": 1.0, "activity": 3.0}
# Areas people name for a hotel or a meeting point: recognised, but never put in the plan as a visit.
AREAS = {
    "Shanghai, China": [("People's Square", ["人民广场", "people's square", "peoples square"]),
                        ("Jing'an", ["静安"]), ("Pudong", ["浦东"]), ("Puxi", ["浦西"])],
}


def city_aliases(city):
    short, zh, ms = CITY_NAMES.get(city, (city.split(",")[0], "", ""))
    return sorted({a.lower() for a in (city.split(",")[0], short, zh, ms) if a})


def main():
    places = []
    for city, d in DESTINATIONS.items():
        for name, area, icon, slots, aliases, zh in d["pois"]:
            al = {name.lower(), *[a.lower() for a in aliases], *([zh] if zh else []),
                  *[a.lower() for a in MORE_ALIASES.get(name, [])]}
            hours = 8.0 if "disney" in name.lower() or "universal" in name.lower() else HOURS.get(icon, 2.0)
            places.append({"name": name, "city": city, "district": DISTRICT.get(area, area) if city.startswith("Shanghai") else area,
                           "area": area, "icon": icon, "slots": slots, "hours": hours,
                           "aliases": sorted(a for a in al if len(a) >= 2), **({"tags": TAGS[name]} if name in TAGS else {})})
        for name, area, district, icon, slots, hours, aliases in EXTRA.get(city, []):
            places.append({"name": name, "city": city, "district": district, "area": area, "icon": icon,
                           "slots": slots, "hours": hours, "aliases": sorted({name.lower(), *aliases}),
                           **({"tags": TAGS[name]} if name in TAGS else {})})
    cities = [{"city": c, "aliases": city_aliases(c)} for c in DESTINATIONS]
    areas = [{"city": c, "name": n, "aliases": a} for c, lst in AREAS.items() for n, a in lst]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"cities": cities, "places": places, "areas": areas}, ensure_ascii=False, indent=0),
                   encoding="utf-8")
    print(f"wrote {OUT} ({len(places)} places, {len(cities)} cities)")


if __name__ == "__main__":
    main()
