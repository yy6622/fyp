"""Second batch of hand-written TRAINING chats (16 chats), written after
test_challenge2 was frozen. Imported by manual_data.py."""

CHATS_BATCH2 = [
    {"id": "man-13-krabi", "destination": "Krabi", "members": ["Lina", "Hong", "Rizal", "Peggy"], "lines": """
Lina | Krabi for CNY holidays anyone? | DESTINATION | t1 | propose
Hong | CNY flights expensive leh, check first | DECISION | t1 | defer
Rizal | I checked, RM600 return still ok | TRANSPORT | - | info
Hong | ok then I'm in | DECISION | t1 | agree
Peggy | me too | DECISION | t1 | agree
Rizal | Krabi it is then | DECISION | t1 | finalize
Peggy | Ao Nang area for hotel, all the boats leave from there | ACCOMMODATION | t2 | propose
Lina | Ao Nang 👍 | DECISION | t2 | agree
Hong | sure | DECISION | t2 | agree
Rizal | 4 islands tour by longtail boat | ATTRACTION | t3 | propose
Peggy | how long is the tour? | ATTRACTION | - | ask
Rizal | half day, around 1000 baht | ATTRACTION | t3 | info
Lina | ok can | DECISION | t3 | agree
Hong | I can't swim btw, need life jacket | PREFERENCE | - | none
Peggy | Tiger Cave temple, 1260 steps 😱 | ATTRACTION | t4 | propose
Hong | 1260 steps?? no thank you | DECISION | t4 | reject
Lina | I'll go with Peggy, the rest can chill | DECISION | t4 | agree
Rizal | up to you guys | DECISION | t4 | defer
Lina | budget? I'm thinking RM2500 each | BUDGET | t5 | propose
Peggy | 2.5k fine | DECISION | t5 | agree
Rizal | ok | DECISION | t5 | agree
Hong | ok RM2500 then | DECISION | t5 | finalize
""", "topics": {"t1": ("DESTINATION", "Krabi", "confirmed"), "t2": ("ACCOMMODATION", "Ao Nang", "confirmed"),
                "t3": ("ATTRACTION", "4 islands tour", "pending"), "t4": ("ATTRACTION", "Tiger Cave temple", "pending"),
                "t5": ("BUDGET", "RM2500 each", "confirmed")},
     "prefs": [("Hong", "can't swim")],
     "facts": {"destination": "Krabi", "budget": 2500, "budget_basis": "per_person", "dates": None}},

    {"id": "man-14-singapore", "destination": "Singapore", "members": ["Farid", "Celine", "Ah Boy"], "lines": """
Celine | SG weekend? take the bus from TBS | DESTINATION | t1 | propose
Farid | why not | DECISION | t1 | agree
Ah Boy | 可以啊 | DECISION | t1 | agree
Farid | bus or ETS + RTS? the causeway jam teruk on Friday | TRANSPORT | - | ask
Celine | bus at 7am Saturday, should be ok | TRANSPORT | t3 | propose
Ah Boy | ok 7am bus | DECISION | t3 | agree
Farid | ok set | DECISION | t3 | agree
Ah Boy | Universal Studios? | ATTRACTION | t4 | propose
Celine | USS ticket SGD 80+, pricey | ATTRACTION | t4 | info
Farid | I went already, pass | DECISION | t4 | reject
Celine | Gardens by the Bay light show is free | ATTRACTION | t5 | propose
Farid | free is good 😂 | DECISION | t5 | agree
Ah Boy | 好 | DECISION | t5 | agree
Ah Boy | 我想去吃Maxwell的海南鸡饭 | ATTRACTION | t6 | propose
Celine | Tian Tian chicken rice! queue but worth it | DECISION | t6 | agree
Farid | I need halal, Maxwell got halal stalls? | PREFERENCE | - | none
Celine | got a few, don't worry | OTHER | - | none
Farid | stay where? hostel in Bugis around SGD 40 | ACCOMMODATION | t7 | propose
Ah Boy | Bugis ok, near MRT | DECISION | t7 | agree
Celine | ok book Bugis | DECISION | t7 | finalize
Ah Boy | 带多少钱？每人RM800够吗 | BUDGET | t8 | propose
Celine | 800 enough for 2 days | DECISION | t8 | agree
""", "topics": {"t1": ("DESTINATION", "Singapore", "confirmed"), "t3": ("TRANSPORT", "7am bus Saturday", "confirmed"),
                "t4": ("ATTRACTION", "Universal Studios", "rejected"), "t5": ("ATTRACTION", "Gardens by the Bay light show", "confirmed"),
                "t6": ("ATTRACTION", "Maxwell Tian Tian chicken rice", "confirmed"), "t7": ("ACCOMMODATION", "hostel in Bugis", "confirmed"),
                "t8": ("BUDGET", "RM800 per person", "confirmed")},
     "prefs": [("Farid", "needs halal food")],
     "facts": {"destination": "Singapore", "budget": 800, "budget_basis": "per_person", "dates": None}},

    {"id": "man-15-busan", "destination": "Busan", "members": ["Min", "Haziq", "Sarah", "Eugene"], "lines": """
Min | Busan this autumn 🍂 | DESTINATION | t1 | propose
Sarah | yes!! Gamcheon village is so pretty | DECISION | t1 | agree
Eugene | I'm in | DECISION | t1 | agree
Haziq | ok | DECISION | t1 | agree
Eugene | when? I can only go after 20 Oct | DATE | - | info
Min | 25-30 Oct then | DATE | t2 | propose
Sarah | 25 to 30 ok | DECISION | t2 | agree
Haziq | 25-30 Oct confirm | DECISION | t2 | finalize
Sarah | Gamcheon culture village | ATTRACTION | t3 | propose
Eugene | lots of uphill walking there fyi | ATTRACTION | t3 | info
Haziq | ok no problem | DECISION | t3 | agree
Min | Haeundae beach + Blueline park sky capsule | ATTRACTION | t4 | propose
Sarah | the sky capsule need to book early, sold out fast | ATTRACTION | t4 | info
Eugene | book it la | DECISION | t4 | agree
Haziq | Jagalchi fish market for seafood | ATTRACTION | t5 | propose
Min | I'm allergic to seafood 😭 | PREFERENCE | - | none
Haziq | oh then skip la | DECISION | t5 | reject
Sarah | Airbnb in Seomyeon, KRW 120000 a night for 4 | ACCOMMODATION | t6 | propose
Eugene | Seomyeon central, ok | DECISION | t6 | agree
Min | ok | DECISION | t6 | agree
Haziq | ok | DECISION | t6 | agree
Eugene | T-money card for subway and bus | TRANSPORT | t7 | propose
""", "topics": {"t1": ("DESTINATION", "Busan", "confirmed"), "t2": ("DATE", "25-30 Oct", "confirmed"),
                "t3": ("ATTRACTION", "Gamcheon culture village", "pending"), "t4": ("ATTRACTION", "Haeundae + sky capsule", "pending"),
                "t5": ("ATTRACTION", "Jagalchi fish market", "rejected"), "t6": ("ACCOMMODATION", "Airbnb in Seomyeon", "confirmed"),
                "t7": ("TRANSPORT", "T-money card", "pending")},
     "prefs": [("Min", "is allergic to seafood")],
     "facts": {"destination": "Busan", "budget": None, "budget_basis": None, "dates": "25-30 Oct"}},

    {"id": "man-16-tioman", "destination": "Tioman", "members": ["Hakimi", "Zarina", "Fikri"], "lines": """
Zarina | jom snorkeling Pulau Tioman bulan Mei | DESTINATION | t1 | propose
Hakimi | best! | DECISION | t1 | agree
Fikri | aku on | DECISION | t1 | agree
Hakimi | feri dari Mersing, kena book awal | TRANSPORT | t2 | propose
Fikri | ok aku book feri | DECISION | t2 | finalize
Zarina | 2 hingga 5 Mei boleh? | DATE | t3 | propose
Fikri | 2-5 Mei aku kerja, 9 hingga 12 Mei? | DATE | t4 | propose
Zarina | 9-12 boleh | DECISION | t4 | agree
Hakimi | ok 9-12 Mei | DECISION | t4 | agree
Hakimi | chalet tepi pantai Salang, RM180 semalam | ACCOMMODATION | t5 | propose
Zarina | Salang ok, snorkel depan chalet je | DECISION | t5 | agree
Fikri | setuju | DECISION | t5 | agree
Zarina | aku tak reti berenang sangat, nak life jacket | PREFERENCE | - | none
Fikri | Coral Island snorkeling trip | ATTRACTION | t6 | propose
Hakimi | wajib! | DECISION | t6 | agree
Zarina | Asah waterfall? | ATTRACTION | t7 | propose
Hakimi | jauh tu, kena naik bot lagi | ATTRACTION | t7 | info
Fikri | nanti tengok masa | DECISION | t7 | defer
Hakimi | budget RM900 seorang including feri | BUDGET | t8 | propose
Zarina | ok | DECISION | t8 | agree
Fikri | ok cukup | DECISION | t8 | agree
""", "topics": {"t1": ("DESTINATION", "Tioman", "confirmed"), "t2": ("TRANSPORT", "ferry from Mersing", "confirmed"),
                "t3": ("DATE", "2-5 May", "rejected"), "t4": ("DATE", "9-12 May", "confirmed"),
                "t5": ("ACCOMMODATION", "chalet at Salang", "confirmed"), "t6": ("ATTRACTION", "Coral Island snorkeling", "confirmed"),
                "t7": ("ATTRACTION", "Asah waterfall", "pending"), "t8": ("BUDGET", "RM900 per person", "confirmed")},
     "prefs": [("Zarina", "is not a strong swimmer")],
     "facts": {"destination": "Tioman", "budget": 900, "budget_basis": "per_person", "dates": "9-12 May"}},

    {"id": "man-17-guilin", "destination": "Guilin", "members": ["林叔", "Grace", "Benjamin", "阿芳"], "lines": """
Grace | 叔叔阿姨，明年四月去桂林好吗？ | DESTINATION | t1 | propose
林叔 | 桂林山水甲天下，好！ | DECISION | t1 | agree
阿芳 | 我没意见 | DECISION | t1 | agree
Benjamin | Guilin ok, I'll handle the booking | DECISION | t1 | agree
Grace | 漓江游船一定要坐 | ATTRACTION | t2 | propose
林叔 | 对，坐船到阳朔 | DECISION | t2 | agree
阿芳 | 好 | DECISION | t2 | agree
Benjamin | the Li River cruise is around RMB 300 per person | ATTRACTION | t2 | info
Benjamin | 阳朔住两晚，西街附近 | ACCOMMODATION | t3 | propose
阿芳 | 西街太吵了，我睡不着 | DECISION | t3 | reject
Grace | 那住遇龙河边的民宿，比较安静 | ACCOMMODATION | t4 | propose
阿芳 | 这个好 | DECISION | t4 | agree
林叔 | 可以 | DECISION | t4 | agree
Benjamin | ok 遇龙河 then | DECISION | t4 | finalize
林叔 | 我想去看印象刘三姐 | ATTRACTION | t5 | propose
Grace | 晚上的表演，可以 | DECISION | t5 | agree
阿芳 | 我晚上容易累，不要太晚 | PREFERENCE | - | none
Benjamin | from KL fly to Guilin direct, AirAsia | TRANSPORT | t6 | propose
Grace | 直飞最好，爸妈不用转机 | DECISION | t6 | agree
林叔 | 好 | DECISION | t6 | agree
""", "topics": {"t1": ("DESTINATION", "Guilin", "confirmed"), "t2": ("ATTRACTION", "Li River cruise", "confirmed"),
                "t3": ("ACCOMMODATION", "near West Street", "rejected"), "t4": ("ACCOMMODATION", "guesthouse by Yulong River", "confirmed"),
                "t5": ("ATTRACTION", "Impression Liu Sanjie show", "pending"), "t6": ("TRANSPORT", "direct AirAsia flight", "confirmed")},
     "prefs": [("阿芳", "gets tired at night")],
     "facts": {"destination": "Guilin", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-18-istanbul", "destination": "Istanbul", "members": ["Aisyah", "Omar", "Mei Lin", "Jake"], "lines": """
Aisyah | dream trip: Istanbul + Cappadocia hot air balloon 🎈 | DESTINATION | t1 | propose
Omar | I've wanted this forever | DECISION | t1 | agree
Jake | how much would it cost tho | BUDGET | - | ask
Aisyah | around RM7000 per person for 9 days | BUDGET | t2 | propose
Mei Lin | 7k is a lot for me, maybe RM5500? skip some paid stuff | BUDGET | t3 | propose
Jake | 5.5k doable if we take Turkish Airlines promo | DECISION | t3 | agree
Omar | ok 5500 | DECISION | t3 | agree
Aisyah | fine, RM5500 | DECISION | t3 | agree
Omar | the balloon ride alone is like RM1200 | BUDGET | t3 | info
Mei Lin | balloon is non negotiable 😂 | DECISION | t1 | agree
Jake | Hagia Sophia and Blue Mosque on day 1 | ATTRACTION | t4 | propose
Aisyah | yes, they're next to each other | DECISION | t4 | agree
Omar | agree | DECISION | t4 | agree
Mei Lin | Grand Bazaar shopping | ATTRACTION | t5 | propose
Jake | I hate bargaining lol, you guys go | DECISION | t5 | reject
Aisyah | domestic flight to Cappadocia, 1.5 hours | TRANSPORT | t6 | propose
Omar | flight better than 10 hours bus | DECISION | t6 | agree
Mei Lin | cave hotel in Göreme!! | ACCOMMODATION | t7 | propose
Jake | cave hotel 😍 | DECISION | t7 | agree
Omar | ok | DECISION | t7 | agree
Aisyah | September is the best weather, 5 to 13 Sep? | DATE | t8 | propose
Jake | let me check my leave | DECISION | t8 | defer
""", "topics": {"t1": ("DESTINATION", "Istanbul + Cappadocia", "confirmed"), "t2": ("BUDGET", "RM7000 per person", "rejected"),
                "t3": ("BUDGET", "RM5500", "confirmed"), "t4": ("ATTRACTION", "Hagia Sophia and Blue Mosque", "confirmed"),
                "t5": ("ATTRACTION", "Grand Bazaar", "pending"), "t6": ("TRANSPORT", "domestic flight to Cappadocia", "pending"),
                "t7": ("ACCOMMODATION", "cave hotel in Goreme", "confirmed"), "t8": ("DATE", "5-13 Sep", "pending")},
     "prefs": [],
     "facts": {"destination": "Istanbul", "budget": 5500, "budget_basis": "per_person", "dates": None}},

    {"id": "man-19-genting", "destination": "Genting", "members": ["Jia Yi", "Kumaran", "Adrian"], "lines": """
Adrian | Genting this Friday night? | DESTINATION | t1 | propose
Jia Yi | 好啊，好久没上去 | DECISION | t1 | agree
Kumaran | ok but come back Saturday ya, Sunday got family dinner | DECISION | t1 | agree
Adrian | Friday 7pm go up, Saturday evening come down | DATE | t2 | propose
Kumaran | ok | DECISION | t2 | agree
Jia Yi | 可以 | DECISION | t2 | agree
Jia Yi | 我开车 | TRANSPORT | t3 | propose
Adrian | the road up foggy at night, careful | TRANSPORT | t3 | info
Kumaran | or cable car from Gohtong Jaya? | TRANSPORT | t4 | propose
Jia Yi | 开车方便，回来不用等 | DECISION | t4 | reject
Adrian | ok drive | DECISION | t3 | agree
Kumaran | Skytropolis indoor park | ATTRACTION | t5 | propose
Adrian | outdoor theme park better, the new rides | ATTRACTION | t6 | propose
Jia Yi | outdoor 下雨就玩不了 | ATTRACTION | t6 | info
Kumaran | then indoor la | DECISION | t5 | agree
Jia Yi | 好 indoor | DECISION | t5 | agree
Kumaran | I'm vegetarian, there's a veggie place at SkyAvenue right? | PREFERENCE | - | none
Adrian | First World hotel cheapest, RM120 | ACCOMMODATION | t7 | propose
Jia Yi | First World ok la, just to sleep | DECISION | t7 | agree
Kumaran | 👍 | DECISION | t7 | agree
""", "topics": {"t1": ("DESTINATION", "Genting", "confirmed"), "t2": ("DATE", "Friday night to Saturday", "confirmed"),
                "t3": ("TRANSPORT", "Jia Yi drives", "confirmed"), "t4": ("TRANSPORT", "cable car", "rejected"),
                "t5": ("ATTRACTION", "Skytropolis indoor park", "confirmed"), "t6": ("ATTRACTION", "outdoor theme park", "pending"),
                "t7": ("ACCOMMODATION", "First World hotel", "confirmed")},
     "prefs": [("Kumaran", "is vegetarian")],
     "facts": {"destination": "Genting", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-20-london", "destination": "London", "members": ["Rebecca", "Shawn", "Nurin", "Daryl", "Wei"], "lines": """
Rebecca | Since Shawn is studying in London, let's visit him in December! | DESTINATION | t1 | propose
Shawn | YES please come, I can host 2 people in my flat | DECISION | t1 | agree
Nurin | flights are like RM4000 though 😬 | TRANSPORT | - | info
Daryl | if got promo I go | DECISION | t1 | agree
Wei | I'm in no matter what | DECISION | t1 | agree
Nurin | ok I'll try to save, count me in | DECISION | t1 | agree
Rebecca | 15 to 24 December, Christmas markets | DATE | t2 | propose
Shawn | my exams end 13 Dec so perfect | DECISION | t2 | agree
Daryl | ok | DECISION | t2 | agree
Wei | 15-24 can | DECISION | t2 | agree
Rebecca | budget RM9000 per person including flights | BUDGET | t3 | propose
Nurin | that's my max honestly | DECISION | t3 | agree
Wei | ok 9k | DECISION | t3 | agree
Daryl | ok | DECISION | t3 | agree
Shawn | 3 of you stay in an Airbnb near my place in Camden | ACCOMMODATION | t4 | propose
Wei | Camden is cool | DECISION | t4 | agree
Rebecca | ok sounds good | DECISION | t4 | agree
Daryl | day trip to Edinburgh by train? | ATTRACTION | t5 | propose
Shawn | 4.5 hours each way, better stay overnight | ATTRACTION | t5 | info
Nurin | too tiring, I'd rather stay in London | DECISION | t5 | reject
Wei | Harry Potter studio tour!! | ATTRACTION | t6 | propose
Rebecca | YES | DECISION | t6 | agree
Nurin | yes!! | DECISION | t6 | agree
Daryl | sure | DECISION | t6 | agree
Nurin | I get cold easily, need to buy a proper coat | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "London", "confirmed"), "t2": ("DATE", "15-24 Dec", "confirmed"),
                "t3": ("BUDGET", "RM9000 per person", "confirmed"), "t4": ("ACCOMMODATION", "Airbnb in Camden", "pending"),
                "t5": ("ATTRACTION", "Edinburgh day trip", "pending"), "t6": ("ATTRACTION", "Harry Potter studio tour", "confirmed")},
     "prefs": [("Nurin", "gets cold easily")],
     "facts": {"destination": "London", "budget": 9000, "budget_basis": "per_person", "dates": "15-24 Dec"}},

    {"id": "man-21-penang-food", "destination": "Penang", "members": ["Kenny", "Michelle", "Dinesh"], "lines": """
Michelle | 槟城吃东西之旅！下个月 | DESTINATION | t1 | propose
Kenny | 我要吃炒粿条 | DECISION | t1 | agree
Dinesh | in, as long as got nasi kandar | DECISION | t1 | agree
Kenny | 第一站：汕头街夜市 | ATTRACTION | t2 | propose
Michelle | Kimberley Street ok | DECISION | t2 | agree
Dinesh | Line Clear nasi kandar at 2am 😂 | ATTRACTION | t3 | propose
Michelle | 2am?? 我睡觉了 | DECISION | t3 | reject
Kenny | 我陪你去 | DECISION | t3 | agree
Michelle | 早餐去多春茶座 | ATTRACTION | t4 | propose
Kenny | Toh Soon 要排队哦 | ATTRACTION | t4 | info
Dinesh | queue also go | DECISION | t4 | agree
Kenny | 好 | DECISION | t4 | agree
Dinesh | stay at a heritage hotel in George Town | ACCOMMODATION | t5 | propose
Michelle | 太贵了吧，民宿就好 | ACCOMMODATION | t6 | propose
Kenny | 民宿ok | DECISION | t6 | agree
Dinesh | ok fine homestay | DECISION | t6 | agree
Kenny | 坐飞机还是开车？ | TRANSPORT | - | ask
Michelle | 开车，4个小时 | TRANSPORT | t7 | propose
Dinesh | I can share driving | DECISION | t7 | agree
Kenny | 我不吃牛 | PREFERENCE | - | none
Michelle | 每人带RM500应该够 | BUDGET | t8 | propose
Dinesh | 500 for food alone not enough 😂 | DECISION | t8 | reject
""", "topics": {"t1": ("DESTINATION", "Penang", "confirmed"), "t2": ("ATTRACTION", "Kimberley Street night market", "confirmed"),
                "t3": ("ATTRACTION", "Line Clear at 2am", "pending"), "t4": ("ATTRACTION", "Toh Soon cafe breakfast", "confirmed"),
                "t5": ("ACCOMMODATION", "heritage hotel", "rejected"), "t6": ("ACCOMMODATION", "homestay", "confirmed"),
                "t7": ("TRANSPORT", "drive", "confirmed"), "t8": ("BUDGET", "RM500 per person", "rejected")},
     "prefs": [("Kenny", "doesn't eat beef")],
     "facts": {"destination": "Penang", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-22-bali-chatter", "destination": "Bali", "members": ["Tiffany", "Hairul", "Cindy", "Brandon"], "lines": """
Tiffany | guys I just got my bonus 🤑 | OTHER | - | none
Hairul | belanja makan! | OTHER | - | none
Cindy | lol | OTHER | - | none
Tiffany | no la, but let's go Bali in August 🌴 | DESTINATION | t1 | propose
Brandon | finally a holiday | DECISION | t1 | agree
Cindy | Bali yes | DECISION | t1 | agree
Hairul | ok jom | DECISION | t1 | agree
Brandon | did anyone watch the new Marvel movie | OTHER | - | none
Cindy | not yet, no spoilers!! | OTHER | - | none
Tiffany | focus guys 😂 villa in Canggu? | ACCOMMODATION | t2 | propose
Cindy | Canggu nice cafes | DECISION | t2 | agree
Hairul | or Seminyak, more restaurants | ACCOMMODATION | t3 | propose
Brandon | I prefer Canggu, chill vibe | DECISION | t2 | agree
Hairul | ok Canggu lor | DECISION | t2 | agree
Cindy | surf lesson! | ATTRACTION | t4 | propose
Brandon | I'm in for surfing | DECISION | t4 | agree
Hairul | aku tengok je dari pantai 😂 | DECISION | t4 | reject
Tiffany | Mount Batur sunrise trek, start 2am | ATTRACTION | t5 | propose
Cindy | 2am?!?! | DECISION | t5 | reject
Brandon | it's worth it trust me | DECISION | t5 | agree
Hairul | I need to sleep at least 7 hours or I die | PREFERENCE | - | none
Tiffany | lol ok we decide later | DECISION | t5 | defer
""", "topics": {"t1": ("DESTINATION", "Bali", "confirmed"), "t2": ("ACCOMMODATION", "villa in Canggu", "confirmed"),
                "t3": ("ACCOMMODATION", "Seminyak", "rejected"), "t4": ("ATTRACTION", "surf lesson", "pending"),
                "t5": ("ATTRACTION", "Mount Batur sunrise trek", "pending")},
     "prefs": [("Hairul", "needs enough sleep")],
     "facts": {"destination": "Bali", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-23-semporna", "destination": "Semporna", "members": ["Yong", "Atiqah", "Mark"], "lines": """
Atiqah | Semporna diving trip, Sipadan permit need to apply early | DESTINATION | t1 | propose
Mark | Sipadan is my bucket list | DECISION | t1 | agree
Yong | I don't have diving license leh | PREFERENCE | - | none
Atiqah | can do snorkeling, or take a discover scuba course | ATTRACTION | t2 | propose
Yong | discover scuba ok, I try | DECISION | t2 | agree
Mark | fly KL to Tawau then 1 hour van to Semporna | TRANSPORT | t3 | propose
Atiqah | yup that's the only way | DECISION | t3 | agree
Yong | ok | DECISION | t3 | agree
Mark | stay on Mabul island or Semporna town? | ACCOMMODATION | - | ask
Atiqah | Mabul water bungalow, RM350 a night with meals | ACCOMMODATION | t4 | propose
Yong | 350 include meals not bad | DECISION | t4 | agree
Mark | Mabul ok | DECISION | t4 | agree
Atiqah | dates: 18 to 22 April | DATE | t5 | propose
Mark | 18-22 Apr can | DECISION | t5 | agree
Yong | I need to ask my boss | DECISION | t5 | defer
Mark | budget around RM3000 each, diving is expensive | BUDGET | t6 | propose
Yong | for non-diver can less ah? | DECISION | t6 | defer
Atiqah | Yong maybe RM2000 | BUDGET | t6 | info
Mark | I get seasick on small boats 🤢 | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Semporna", "pending"), "t2": ("ATTRACTION", "discover scuba", "confirmed"),
                "t3": ("TRANSPORT", "fly to Tawau + van", "confirmed"), "t4": ("ACCOMMODATION", "Mabul water bungalow", "confirmed"),
                "t5": ("DATE", "18-22 Apr", "pending"), "t6": ("BUDGET", "RM3000 each", "pending")},
     "prefs": [("Yong", "has no diving license"), ("Mark", "gets seasick on small boats")],
     "facts": {"destination": None, "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-24-jb", "destination": "Johor Bahru", "members": ["Mum", "Chee Keong", "Ling"], "lines": """
Chee Keong | 妈，这个星期六去新山买东西？ | DESTINATION | t1 | propose
Mum | 好，我要去买布 | DECISION | t1 | agree
Ling | 我也要去 | DECISION | t1 | agree
Chee Keong | 先去Mid Valley Southkey | ATTRACTION | t2 | propose
Ling | Southkey 太大了妈会走到累 | DECISION | t2 | reject
Mum | 我要去City Square | ATTRACTION | t3 | propose
Chee Keong | ok City Square | DECISION | t3 | agree
Ling | 好 | DECISION | t3 | agree
Ling | 午餐吃肉骨茶 | ATTRACTION | t4 | propose
Mum | 我不吃猪肉了，医生说胆固醇高 | PREFERENCE | - | none
Ling | 啊，那吃海南鸡饭 | ATTRACTION | t5 | propose
Mum | 这个可以 | DECISION | t5 | agree
Chee Keong | ok | DECISION | t5 | agree
Chee Keong | 我开车，早上9点出发 | TRANSPORT | t6 | propose
Mum | 好 | DECISION | t6 | agree
Ling | 可以 | DECISION | t6 | agree
""", "topics": {"t1": ("DESTINATION", "Johor Bahru", "confirmed"), "t2": ("ATTRACTION", "Mid Valley Southkey", "rejected"),
                "t3": ("ATTRACTION", "City Square", "confirmed"), "t4": ("ATTRACTION", "bak kut teh", "rejected"),
                "t5": ("ATTRACTION", "Hainanese chicken rice", "confirmed"), "t6": ("TRANSPORT", "Chee Keong drives, 9am", "confirmed")},
     "prefs": [("Mum", "doesn't eat pork")],
     "facts": {"destination": "Johor Bahru", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-25-hanoi-sapa", "destination": "Sapa", "members": ["Victoria", "Imran", "Kah Wai", "Pooja"], "lines": """
Imran | Sapa trekking + Hanoi, 7 days. thoughts? | DESTINATION | t1 | propose
Pooja | love it, rice terraces 😍 | DECISION | t1 | agree
Kah Wai | trekking how many hours per day? | ATTRACTION | - | ask
Imran | 4 to 6 hours, can choose easy route | ATTRACTION | - | info
Kah Wai | ok then I'm in | DECISION | t1 | agree
Victoria | me too | DECISION | t1 | agree
Victoria | sleeper bus Hanoi to Sapa, RM60 | TRANSPORT | t2 | propose
Pooja | sleeper bus very uncomfortable, train better? | TRANSPORT | t3 | propose
Imran | the train only goes to Lao Cai, then 1 hour van | TRANSPORT | t3 | info
Kah Wai | train + van ok, at least can sleep | DECISION | t3 | agree
Victoria | ok train | DECISION | t3 | agree
Imran | homestay with a local family in Ta Van village | ACCOMMODATION | t4 | propose
Pooja | homestay experience yes | DECISION | t4 | agree
Kah Wai | ok | DECISION | t4 | agree
Victoria | Fansipan cable car, the highest peak | ATTRACTION | t5 | propose
Imran | weather there unpredictable, decide on the day | DECISION | t5 | defer
Pooja | I'm vegetarian too, homestay can cook veg? | PREFERENCE | - | none
Imran | I'll ask the host | OTHER | - | none
Kah Wai | budget around RM3000 each? | BUDGET | t6 | propose
Victoria | Vietnam cheap, RM2500 enough | BUDGET | t7 | propose
Pooja | 2500 ok | DECISION | t7 | agree
Imran | 2.5k ok | DECISION | t7 | agree
Kah Wai | fine 2500 | DECISION | t7 | agree
""", "topics": {"t1": ("DESTINATION", "Sapa + Hanoi", "confirmed"), "t2": ("TRANSPORT", "sleeper bus", "rejected"),
                "t3": ("TRANSPORT", "train + van", "confirmed"), "t4": ("ACCOMMODATION", "homestay in Ta Van", "confirmed"),
                "t5": ("ATTRACTION", "Fansipan cable car", "pending"), "t6": ("BUDGET", "RM3000 each", "rejected"),
                "t7": ("BUDGET", "RM2500", "confirmed")},
     "prefs": [("Pooja", "is vegetarian")],
     "facts": {"destination": "Sapa", "budget": 2500, "budget_basis": "per_person", "dates": None}},

    {"id": "man-26-melbourne", "destination": "Melbourne", "members": ["Elaine", "Cheng Hao", "Suresh", "Amanda"], "lines": """
Suresh | Melbourne in Feb for the Australian Open final? 🎾 | DESTINATION | t1 | propose
Amanda | tickets sold out already I think | ATTRACTION | - | info
Suresh | ground pass still available | ATTRACTION | t2 | propose
Elaine | ground pass ok, cheaper | DECISION | t2 | agree
Cheng Hao | I'm not into tennis but Melbourne yes | DECISION | t1 | agree
Amanda | Melbourne ok | DECISION | t1 | agree
Elaine | yes | DECISION | t1 | agree
Cheng Hao | Great Ocean Road drive, 2 days | ATTRACTION | t3 | propose
Amanda | 12 Apostles at sunset 😍 | DECISION | t3 | agree
Suresh | who's driving? left side same as Malaysia | TRANSPORT | t4 | info
Elaine | I can drive | TRANSPORT | t4 | propose
Cheng Hao | me too, we take turns | DECISION | t4 | agree
Amanda | Phillip Island penguin parade | ATTRACTION | t5 | propose
Suresh | far la, another 2 hours | DECISION | t5 | reject
Amanda | but penguins 🐧 | DECISION | t5 | agree
Elaine | maybe if got time | DECISION | t5 | defer
Cheng Hao | Airbnb in Southbank, AUD 250 a night | ACCOMMODATION | t6 | propose
Amanda | Southbank nice | DECISION | t6 | agree
Suresh | ok | DECISION | t6 | agree
Elaine | ok booked | DECISION | t6 | finalize
Amanda | I'm a coffee snob, must try Melbourne cafes ☕ | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Melbourne", "confirmed"), "t2": ("ATTRACTION", "Australian Open ground pass", "pending"),
                "t3": ("ATTRACTION", "Great Ocean Road", "pending"), "t4": ("TRANSPORT", "Elaine and Cheng Hao drive", "pending"),
                "t5": ("ATTRACTION", "Phillip Island penguin parade", "pending"), "t6": ("ACCOMMODATION", "Airbnb in Southbank", "confirmed")},
     "prefs": [("Amanda", "loves coffee")],
     "facts": {"destination": "Melbourne", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-27-redang", "destination": "Redang", "members": ["Shafiq", "Huda", "Lim", "Nicole"], "lines": """
Huda | Redang package 3D2N, RM850 seorang include makan + snorkel | DESTINATION | t1 | propose
Lim | package senang, no need plan | DECISION | t1 | agree
Nicole | ok worth it | DECISION | t1 | agree
Shafiq | on | DECISION | t1 | agree
Huda | Laguna Redang resort | ACCOMMODATION | t2 | propose
Nicole | Laguna ok, the beach in front very nice | DECISION | t2 | agree
Shafiq | ok | DECISION | t2 | agree
Lim | when? June school holiday very crowded | DATE | - | info
Huda | 3 hingga 5 Julai? after school holiday | DATE | t4 | propose
Lim | 3-5 Jul ok | DECISION | t4 | agree
Nicole | ok | DECISION | t4 | agree
Shafiq | ok 3-5 Julai | DECISION | t4 | agree
Shafiq | drive to Kuala Terengganu then ferry from Merang jetty | TRANSPORT | t5 | propose
Lim | 6 hours drive 😵 fly to KT? | TRANSPORT | t6 | propose
Huda | flight RM300, drive split 4 cheaper | DECISION | t6 | reject
Nicole | drive la, we take turns | DECISION | t5 | agree
Lim | ok ok drive | DECISION | t5 | agree
Nicole | I want to see turtles 🐢 | PREFERENCE | - | none
Huda | aku takut laut dalam, snorkel tepi je | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Redang package", "confirmed"), "t2": ("ACCOMMODATION", "Laguna Redang", "pending"),
                "t4": ("DATE", "3-5 Jul", "confirmed"), "t5": ("TRANSPORT", "drive + ferry from Merang", "confirmed"),
                "t6": ("TRANSPORT", "fly to Kuala Terengganu", "rejected")},
     "prefs": [("Nicole", "wants to see turtles"), ("Huda", "is afraid of deep water")],
     "facts": {"destination": "Redang", "budget": None, "budget_basis": None, "dates": "3-5 Jul"}},

    {"id": "man-28-chengdu", "destination": "Chengdu", "members": ["小王", "Joyce", "阿明"], "lines": """
Joyce | 成都看熊猫！五月去？ | DESTINATION | t1 | propose
阿明 | 熊猫🐼 我要去 | DECISION | t1 | agree
小王 | 去，顺便吃火锅 | DECISION | t1 | agree
小王 | 五一假期人太多，5月10号到15号？ | DATE | t2 | propose
Joyce | 10号到15号可以 | DECISION | t2 | agree
阿明 | 好 | DECISION | t2 | agree
Joyce | 熊猫基地要早上去，熊猫早上才活跃 | ATTRACTION | t3 | propose
阿明 | 早上8点到 | DECISION | t3 | agree
小王 | 我吃不了太辣，火锅要鸳鸯锅 | PREFERENCE | - | none
阿明 | 乐山大佛一日游 | ATTRACTION | t4 | propose
Joyce | 来回要4个小时 | ATTRACTION | t4 | info
小王 | 可以啊，难得去 | DECISION | t4 | agree
Joyce | 那好吧 | DECISION | t4 | agree
小王 | 住春熙路附近，吃的多 | ACCOMMODATION | t5 | propose
Joyce | 春熙路方便 | DECISION | t5 | agree
阿明 | 每人预算RM3500够吗？ | BUDGET | t6 | propose
小王 | 应该够 | DECISION | t6 | agree
Joyce | 够了 | DECISION | t6 | agree
""", "topics": {"t1": ("DESTINATION", "Chengdu", "confirmed"), "t2": ("DATE", "10-15 May", "confirmed"),
                "t3": ("ATTRACTION", "Panda base in the morning", "confirmed"), "t4": ("ATTRACTION", "Leshan Giant Buddha", "confirmed"),
                "t5": ("ACCOMMODATION", "near Chunxi Road", "confirmed"), "t6": ("BUDGET", "RM3500 per person", "confirmed")},
     "prefs": [("小王", "can't eat very spicy food")],
     "facts": {"destination": "Chengdu", "budget": 3500, "budget_basis": "per_person", "dates": "10-15 May"}},
]
