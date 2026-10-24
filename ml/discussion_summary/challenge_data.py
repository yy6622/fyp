"""Hand-written challenge chats (written independently of the templates, labelled
by human judgement - NOT by the decision rule). Never used for training.

Line format:  speaker | text | LABEL | topic | stance
Run: python challenge_data.py   -> data/challenge.jsonl, data/challenge2.jsonl
"""

from common import DATA, write_jsonl

CHATS = [
    {
        "id": "ch-01-shanghai", "destination": "Shanghai", "members": ["Wei Jie", "Amanda", "Hafiz", "Mei"],
        "lines": """
Wei Jie | guys so are we confirmed going Shanghai in Dec? | DESTINATION | t1 | propose
Amanda | yes!! finally | DECISION | t1 | agree
Hafiz | ok on | DECISION | t1 | agree
Mei | 我ok 🙌 | DECISION | t1 | agree
Wei Jie | budget wise I'm thinking RM3000 per person including flight | BUDGET | t2 | propose
Hafiz | 3k ok for me | DECISION | t2 | agree
Amanda | hmm 3k tight leh if we want to go Disney | DECISION | t2 | defer
Mei | 机票现在大概RM1400来回 | BUDGET | t2 | info
Amanda | ok la 3k can, I'll skip some shopping 😂 | DECISION | t2 | agree
Wei Jie | dates? I'm thinking 14-19 Dec | DATE | t3 | propose
Hafiz | 14-19 cannot, my company year end closing until 16th | DECISION | t3 | reject
Hafiz | 18-23 Dec? | DATE | t4 | propose
Mei | 12月18号到23号我可以 | DECISION | t4 | agree
Amanda | same | DECISION | t4 | agree
Wei Jie | ok 18-23 Dec then, I'll check flights tonight | DECISION | t4 | finalize
Mei | 外滩一定要去，晚上很漂亮 | ATTRACTION | t5 | propose
Amanda | yesss the bund at night 😍 | DECISION | t5 | agree
Hafiz | bund confirm la | DECISION | t5 | agree
Amanda | can we do Disneyland one day? | ATTRACTION | t6 | propose
Hafiz | Disney ticket like RM400 leh 😬 | ATTRACTION | t6 | info
Wei Jie | I'm not that into theme parks tbh | DECISION | t6 | reject
Mei | 我也可以不去，你们决定 | DECISION | t6 | defer
Amanda | ok we decide nearer the date lah | DECISION | t6 | defer
Hafiz | Yu Garden and Nanjing Road can do same day, both near | ATTRACTION | t7 | propose
Mei | 可以，豫园那边也有小笼包 | DECISION | t7 | agree
Amanda | 👍 | DECISION | t7 | agree
Wei Jie | hotel I found Jinjiang Inn near People's Square, RM180 a night for 2 pax | ACCOMMODATION | t8 | propose
Amanda | People's Square convenient, metro line 1 2 8 all there | DESTINATION | t8 | info
Hafiz | Or Airbnb in French Concession? more vibe | ACCOMMODATION | t9 | propose
Mei | 上海很多airbnb不能登记外国人哦 | ACCOMMODATION | t9 | info
Hafiz | oh really? then hotel la | DECISION | t9 | reject
Wei Jie | ok I book Jinjiang Inn, 2 rooms | DECISION | t8 | finalize
Mei | 交通的话就坐地铁，买张交通卡 | TRANSPORT | t10 | propose
Amanda | metro all the way 👍 | DECISION | t10 | agree
Hafiz | metro ok | DECISION | t10 | agree
Hafiz | I prefer not to wake up too early pls, holiday mah | PREFERENCE | - | none
Mei | 我不吃牛肉哦 | PREFERENCE | - | none
Wei Jie | noted 👌 | OTHER | - | none
""",
        "topics": {"t1": ("DESTINATION", "Shanghai", "confirmed"), "t2": ("BUDGET", "RM3000 per person", "confirmed"),
                   "t3": ("DATE", "14-19 Dec", "rejected"), "t4": ("DATE", "18-23 Dec", "confirmed"),
                   "t5": ("ATTRACTION", "The Bund", "confirmed"), "t6": ("ATTRACTION", "Disneyland", "pending"),
                   "t7": ("ATTRACTION", "Yu Garden and Nanjing Road", "confirmed"),
                   "t8": ("ACCOMMODATION", "Jinjiang Inn People's Square", "confirmed"),
                   "t9": ("ACCOMMODATION", "Airbnb in French Concession", "rejected"),
                   "t10": ("TRANSPORT", "metro", "confirmed")},
        "prefs": [("Hafiz", "doesn't want early starts"), ("Mei", "doesn't eat beef")],
        "facts": {"destination": "Shanghai", "budget": 3000, "budget_basis": "per_person", "dates": "18-23 Dec"},
    },
    {
        "id": "ch-02-penang", "destination": "Penang", "members": ["Aiman", "Siti", "Kumar"],
        "lines": """
Aiman | weekend ni jom Penang? dah lama tak cuti | DESTINATION | t1 | propose
Siti | jom!! | DECISION | t1 | agree
Kumar | on, I drive | DECISION | t1 | agree
Kumar | drive up from KL, petrol + toll maybe RM200 total | TRANSPORT | t2 | propose
Siti | ok best, no need flight | DECISION | t2 | agree
Aiman | total budget for 3 of us around RM1200 boleh? | BUDGET | t3 | propose
Siti | hmm hotel pun mahal skrg, takut tak cukup | DECISION | t3 | defer
Kumar | we see the hotel price first then decide | DECISION | t3 | defer
Siti | hotel aku tengok Hotel Jen Penang RM380 semalam | ACCOMMODATION | t4 | propose
Kumar | 380 too much for one night bro | DECISION | t4 | reject
Aiman | ada homestay kat Armenian Street RM220, 2 bilik | ACCOMMODATION | t5 | propose
Kumar | homestay ok, near street art also | DECISION | t5 | agree
Siti | ok fine homestay | DECISION | t5 | agree
Aiman | ok aku book homestay tu | DECISION | t5 | finalize
Siti | lol my mom asking me to buy tau sar pneah back | OTHER | - | none
Kumar | hahaha the famous one at Ghee Hiang | OTHER | - | none
Siti | Kek Lok Si nak pergi tak? | ATTRACTION | t6 | propose
Aiman | boleh, pagi Sabtu | DECISION | t6 | agree
Kumar | morning ok | DECISION | t6 | agree
Kumar | Penang Hill also? sunset view | ATTRACTION | t7 | propose
Siti | aku takut tinggi 😅 | PREFERENCE | - | none
Aiman | tengok la nanti, kalau ada masa | DECISION | t7 | defer
Siti | must eat char koay teow at Siam Road!! | ATTRACTION | t8 | propose
Kumar | 100% | DECISION | t8 | agree
Aiman | wajib | DECISION | t8 | agree
Aiman | aku tak makan pedas sangat btw | PREFERENCE | - | none
Kumar | dates confirm this sat sun right? 14-15 Jun | DATE | t9 | propose
Siti | yup | DECISION | t9 | agree
Aiman | yes | DECISION | t9 | agree
""",
        "topics": {"t1": ("DESTINATION", "Penang", "confirmed"), "t2": ("TRANSPORT", "drive from KL", "confirmed"),
                   "t3": ("BUDGET", "RM1200 total", "pending"), "t4": ("ACCOMMODATION", "Hotel Jen Penang", "rejected"),
                   "t5": ("ACCOMMODATION", "homestay at Armenian Street", "confirmed"),
                   "t6": ("ATTRACTION", "Kek Lok Si", "confirmed"), "t7": ("ATTRACTION", "Penang Hill", "pending"),
                   "t8": ("ATTRACTION", "Siam Road Char Koay Teow", "confirmed"), "t9": ("DATE", "14-15 Jun", "confirmed")},
        "prefs": [("Siti", "is afraid of heights"), ("Aiman", "can't eat very spicy food")],
        "facts": {"destination": "Penang", "budget": None, "budget_basis": None, "dates": "14-15 Jun"},
    },
    {
        "id": "ch-03-tokyo-family", "destination": "Tokyo", "members": ["爸爸", "妈妈", "Jia Hao", "Xin Yi"],
        "lines": """
Jia Hao | 爸妈，明年三月去东京好不好？樱花季 | DESTINATION | t1 | propose
妈妈 | 好啊，我一直想看樱花 | DECISION | t1 | agree
爸爸 | 可以 | DECISION | t1 | agree
Xin Yi | yay!! 🌸 | DECISION | t1 | agree
Jia Hao | 我看了一下，3月25号到30号樱花最好 | DATE | t2 | propose
Xin Yi | 25号我还在考试 😭 | DECISION | t2 | reject
Xin Yi | 3月28号到4月2号呢？ | DATE | t3 | propose
妈妈 | 我们都可以，看Xin Yi | DECISION | t3 | agree
Jia Hao | 那就28号出发吧 | DECISION | t3 | finalize
爸爸 | 预算每人六千够吗 | BUDGET | t4 | propose
Jia Hao | 六千应该够，机票大概两千 | DECISION | t4 | agree
妈妈 | 不要太省，难得出去 | PREFERENCE | - | none
爸爸 | 那就每人六千左右 | DECISION | t4 | finalize
Xin Yi | I want to go teamLab Planets!! | ATTRACTION | t5 | propose
爸爸 | 那是什么 | OTHER | - | none
Xin Yi | digital art museum, very nice for photos | ATTRACTION | t5 | info
妈妈 | 年轻人去就好，我们去浅草寺 | DECISION | t5 | defer
Jia Hao | 浅草寺一定要去 | ATTRACTION | t6 | propose
爸爸 | 好 | DECISION | t6 | agree
妈妈 | 我膝盖不好，不要走太多路 | PREFERENCE | - | none
Jia Hao | 那我们多坐的士，少走路 | TRANSPORT | t7 | propose
爸爸 | 东京的士很贵 | DECISION | t7 | reject
Xin Yi | 地铁很方便啦，买Suica卡就好 | TRANSPORT | t8 | propose
Jia Hao | ok地铁为主，远的才坐的士 | DECISION | t8 | finalize
妈妈 | 住的地方要近地铁站 | PREFERENCE | - | none
Jia Hao | 新宿的Hilton一晚RM900，有点贵 | ACCOMMODATION | t9 | propose
Xin Yi | 上野的APA便宜很多，RM350 | ACCOMMODATION | t10 | propose
爸爸 | 再看看 | DECISION | t10 | defer
""",
        "topics": {"t1": ("DESTINATION", "Tokyo", "confirmed"), "t2": ("DATE", "25-30 Mar", "rejected"),
                   "t3": ("DATE", "28 Mar - 2 Apr", "confirmed"), "t4": ("BUDGET", "6000 per person", "confirmed"),
                   "t5": ("ATTRACTION", "teamLab Planets", "pending"), "t6": ("ATTRACTION", "Senso-ji", "confirmed"),
                   "t7": ("TRANSPORT", "taxi", "rejected"), "t8": ("TRANSPORT", "metro with Suica", "confirmed"),
                   "t9": ("ACCOMMODATION", "Hilton Shinjuku", "pending"), "t10": ("ACCOMMODATION", "APA Ueno", "pending")},
        "prefs": [("妈妈", "doesn't want to save too much"), ("妈妈", "can't walk too much"),
                  ("妈妈", "wants to stay near a metro station")],
        "facts": {"destination": "Tokyo", "budget": 6000, "budget_basis": "per_person", "dates": "28 Mar - 2 Apr"},
    },
    {
        "id": "ch-04-bangkok", "destination": "Bangkok", "members": ["Ryan", "Zara", "Bryan", "Elaine", "Darren"],
        "lines": """
Ryan | ok serious now. Bangkok trip after finals. who's in | DESTINATION | t1 | propose
Zara | meee | DECISION | t1 | agree
Bryan | in | DECISION | t1 | agree
Elaine | in but I'm broke ah | DECISION | t1 | agree
Darren | lol same | OTHER | - | none
Ryan | budget RM1500 each max? airasia is cheap now | BUDGET | t2 | propose
Elaine | 1500 can | DECISION | t2 | agree
Darren | ok | DECISION | t2 | agree
Zara | ok | DECISION | t2 | agree
Bryan | anyone watched the match last night | OTHER | - | none
Darren | don't remind me 😭 | OTHER | - | none
Zara | Chatuchak weekend market!!! | ATTRACTION | t3 | propose
Elaine | yes shopping 🛍️ | DECISION | t3 | agree
Ryan | sure | DECISION | t3 | agree
Bryan | what about Safari World | ATTRACTION | t4 | propose
Darren | Safari World so far from city leh | DECISION | t4 | reject
Zara | not keen on animal shows also | DECISION | t4 | reject
Bryan | ok nvm then | DECISION | t4 | reject
Elaine | rooftop bar one night? Sky bar at lebua | ATTRACTION | t5 | propose
Ryan | expensive af but once in a lifetime ok | DECISION | t5 | agree
Darren | not bad, I'm in | DECISION | t5 | agree
Bryan | 我不喝酒，but can go see view | DECISION | t5 | agree
Zara | hostel or hotel? | ACCOMMODATION | - | ask
Ryan | Lub d Siam hostel, RM60 per night per person | ACCOMMODATION | t6 | propose
Elaine | hostel ok for me | DECISION | t6 | agree
Zara | I need my own room tho, cannot sleep with noise | PREFERENCE | - | none
Darren | then we take private room at Lub d? got 4 bed room | ACCOMMODATION | t7 | propose
Zara | ok that works | DECISION | t7 | agree
Ryan | yeah private room better | DECISION | t7 | agree
Bryan | ok | DECISION | t7 | agree
Ryan | BTS + grab to get around | TRANSPORT | t8 | propose
Elaine | tuk tuk once for the experience!! | TRANSPORT | t9 | propose
Darren | tuk tuk scam one la | DECISION | t9 | reject
""",
        "topics": {"t1": ("DESTINATION", "Bangkok", "confirmed"), "t2": ("BUDGET", "RM1500 each", "confirmed"),
                   "t3": ("ATTRACTION", "Chatuchak Weekend Market", "confirmed"), "t4": ("ATTRACTION", "Safari World", "rejected"),
                   "t5": ("ATTRACTION", "Sky Bar at lebua", "confirmed"), "t6": ("ACCOMMODATION", "Lub d Siam dorm", "rejected"),
                   "t7": ("ACCOMMODATION", "Lub d Siam private 4-bed room", "confirmed"),
                   "t8": ("TRANSPORT", "BTS and Grab", "pending"), "t9": ("TRANSPORT", "tuk tuk", "pending")},
        "prefs": [("Zara", "needs a quiet room")],
        "facts": {"destination": "Bangkok", "budget": 1500, "budget_basis": "per_person", "dates": None},
    },
    {
        "id": "ch-05-hanoi", "destination": "Hanoi", "members": ["Priya", "Marcus", "Lisa"],
        "lines": """
Priya | so Hanoi or Da Nang? | DESTINATION | t1 | propose
Marcus | Hanoi, then Ha Long Bay cruise | DESTINATION | t2 | propose
Lisa | Hanoi +1 | DECISION | t2 | agree
Priya | ok Hanoi it is 🇻🇳 | DECISION | t2 | finalize
Marcus | how many days ah | DATE | - | ask
Lisa | 5D4N enough | DATE | t3 | propose
Priya | 5D4N ok, maybe early Oct? | DATE | t4 | propose
Marcus | early oct I can, need to apply leave early | DECISION | t4 | agree
Lisa | I'll confirm my leave next week | DECISION | t4 | defer
Marcus | Ha Long overnight cruise around RM600 per person | ATTRACTION | t5 | propose
Lisa | worth it!! | DECISION | t5 | agree
Priya | ok but only if the cabin got window 😂 | DECISION | t5 | agree
Marcus | lol all got window | OTHER | - | none
Lisa | old quarter walking food tour one night? | ATTRACTION | t6 | propose
Priya | yesss egg coffee | DECISION | t6 | agree
Marcus | I'm vegetarian, can find veg food? | PREFERENCE | - | none
Lisa | got, I check for you | OTHER | - | none
Priya | rent motorbike to go around? | TRANSPORT | t7 | propose
Marcus | no way, the traffic there crazy | DECISION | t7 | reject
Lisa | grab bike cheaper and safer | TRANSPORT | t8 | propose
Priya | ok grab then | DECISION | t8 | agree
Marcus | budget for whole trip? I'm thinking RM2500 each | BUDGET | t9 | propose
Priya | hmm let's see after flight price | DECISION | t9 | defer
""",
        "topics": {"t1": ("DESTINATION", "Da Nang", "rejected"), "t2": ("DESTINATION", "Hanoi", "confirmed"),
                   "t3": ("DATE", "5D4N", "pending"), "t4": ("DATE", "early Oct", "pending"),
                   "t5": ("ATTRACTION", "Ha Long Bay overnight cruise", "confirmed"),
                   "t6": ("ATTRACTION", "Old Quarter food tour", "confirmed"), "t7": ("TRANSPORT", "rent motorbike", "rejected"),
                   "t8": ("TRANSPORT", "Grab bike", "confirmed"), "t9": ("BUDGET", "RM2500 each", "pending")},
        "prefs": [("Marcus", "is vegetarian")],
        "facts": {"destination": "Hanoi", "budget": None, "budget_basis": None, "dates": None},
    },
    {
        "id": "ch-06-bali", "destination": "Bali", "members": ["Natasha", "Kelvin", "Grace", "Oscar"],
        "lines": """
Natasha | Bali for our anniversary trip with you two? 🥂 | DESTINATION | t1 | propose
Grace | omg yes | DECISION | t1 | agree
Oscar | ok, can | DECISION | t1 | agree
Kelvin | sure | DECISION | t1 | agree
Grace | villa with private pool in Seminyak, RM900 a night for 2 bedrooms | ACCOMMODATION | t2 | propose
Kelvin | ok if we split 4 ways | DECISION | t2 | agree
Oscar | can lah | DECISION | t2 | agree
Natasha | Ubud also? 2 nights there for rice terrace | ATTRACTION | t3 | propose
Grace | Ubud yes, Tegallalang rice terrace in the morning | DECISION | t3 | agree
Kelvin | I'm fine either way | DECISION | t3 | agree
Oscar | swing photo thing at Ubud 😂 | ATTRACTION | t4 | propose
Natasha | hahaha | OTHER | - | none
Kelvin | can we hire a driver for the days we move around | TRANSPORT | t5 | propose
Grace | yes driver better, around RM200 per day | DECISION | t5 | agree
Natasha | agree | DECISION | t5 | agree
Oscar | 👍 | DECISION | t5 | agree
Natasha | I prefer chill beach days, not too packed | PREFERENCE | - | none
Grace | dates still 20-25 Aug right? | DATE | t6 | propose
Oscar | 20-25 Aug confirmed on my side | DECISION | t6 | agree
Kelvin | I need to check with my boss first | DECISION | t6 | defer
Natasha | I'm ok | DECISION | t6 | agree
Grace | Uluwatu temple sunset + kecak dance? | ATTRACTION | t7 | propose
Kelvin | heard the monkeys steal stuff there 😅 | ATTRACTION | t7 | info
""",
        "topics": {"t1": ("DESTINATION", "Bali", "confirmed"), "t2": ("ACCOMMODATION", "pool villa in Seminyak", "confirmed"),
                   "t3": ("ATTRACTION", "Ubud and Tegallalang rice terrace", "confirmed"),
                   "t4": ("ATTRACTION", "Bali swing", "pending"), "t5": ("TRANSPORT", "private driver", "confirmed"),
                   "t6": ("DATE", "20-25 Aug", "pending"), "t7": ("ATTRACTION", "Uluwatu temple sunset and kecak dance", "pending")},
        "prefs": [("Natasha", "wants a relaxed schedule")],
        "facts": {"destination": "Bali", "budget": None, "budget_basis": None, "dates": None},
    },
]


def apply_consent_definition(topics, msgs):
    """These chats were first labelled with a majority rule ("pending" unless more
    than half agreed). The project now defines a decision as "proposed and nobody
    argued against it" (see decision_rule). Topics a human marked confirmed or
    rejected keep that label; topics marked pending are re-decided from their
    gold stances with the new definition."""
    from common import SINGLE_VALUE
    from generate_template_data import decision_rule
    order = {m["id"]: i for i, m in enumerate(msgs)}
    stances = {t["id"]: [] for t in topics}
    for m in msgs:
        if m["topic"] in stances and m["stance"] in ("propose", "agree", "reject", "defer", "finalize"):
            stances[m["topic"]].append((m["speaker"], m["stance"]))
    for t in topics:
        if t["status"] == "pending":
            t["status"] = decision_rule(t, stances[t["id"]], 0, False)
    for t in topics:  # a later agreed option replaces an earlier one of the same kind
        if t["category"] in SINGLE_VALUE and t["status"] != "rejected" and any(
                u["category"] == t["category"] and order[u["proposal"]] > order[t["proposal"]]
                and u["status"] == "confirmed" for u in topics):
            t["status"] = "rejected"


def to_convs(chats, source):
    """Turns the compact line format into dataset conversations."""
    from generate_template_data import reference_summary
    out = []
    for ch in chats:
        msgs = []
        for i, line in enumerate([l for l in ch["lines"].strip().splitlines() if l.strip()]):
            parts = [p.strip() for p in line.split(" | ")]
            if len(parts) != 5:
                raise ValueError(f"{ch['id']} line {i + 1}: expected 5 fields: {line}")
            speaker, text, label, topic, stance = parts
            msgs.append({"id": f"m{i + 1:03d}", "speaker": speaker, "text": text, "label": label,
                         "topic": None if topic == "-" else topic, "stance": stance})
        topics = []
        for tid, (cat, value, status) in ch["topics"].items():
            prop = next(m["id"] for m in msgs if m["topic"] == tid and m["stance"] == "propose")
            topics.append({"id": tid, "category": cat, "value": value, "proposal": prop, "status": status})
        apply_consent_definition(topics, msgs)
        prefs = []
        for who, text in ch["prefs"]:
            mid = next(m["id"] for m in msgs if m["speaker"] == who and m["label"] == "PREFERENCE"
                       and m["id"] not in {p["message"] for p in prefs})
            prefs.append({"speaker": who, "text": text, "message": mid})
        out.append({"conv_id": ch["id"], "source": source, "destination": ch["destination"], "members": ch["members"],
                    "messages": msgs, "topics": topics, "preferences": prefs, "facts": ch["facts"],
                    "reference_summary": reference_summary(topics, prefs)})
    return out




# ---------------------------------------------------------------------------
# Second challenge set. Written before the final training round (manual_data.py
# batch 2) and never used to change the model, the lexicons or the rules.
# ---------------------------------------------------------------------------
CHATS2 = [
    {"id": "ch2-01-danang", "destination": "Da Nang", "members": ["Kelly", "Irfan", "Bao", "Shirley"], "lines": """
Kelly | ok team, Da Nang in March? flights super cheap now | DESTINATION | t1 | propose
Irfan | Da Nang + Hoi An, I'm game | DECISION | t1 | agree
Bao | my hometown 😎 I can be your guide | DECISION | t1 | agree
Shirley | count me in!! | DECISION | t1 | agree
Bao | 12 to 16 March got a festival in Hoi An | DATE | t2 | propose
Shirley | 12-16 Mar perfect | DECISION | t2 | agree
Irfan | can, apply leave already | DECISION | t2 | agree
Kelly | budget per pax RM2200? | BUDGET | t3 | propose
Irfan | should be ok, Vietnam cheap | DECISION | t3 | agree
Shirley | yup | DECISION | t3 | agree
Bao | Ba Na Hills with the golden bridge | ATTRACTION | t4 | propose
Kelly | ticket quite expensive leh, around RM400 | ATTRACTION | t4 | info
Shirley | but the golden bridge 😍 must take photo | DECISION | t4 | agree
Irfan | I'm fine with it | DECISION | t4 | agree
Bao | Hoi An old town at night, lanterns | ATTRACTION | t5 | propose
Kelly | yes yes | DECISION | t5 | agree
Irfan | I need halal food ya, can find? | PREFERENCE | - | none
Bao | got a few halal places near My Khe beach | OTHER | - | none
Shirley | hotel near My Khe beach then? | ACCOMMODATION | t6 | propose
Kelly | beach hotel 👍 | DECISION | t6 | agree
Irfan | ok | DECISION | t6 | agree
Bao | Grab bike is the cheapest way around | TRANSPORT | t7 | propose
Shirley | I scared of bikes, Grab car can? | TRANSPORT | t8 | propose
Kelly | Grab car la, 4 of us share also cheap | DECISION | t8 | agree
Irfan | agree car | DECISION | t8 | agree
""", "topics": {"t1": ("DESTINATION", "Da Nang", "confirmed"), "t2": ("DATE", "12-16 Mar", "confirmed"),
                "t3": ("BUDGET", "RM2200 per person", "confirmed"), "t4": ("ATTRACTION", "Ba Na Hills golden bridge", "confirmed"),
                "t5": ("ATTRACTION", "Hoi An old town at night", "pending"), "t6": ("ACCOMMODATION", "hotel near My Khe beach", "confirmed"),
                "t7": ("TRANSPORT", "Grab bike", "rejected"), "t8": ("TRANSPORT", "Grab car", "confirmed")},
     "prefs": [("Irfan", "needs halal food")],
     "facts": {"destination": "Da Nang", "budget": 2200, "budget_basis": "per_person", "dates": "12-16 Mar"}},

    {"id": "ch2-02-chiangmai", "destination": "Chiang Mai", "members": ["Yen", "Hui Ling", "Dennis"], "lines": """
Yen | 清迈怎么样？我想去大象保护区 | DESTINATION | t1 | propose
Hui Ling | 好啊，我也一直想去 | DECISION | t1 | agree
Dennis | Chiang Mai can, but not elephant riding ya, ethical one only | DECISION | t1 | agree
Yen | 当然，是那种只喂食洗澡的 | ATTRACTION | t2 | propose
Dennis | ok then I'm in for elephant nature park | DECISION | t2 | agree
Hui Ling | 我们几时去？ | DATE | - | ask
Yen | 十一月初，天气比较凉 | DATE | t3 | propose
Dennis | early Nov I have a work trip, end Nov? | DATE | t4 | propose
Hui Ling | 11月底我可以 | DECISION | t4 | agree
Yen | ok 月底 | DECISION | t4 | agree
Dennis | Doi Suthep temple on the mountain | ATTRACTION | t5 | propose
Hui Ling | 素贴山的庙对吗？好 | DECISION | t5 | agree
Yen | Sunday walking street market 一定要 | ATTRACTION | t6 | propose
Dennis | only on Sunday ya, need plan the dates around it | ATTRACTION | t6 | info
Hui Ling | 我不能吃太辣 | PREFERENCE | - | none
Dennis | Thai food all spicy one 😂 | OTHER | - | none
Yen | 住古城里面的民宿，一晚大概RM150 | ACCOMMODATION | t7 | propose
Hui Ling | 古城方便，可以 | DECISION | t7 | agree
Dennis | whatever you guys decide | DECISION | t7 | defer
Yen | 租摩托车？ | TRANSPORT | t8 | propose
Hui Ling | 我不会骑 | DECISION | t8 | reject
Dennis | songthaew red truck everywhere, cheap | TRANSPORT | t9 | propose
""", "topics": {"t1": ("DESTINATION", "Chiang Mai", "confirmed"), "t2": ("ATTRACTION", "ethical elephant sanctuary", "confirmed"),
                "t3": ("DATE", "early Nov", "rejected"), "t4": ("DATE", "end Nov", "confirmed"),
                "t5": ("ATTRACTION", "Doi Suthep", "confirmed"), "t6": ("ATTRACTION", "Sunday walking street", "pending"),
                "t7": ("ACCOMMODATION", "guesthouse in the old city", "confirmed"), "t8": ("TRANSPORT", "rent motorbike", "rejected"),
                "t9": ("TRANSPORT", "songthaew", "pending")},
     "prefs": [("Hui Ling", "can't eat very spicy food")],
     "facts": {"destination": "Chiang Mai", "budget": None, "budget_basis": None, "dates": "end Nov"}},

    {"id": "ch2-03-cameron", "destination": "Cameron Highlands", "members": ["Rashid", "Pei Shan", "Victor", "Liyana", "Gary"], "lines": """
Rashid | weekend escape to Cameron? need cold air 🥶 | DESTINATION | t1 | propose
Pei Shan | yes pls KL so hot | DECISION | t1 | agree
Victor | can | DECISION | t1 | agree
Liyana | on | DECISION | t1 | agree
Gary | I might have to work Saturday, see first | DECISION | t1 | defer
Rashid | 22-23 Nov | DATE | t2 | propose
Pei Shan | ok | DECISION | t2 | agree
Liyana | ok | DECISION | t2 | agree
Victor | 22-23 can | DECISION | t2 | agree
Victor | I drive my MPV, 7 seater | TRANSPORT | t3 | propose
Liyana | wah thanks Victor | DECISION | t3 | agree
Pei Shan | I get carsick on the winding road 😵 | PREFERENCE | - | none
Rashid | sit in front la | OTHER | - | none
Liyana | BOH tea plantation for sure | ATTRACTION | t4 | propose
Pei Shan | the scones there 🤤 | DECISION | t4 | agree
Rashid | Mossy forest also | ATTRACTION | t5 | propose
Victor | mossy forest road bad, need 4x4 tour, RM70 each | ATTRACTION | t5 | info
Liyana | hmm expensive for half day | DECISION | t5 | reject
Rashid | ok drop mossy forest | DECISION | t5 | reject
Pei Shan | strawberry farm! | ATTRACTION | t6 | propose
Victor | very touristy but ok la | DECISION | t6 | agree
Liyana | apartment in Brinchang, RM380 one night, 3 rooms | ACCOMMODATION | t7 | propose
Victor | Brinchang near night market, good | DECISION | t7 | agree
Rashid | fine | DECISION | t7 | agree
Pei Shan | ok I'm in | DECISION | t7 | agree
Gary | ok boss let me off, I'm joining!! | DECISION | t1 | agree
""", "topics": {"t1": ("DESTINATION", "Cameron Highlands", "confirmed"), "t2": ("DATE", "22-23 Nov", "confirmed"),
                "t3": ("TRANSPORT", "Victor drives MPV", "pending"), "t4": ("ATTRACTION", "BOH tea plantation", "pending"),
                "t5": ("ATTRACTION", "Mossy forest", "rejected"), "t6": ("ATTRACTION", "strawberry farm", "pending"),
                "t7": ("ACCOMMODATION", "apartment in Brinchang", "confirmed")},
     "prefs": [("Pei Shan", "gets carsick")],
     "facts": {"destination": "Cameron Highlands", "budget": None, "budget_basis": None, "dates": "22-23 Nov"}},

    {"id": "ch2-04-kuching", "destination": "Kuching", "members": ["Nora", "Alvin", "Syafiq"], "lines": """
Alvin | Kuching for Rainforest Music Festival? July | DESTINATION | t1 | propose
Nora | omg yes I always wanted to go RWMF | DECISION | t1 | agree
Syafiq | festival ticket how much ah | ATTRACTION | - | ask
Alvin | 3 day pass around RM400 | ATTRACTION | t2 | propose
Syafiq | ok worth it for 3 days | DECISION | t2 | agree
Nora | buy early bird! | DECISION | t2 | agree
Alvin | festival is 11-13 July, we go 10 to 14 July | DATE | t3 | propose
Nora | 10-14 Jul ok | DECISION | t3 | agree
Syafiq | ok | DECISION | t3 | agree
Syafiq | total budget RM1800 per person cukup? | BUDGET | t4 | propose
Nora | should be enough | DECISION | t4 | agree
Alvin | ok RM1800 | DECISION | t4 | agree
Nora | Bako national park to see proboscis monkeys | ATTRACTION | t5 | propose
Syafiq | need boat to get there, weather dependent | ATTRACTION | t5 | info
Alvin | if weather ok we go | DECISION | t5 | agree
Nora | Sarawak laksa every morning 😋 | PREFERENCE | - | none
Syafiq | homestay at Damai near the festival | ACCOMMODATION | t6 | propose
Alvin | Damai all fully booked already 😭 | ACCOMMODATION | t6 | info
Nora | then stay in Kuching city and take the shuttle | ACCOMMODATION | t7 | propose
Syafiq | ok city hotel + shuttle | DECISION | t7 | agree
Alvin | agree | DECISION | t7 | agree
""", "topics": {"t1": ("DESTINATION", "Kuching", "confirmed"), "t2": ("ATTRACTION", "RWMF 3-day pass", "confirmed"),
                "t3": ("DATE", "10-14 Jul", "confirmed"), "t4": ("BUDGET", "RM1800 per person", "confirmed"),
                "t5": ("ATTRACTION", "Bako national park", "confirmed"), "t6": ("ACCOMMODATION", "homestay at Damai", "rejected"),
                "t7": ("ACCOMMODATION", "hotel in Kuching city + shuttle", "confirmed")},
     "prefs": [("Nora", "wants Sarawak laksa every morning")],
     "facts": {"destination": "Kuching", "budget": 1800, "budget_basis": "per_person", "dates": "10-14 Jul"}},

    {"id": "ch2-05-perth", "destination": "Perth", "members": ["Esther", "Wai Kit", "Jo", "Hamid"], "lines": """
Esther | Perth road trip next year? or Melbourne? | DESTINATION | t1 | propose
Wai Kit | Perth! Melbourne went already | DECISION | t1 | agree
Jo | Perth la, can see quokka 🐹 | DECISION | t1 | agree
Hamid | either ok for me | DECISION | t1 | defer
Esther | ok Perth it is | DECISION | t1 | finalize
Wai Kit | rent a campervan? | TRANSPORT | t2 | propose
Jo | campervan sounds fun but I need proper bed and shower 😅 | DECISION | t2 | reject
Hamid | campervan got shower one also | TRANSPORT | t2 | info
Esther | normal car + motels easier | TRANSPORT | t3 | propose
Jo | car + motel yes | DECISION | t3 | agree
Hamid | ok car | DECISION | t3 | agree
Wai Kit | ok lah car | DECISION | t3 | agree
Jo | Rottnest island for quokka selfie | ATTRACTION | t4 | propose
Esther | yesss | DECISION | t4 | agree
Hamid | ferry around AUD80 return | ATTRACTION | t4 | info
Wai Kit | Pinnacles desert drive up north | ATTRACTION | t5 | propose
Hamid | 2.5 hours drive each way hmm | DECISION | t5 | defer
Esther | budget around RM6000 each? AUD exchange rate bad now | BUDGET | t6 | propose
Wai Kit | 6k ok | DECISION | t6 | agree
Jo | 6k a bit much, 5k? | BUDGET | t7 | propose
Hamid | 5k can if we cook some meals | DECISION | t7 | agree
Esther | let's see after we check flight prices | DECISION | t7 | defer
Jo | I don't drive on the highway, too scared | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Perth", "confirmed"), "t2": ("TRANSPORT", "campervan", "rejected"),
                "t3": ("TRANSPORT", "car + motels", "confirmed"), "t4": ("ATTRACTION", "Rottnest island", "pending"),
                "t5": ("ATTRACTION", "Pinnacles desert", "pending"), "t6": ("BUDGET", "RM6000 each", "pending"),
                "t7": ("BUDGET", "RM5000 each", "pending")},
     "prefs": [("Jo", "won't drive on highways")],
     "facts": {"destination": "Perth", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "ch2-06-hokkaido", "destination": "Hokkaido", "members": ["妈妈", "爸爸", "Wei Ming", "Jasmine"], "lines": """
Wei Ming | 爸妈，过年去北海道看雪好不好？ | DESTINATION | t1 | propose
爸爸 | 很冷吧？ | OTHER | - | none
Jasmine | 冷才好玩啦，爸你没看过雪 | DECISION | t1 | agree
妈妈 | 我想去！ | DECISION | t1 | agree
爸爸 | 好啦好啦 | DECISION | t1 | agree
Wei Ming | 2月1号到7号，7天 | DATE | t2 | propose
Jasmine | 可以 | DECISION | t2 | agree
妈妈 | 我们都退休了随便 | DECISION | t2 | agree
Wei Ming | 札幌雪祭刚好2月初 | ATTRACTION | t3 | propose
Jasmine | Sapporo snow festival 👍👍 | DECISION | t3 | agree
妈妈 | 小樽运河也要去 | ATTRACTION | t4 | propose
爸爸 | 好 | DECISION | t4 | agree
Jasmine | 滑雪？ | ATTRACTION | t5 | propose
爸爸 | 我这把老骨头不要了 | DECISION | t5 | reject
妈妈 | 我也不要 | DECISION | t5 | reject
Wei Ming | 坐JR火车，买JR Pass | TRANSPORT | t6 | propose
Jasmine | JR pass 现在涨价了，算一下再说 | DECISION | t6 | defer
妈妈 | 酒店要有温泉的 | PREFERENCE | - | none
Wei Ming | 定山溪温泉酒店，一晚RM900 | ACCOMMODATION | t7 | propose
爸爸 | 太贵了 | DECISION | t7 | reject
Jasmine | 住两晚温泉就好，其他住札幌便宜的 | ACCOMMODATION | t8 | propose
妈妈 | 这个好 | DECISION | t8 | agree
爸爸 | 可以 | DECISION | t8 | agree
""", "topics": {"t1": ("DESTINATION", "Hokkaido", "confirmed"), "t2": ("DATE", "1-7 Feb", "confirmed"),
                "t3": ("ATTRACTION", "Sapporo snow festival", "pending"), "t4": ("ATTRACTION", "Otaru canal", "pending"),
                "t5": ("ATTRACTION", "skiing", "rejected"), "t6": ("TRANSPORT", "JR Pass", "pending"),
                "t7": ("ACCOMMODATION", "Jozankei onsen hotel all nights", "rejected"),
                "t8": ("ACCOMMODATION", "2 nights onsen + cheaper Sapporo hotel", "confirmed")},
     "prefs": [("妈妈", "wants a hotel with hot spring")],
     "facts": {"destination": "Hokkaido", "budget": None, "budget_basis": None, "dates": "1-7 Feb"}},
]


def build():
    for chats, name in ((CHATS, "challenge"), (CHATS2, "challenge2")):
        out = to_convs(chats, "challenge")
        write_jsonl(DATA / f"{name}.jsonl", out)
        print(f"wrote {len(out)} {name} chats, {sum(len(c['messages']) for c in out)} messages")


if __name__ == "__main__":
    build()
