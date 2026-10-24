"""Knowledge base for the template-based synthetic group chats.

Only used to *generate* training conversations. The trained model and the
summary algorithm never read this file, so nothing here is hard-coded into
the predictions.
"""

from kb_pois import DESTINATIONS as _POI_DESTINATIONS

# Held out of training: these destinations appear only in the "unseen" test
# split, which checks that the model learned how people talk, not place names.
HELD_OUT = {"Osaka, Japan", "Kota Kinabalu, Malaysia"}

DESTINATIONS = dict(_POI_DESTINATIONS)
DESTINATIONS["Shanghai, China"] = {
    "airport": "Shanghai Pudong International Airport (PVG)",
    "pois": [
        ("The Bund", "Zhongshan East 1st Road", "place", "EN", ["the bund", "bund"], "外滩"),
        ("Yu Garden", "Huangpu", "place", "MA", ["yu garden", "yuyuan"], "豫园"),
        ("Nanjing Road", "Huangpu", "shopping", "AEN", ["nanjing road", "nanjing lu"], "南京路"),
        ("Shanghai Disneyland", "Pudong", "activity", "MA", ["disneyland", "disney"], "迪士尼"),
        ("Oriental Pearl Tower", "Lujiazui", "place", "AEN", ["pearl tower", "oriental pearl"], "东方明珠"),
        ("Tianzifang", "Taikang Road", "shopping", "AE", ["tianzifang", "tian zi fang"], "田子坊"),
        ("Zhujiajiao Water Town", "Qingpu", "place", "M", ["zhujiajiao", "water town"], "朱家角"),
        ("Xintiandi", "Huangpu", "place", "AEN", ["xintiandi"], "新天地"),
        ("Shanghai Tower Observation Deck", "Lujiazui", "place", "AE", ["shanghai tower"], "上海中心"),
        ("Jade Buddha Temple", "Putuo", "place", "M", ["jade buddha temple"], "玉佛寺"),
        ("Jia Jia Tang Bao", "Huanghe Road", "food", "BL", ["jia jia tang bao", "jiajia soup dumplings"], "佳家汤包"),
        ("Wukang Road", "Former French Concession", "place", "MA", ["wukang road", "french concession"], "武康路"),
        ("Yang's Fried Dumplings", "Huanghe Road", "food", "BL", ["yang's dumplings", "shengjian"], "小杨生煎"),
        ("Shanghai Museum", "People's Square", "place", "MA", ["shanghai museum"], "上海博物馆"),
    ],
}

# How each destination is named in chat: English short name, Chinese, Malay.
CITY_NAMES = {
    "Penang, Malaysia": ("Penang", "槟城", "Pulau Pinang"),
    "Kuala Lumpur, Malaysia": ("KL", "吉隆坡", "KL"),
    "Melaka, Malaysia": ("Melaka", "马六甲", "Melaka"),
    "Langkawi, Malaysia": ("Langkawi", "兰卡威", "Langkawi"),
    "Singapore": ("Singapore", "新加坡", "Singapura"),
    "Bangkok, Thailand": ("Bangkok", "曼谷", "Bangkok"),
    "Bali, Indonesia": ("Bali", "巴厘岛", "Bali"),
    "Tokyo, Japan": ("Tokyo", "东京", "Tokyo"),
    "Seoul, South Korea": ("Seoul", "首尔", "Seoul"),
    "Taipei, Taiwan": ("Taipei", "台北", "Taipei"),
    "Hong Kong": ("Hong Kong", "香港", "Hong Kong"),
    "Ho Chi Minh City, Vietnam": ("HCMC", "胡志明市", "Ho Chi Minh"),
    "Osaka, Japan": ("Osaka", "大阪", "Osaka"),
    "Kota Kinabalu, Malaysia": ("KK", "亚庇", "Kota Kinabalu"),
    "Shanghai, China": ("Shanghai", "上海", "Shanghai"),
}

HOTEL_BRANDS = [
    ("ibis {area}", "{area}的ibis"),
    ("Holiday Inn Express {area}", "{area}假日酒店"),
    ("Hilton {area}", "{area}希尔顿"),
    ("Citadines {area}", "{area}的Citadines"),
    ("an Airbnb near {area}", "{area}附近的Airbnb"),
    ("a homestay in {area}", "{area}的民宿"),
    ("Novotel {area}", "{area}诺富特"),
    ("a capsule hotel in {area}", "{area}的胶囊旅馆"),
    ("Hotel Jen {area}", "{area}的Hotel Jen"),
    ("the hostel at {area}", "{area}的青旅"),
]

# (english phrase, chinese phrase, malay phrase, short reference)
TRANSPORT = [
    ("take the metro", "坐地铁", "naik MRT", "metro"),
    ("just Grab everywhere", "全程叫Grab", "Grab je semua", "Grab"),
    ("rent a car", "租车自驾", "sewa kereta", "rent car"),
    ("take the bus", "坐巴士", "naik bas", "bus"),
    ("take taxis", "坐的士", "naik teksi", "taxi"),
    ("take the high-speed train", "坐高铁", "naik keretapi laju", "train"),
    ("fly AirAsia", "坐AirAsia飞过去", "naik AirAsia", "AirAsia"),
    ("get a day pass for public transport", "买交通一日券", "beli pas harian", "day pass"),
    ("walk around, it's all near", "走路就好，都很近", "jalan kaki je, dekat", "walk"),
    ("hire a private driver", "包车", "sewa driver", "private driver"),
]

MEMBER_NAMES = [
    "Amy", "Ben", "Chloe", "Daniel", "Ethan", "Farah", "Grace", "Hafiz", "Ivy", "Jason",
    "Kelvin", "Li Wei", "Mei Ling", "Nurul", "Oscar", "Priya", "Qistina", "Ryan", "Siti",
    "Tan", "Uma", "Vivian", "Wei Jie", "Xin Yi", "Yusuf", "Zara", "Aiman", "Bryan", "Cheng",
    "Darren", "Elaine", "Hui Min", "Jia Hao", "Kumar", "Lisa", "Marcus", "Natasha", "Wen",
]
