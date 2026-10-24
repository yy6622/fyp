"""Hand-written TRAINING chats (12 here + 16 in manual_data_batch2.py + 16 in manual_data_batch3.py). They add the kinds of messages the
templates lack: long sentences, replies that name the option ("metro all the
way 👍", "ok I book X"), counter-proposals without a "no", chatter-heavy chats,
votes, family / colleague tones. Same line format as challenge_data.py.

These are written by the same author as the challenge sets, so a gain on
test_challenge / test_challenge2 is partly "same style"; test_real (your real
chats) is the independent check. No external AI API is used to make data.

Run: python manual_data.py  -> data/manual.jsonl (used for training by build_dataset.py)
"""

from challenge_data import to_convs
from common import DATA, write_jsonl

CHATS = [
    {"id": "man-01-kyoto", "destination": "Kyoto", "members": ["Jessica", "Haris", "Tim", "Yuki"], "lines": """
Jessica | Since we all have leave in April, what about Kyoto? Cherry blossom + temples | DESTINATION | t1 | propose
Haris | Kyoto sounds amazing, count me in | DECISION | t1 | agree
Tim | yes yes yes | DECISION | t1 | agree
Yuki | I'm in too, I can help with Japanese 😄 | DECISION | t1 | agree
Tim | flights from KL to Osaka are cheaper than Tokyo btw | TRANSPORT | - | info
Jessica | ok so fly into Osaka and take the train to Kyoto? | TRANSPORT | t2 | propose
Haris | Haruka express is like 75 mins, easy | DECISION | t2 | agree
Yuki | yup that's what I did last time | DECISION | t2 | agree
Tim | dates - 3 to 8 April works for me | DATE | t3 | propose
Haris | 3-8 Apr is fine | DECISION | t3 | agree
Yuki | I can only start on the 5th, sorry guys | DECISION | t3 | reject
Jessica | then 5 to 10 April? | DATE | t4 | propose
Tim | 5-10 ok also | DECISION | t4 | agree
Haris | fine with me | DECISION | t4 | agree
Yuki | thank you!! 🙏 5-10 Apr confirmed | DECISION | t4 | finalize
Haris | budget around RM5000 each including flights? | BUDGET | t5 | propose
Tim | that's a bit high for me, can we try RM4000? | BUDGET | t6 | propose
Jessica | 4k is doable if we stay in a guesthouse | DECISION | t6 | agree
Yuki | ok 4k | DECISION | t6 | agree
Haris | alright RM4000 then | DECISION | t6 | agree
Yuki | Fushimi Inari early morning before the crowds | ATTRACTION | t7 | propose
Tim | yes!! the torii gates | DECISION | t7 | agree
Jessica | Arashiyama bamboo forest also | ATTRACTION | t8 | propose
Haris | both can be same day? | ATTRACTION | - | ask
Yuki | different side of the city, better separate days | ATTRACTION | t8 | info
Haris | ok no problem | DECISION | t8 | agree
Tim | anyone wanna do a tea ceremony? kinda pricey | ATTRACTION | t9 | propose
Jessica | hmm maybe, let's see the budget first | DECISION | t9 | defer
Yuki | guesthouse near Kyoto Station, 9000 yen per night for 4 pax | ACCOMMODATION | t10 | propose
Tim | near the station is super convenient | DECISION | t10 | agree
Haris | 👍 | DECISION | t10 | agree
Jessica | I'm allergic to shellfish fyi | PREFERENCE | - | none
Tim | noted, no seafood dinner for you 😂 | OTHER | - | none
""", "topics": {"t1": ("DESTINATION", "Kyoto", "confirmed"), "t2": ("TRANSPORT", "fly to Osaka + train", "confirmed"),
                "t3": ("DATE", "3-8 Apr", "rejected"), "t4": ("DATE", "5-10 Apr", "confirmed"),
                "t5": ("BUDGET", "RM5000 each", "rejected"), "t6": ("BUDGET", "RM4000", "confirmed"),
                "t7": ("ATTRACTION", "Fushimi Inari", "pending"), "t8": ("ATTRACTION", "Arashiyama bamboo forest", "pending"),
                "t9": ("ATTRACTION", "tea ceremony", "pending"), "t10": ("ACCOMMODATION", "guesthouse near Kyoto Station", "confirmed")},
     "prefs": [("Jessica", "is allergic to shellfish")],
     "facts": {"destination": "Kyoto", "budget": 4000, "budget_basis": "per_person", "dates": "5-10 Apr"}},

    {"id": "man-02-melaka", "destination": "Melaka", "members": ["Jun", "Mum", "Kai"], "lines": """
Jun | 这个周末带妈去马六甲走走？ | DESTINATION | t1 | propose
Mum | 好啊，很久没去了 | DECISION | t1 | agree
Kai | can, I free on Saturday | DECISION | t1 | agree
Jun | 那就星期六一天来回 | DATE | t2 | propose
Kai | ok Saturday day trip | DECISION | t2 | agree
Mum | 早上不要太早出门，我要先去菜市场 | PREFERENCE | - | none
Kai | ok we leave 10am la | DATE | t2 | info
Jun | 我开车，过路费油钱大概RM80 | TRANSPORT | t3 | propose
Kai | ok you drive, I pay petrol | DECISION | t3 | agree
Mum | 鸡场街一定要去 | ATTRACTION | t4 | propose
Jun | Jonker Street 晚上才热闹，白天比较少东西 | ATTRACTION | t4 | info
Mum | 太晚回家我会累 | PREFERENCE | - | none
Jun | 午餐吃鸡饭粒 | ATTRACTION | t5 | propose
Kai | chicken rice ball 好！ | DECISION | t5 | agree
Mum | 去那间和记，不要去游客那间 | ATTRACTION | t6 | propose
Jun | 和记要排队很久哦 | ATTRACTION | t6 | info
Mum | 排就排咯 | DECISION | t6 | agree
Kai | lol ok mum wins | DECISION | t6 | agree
Kai | Stadthuys red building take photo also | ATTRACTION | t7 | propose
Jun | 可以，就在附近 | DECISION | t7 | agree
Mum | 我想买娘惹糕回家 | PREFERENCE | - | none
Jun | ok 回程买 | OTHER | - | none
""", "topics": {"t1": ("DESTINATION", "Melaka", "confirmed"), "t2": ("DATE", "Saturday", "confirmed"),
                "t3": ("TRANSPORT", "Jun drives", "confirmed"), "t4": ("ATTRACTION", "Jonker Street", "pending"),
                "t5": ("ATTRACTION", "chicken rice ball", "confirmed"), "t6": ("ATTRACTION", "Hoe Kee chicken rice ball", "confirmed"),
                "t7": ("ATTRACTION", "Stadthuys", "confirmed")},
     "prefs": [("Mum", "doesn't want to leave too early"), ("Mum", "doesn't want to come back too late"),
               ("Mum", "wants to buy nyonya kuih")],
     "facts": {"destination": "Melaka", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-03-seoul", "destination": "Seoul", "members": ["Ashley", "Joanne", "Faiz", "Ken", "Wen"], "lines": """
Ashley | SEOUL TRIP AFTER SEM ENDS?? 🇰🇷 | DESTINATION | t1 | propose
Joanne | omg yesss | DECISION | t1 | agree
Faiz | if cheap I go | DECISION | t1 | agree
Ken | in | DECISION | t1 | agree
Wen | count me in but my budget very tight ah | DECISION | t1 | agree
Ashley | RM3500 each enough? flight + hotel + food | BUDGET | t2 | propose
Wen | 3.5k too much for me leh, max RM2800 | BUDGET | t3 | propose
Faiz | 2800 can if we stay hostel | DECISION | t3 | agree
Joanne | ok 2.8k la | DECISION | t3 | agree
Ken | fine | DECISION | t3 | agree
Ashley | ok RM2800 per person final | DECISION | t3 | finalize
Joanne | must go Myeongdong for skincare shopping!!! | ATTRACTION | t4 | propose
Ashley | +100 | DECISION | t4 | agree
Ken | Gyeongbokgung with hanbok rental | ATTRACTION | t5 | propose
Faiz | hanbok photos 📸 yes | DECISION | t5 | agree
Wen | free entry if wear hanbok right? | ATTRACTION | t5 | info
Ken | yup | OTHER | - | none
Faiz | I need halal food, Itaewon got many | PREFERENCE | - | none
Joanne | Nami Island day trip? | ATTRACTION | t6 | propose
Wen | Nami quite far, 1.5 hours one way | ATTRACTION | t6 | info
Ken | skip Nami la, not enough time | DECISION | t6 | reject
Joanne | ok fine 😢 | DECISION | t6 | reject
Ashley | hostel in Hongdae, 30000 won per night per person | ACCOMMODATION | t7 | propose
Faiz | Hongdae nightlife best | DECISION | t7 | agree
Wen | ok cheapest option I'm happy | DECISION | t7 | agree
Ken | Myeongdong area more central leh | ACCOMMODATION | t8 | propose
Ashley | but more expensive | DECISION | t8 | reject
Joanne | Hongdae lah, airport railroad straight there | DECISION | t7 | agree
Ken | ok ok Hongdae | DECISION | t7 | agree
Wen | when ah? 20-27 June? | DATE | t9 | propose
Ashley | I check my exam timetable first | DECISION | t9 | defer
""", "topics": {"t1": ("DESTINATION", "Seoul", "confirmed"), "t2": ("BUDGET", "RM3500 each", "rejected"),
                "t3": ("BUDGET", "RM2800 per person", "confirmed"), "t4": ("ATTRACTION", "Myeongdong", "pending"),
                "t5": ("ATTRACTION", "Gyeongbokgung with hanbok", "pending"), "t6": ("ATTRACTION", "Nami Island", "rejected"),
                "t7": ("ACCOMMODATION", "hostel in Hongdae", "confirmed"), "t8": ("ACCOMMODATION", "Myeongdong area", "rejected"),
                "t9": ("DATE", "20-27 Jun", "pending")},
     "prefs": [("Faiz", "needs halal food")],
     "facts": {"destination": "Seoul", "budget": 2800, "budget_basis": "per_person", "dates": None}},

    {"id": "man-04-phuket", "destination": "Phuket", "members": ["Amir", "Sofea", "Danial", "Aina"], "lines": """
Amir | geng, cuti Disember ni jom Phuket? | DESTINATION | t1 | propose
Sofea | best tu! pantai 🏖️ | DECISION | t1 | agree
Danial | aku on | DECISION | t1 | agree
Aina | boleh je, tapi aku tak boleh lama, 4 hari je | DECISION | t1 | agree
Amir | ok 4 hari 3 malam, 18 hingga 21 Disember? | DATE | t2 | propose
Danial | 18-21 Dis set | DECISION | t2 | agree
Sofea | ok | DECISION | t2 | agree
Aina | ok aku apply cuti esok | DECISION | t2 | agree
Danial | flight AirAsia dari KL dalam RM450 return | TRANSPORT | t3 | propose
Sofea | murah, book cepat sebelum naik harga | DECISION | t3 | agree
Amir | aku book malam ni untuk semua | DECISION | t3 | finalize
Aina | island hopping Phi Phi wajib | ATTRACTION | t4 | propose
Sofea | yesss Maya Bay | DECISION | t4 | agree
Danial | aku mabuk laut sikit 😅 | PREFERENCE | - | none
Amir | makan ubat je, ok la | OTHER | - | none
Sofea | Old Phuket Town untuk gambar, cantik bangunan dia | ATTRACTION | t5 | propose
Aina | boleh pergi petang | DECISION | t5 | agree
Danial | Bangla Road malam? | ATTRACTION | t6 | propose
Aina | tak nak lah, tak selesa | DECISION | t6 | reject
Sofea | skip la | DECISION | t6 | reject
Amir | resort tepi pantai Patong, RM300 semalam satu bilik | ACCOMMODATION | t7 | propose
Sofea | Patong bising, Kata Beach lagi tenang | ACCOMMODATION | t8 | propose
Aina | setuju Kata | DECISION | t8 | agree
Danial | Kata ok | DECISION | t8 | agree
Amir | ok tukar Kata | DECISION | t8 | agree
Aina | makanan halal penting untuk kita semua | PREFERENCE | - | none
Amir | budget dalam RM2000 seorang cukup kot | BUDGET | t9 | propose
Danial | cukup kot | DECISION | t9 | agree
""", "topics": {"t1": ("DESTINATION", "Phuket", "confirmed"), "t2": ("DATE", "18-21 Dec", "confirmed"),
                "t3": ("TRANSPORT", "AirAsia flight", "confirmed"), "t4": ("ATTRACTION", "Phi Phi island hopping", "pending"),
                "t5": ("ATTRACTION", "Old Phuket Town", "pending"), "t6": ("ATTRACTION", "Bangla Road", "rejected"),
                "t7": ("ACCOMMODATION", "resort at Patong", "rejected"), "t8": ("ACCOMMODATION", "Kata Beach", "confirmed"),
                "t9": ("BUDGET", "RM2000 per person", "pending")},
     "prefs": [("Danial", "gets seasick"), ("Aina", "needs halal food")],
     "facts": {"destination": "Phuket", "budget": None, "budget_basis": None, "dates": "18-21 Dec"}},

    {"id": "man-05-taipei", "destination": "Taipei", "members": ["小美", "阿杰", "Vivian"], "lines": """
小美 | 我们年底去台北好不好？ | DESTINATION | t1 | propose
阿杰 | 好啊！我要吃夜市 | DECISION | t1 | agree
Vivian | 可以～ | DECISION | t1 | agree
阿杰 | 机票我看了，亚航来回大概RM700 | TRANSPORT | - | info
小美 | 预算每人RM2500可以吗？ | BUDGET | t2 | propose
Vivian | 两千五应该够 | DECISION | t2 | agree
阿杰 | 够啦，台北不贵 | DECISION | t2 | agree
Vivian | 日期呢？12月20号到24号？ | DATE | t3 | propose
阿杰 | 20号我要上班，21号到25号吧 | DATE | t4 | propose
小美 | 21到25可以 | DECISION | t4 | agree
Vivian | 好，那就12月21号到25号 | DECISION | t4 | finalize
阿杰 | 九份一定要去，晚上的灯笼很美 | ATTRACTION | t5 | propose
小美 | 九份好远欸，要坐一个多小时巴士 | ATTRACTION | t5 | info
Vivian | 远也要去啦 | DECISION | t5 | agree
小美 | 好吧 | DECISION | t5 | agree
Vivian | 士林夜市 | ATTRACTION | t6 | propose
阿杰 | 士林太多游客了，饶河街夜市比较好吃 | ATTRACTION | t7 | propose
Vivian | 那就饶河 | DECISION | t7 | agree
小美 | 我不吃内脏哦 | PREFERENCE | - | none
阿杰 | 交通就坐捷运，买悠游卡 | TRANSPORT | t8 | propose
小美 | 捷运很方便 | DECISION | t8 | agree
Vivian | 住西门町附近吧，什么都有 | ACCOMMODATION | t9 | propose
小美 | 西门町可以 | DECISION | t9 | agree
阿杰 | 我先看看价钱 | DECISION | t9 | defer
小美 | 哈哈哈好期待 | OTHER | - | none
""", "topics": {"t1": ("DESTINATION", "Taipei", "confirmed"), "t2": ("BUDGET", "RM2500 per person", "confirmed"),
                "t3": ("DATE", "20-24 Dec", "rejected"), "t4": ("DATE", "21-25 Dec", "confirmed"),
                "t5": ("ATTRACTION", "Jiufen", "confirmed"), "t6": ("ATTRACTION", "Shilin night market", "rejected"),
                "t7": ("ATTRACTION", "Raohe night market", "confirmed"), "t8": ("TRANSPORT", "MRT with EasyCard", "confirmed"),
                "t9": ("ACCOMMODATION", "near Ximending", "confirmed")},
     "prefs": [("小美", "doesn't eat offal")],
     "facts": {"destination": "Taipei", "budget": 2500, "budget_basis": "per_person", "dates": "21-25 Dec"}},

    {"id": "man-06-hongkong", "destination": "Hong Kong", "members": ["Sam", "Rachel", "Kevin", "Mira"], "lines": """
Sam | HK trip for the long weekend, who's keen? | DESTINATION | t1 | propose
Rachel | me! | DECISION | t1 | agree
Kevin | keen | DECISION | t1 | agree
Mira | I'll join if dates work | DECISION | t1 | defer
Sam | 1 to 4 May | DATE | t2 | propose
Mira | perfect, 1-4 May works | DECISION | t2 | agree
Rachel | ok | DECISION | t2 | agree
Kevin | Ocean Park one day? | ATTRACTION | t3 | propose
Rachel | Victoria Peak at night is a must | ATTRACTION | t4 | propose
Mira | peak tram queue super long though | ATTRACTION | t4 | info
Sam | go after 9pm, less people | ATTRACTION | t4 | info
Mira | ok then the peak 👍 | DECISION | t4 | agree
Sam | for Ocean Park, not keen, it's more for kids | DECISION | t3 | reject
Rachel | agree, skip Ocean Park | DECISION | t3 | reject
Kevin | aiya ok la | DECISION | t3 | reject
Mira | dim sum at Tim Ho Wan! | ATTRACTION | t5 | propose
Kevin | yes Tim Ho Wan | DECISION | t5 | agree
Rachel | Tim Ho Wan confirm | DECISION | t5 | agree
Sam | hotel in Tsim Sha Tsui, around HKD1200 per night | ACCOMMODATION | t6 | propose
Rachel | TST ok, near MTR | DECISION | t6 | agree
Kevin | can share 2 rooms | DECISION | t6 | agree
Mira | I'll book it tonight | DECISION | t6 | finalize
Rachel | Octopus card for MTR and ferry | TRANSPORT | t7 | propose
Sam | yes, Star Ferry is cheap and nice | DECISION | t7 | agree
Kevin | budget wise RM2500 per person? | BUDGET | t8 | propose
Mira | probably more la, HK hotels expensive | DECISION | t8 | reject
Sam | let's say RM3000 to be safe | BUDGET | t9 | propose
Rachel | 3k ok | DECISION | t9 | agree
Kevin | ok | DECISION | t9 | agree
Rachel | I'm not a fan of very crowded places btw | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Hong Kong", "confirmed"), "t2": ("DATE", "1-4 May", "confirmed"),
                "t3": ("ATTRACTION", "Ocean Park", "rejected"), "t4": ("ATTRACTION", "Victoria Peak at night", "pending"),
                "t5": ("ATTRACTION", "Tim Ho Wan", "confirmed"), "t6": ("ACCOMMODATION", "hotel in Tsim Sha Tsui", "confirmed"),
                "t7": ("TRANSPORT", "Octopus card, MTR and ferry", "pending"), "t8": ("BUDGET", "RM2500 per person", "rejected"),
                "t9": ("BUDGET", "RM3000", "confirmed")},
     "prefs": [("Rachel", "doesn't like crowded places")],
     "facts": {"destination": "Hong Kong", "budget": 3000, "budget_basis": "per_person", "dates": "1-4 May"}},

    {"id": "man-07-langkawi", "destination": "Langkawi", "members": ["Hana", "Iqbal", "Grace", "Leon"], "lines": """
Hana | good morning everyone ☀️ | OTHER | - | none
Iqbal | morning | OTHER | - | none
Grace | anyone saw the new cafe at SS15? | OTHER | - | none
Leon | yes the matcha one! queue so long | OTHER | - | none
Hana | btw Langkawi trip still on? | DESTINATION | t1 | propose
Leon | still on la | DECISION | t1 | agree
Grace | yes!! | DECISION | t1 | agree
Iqbal | on | DECISION | t1 | agree
Hana | ferry from Kuala Perlis or fly? | TRANSPORT | - | ask
Iqbal | fly la, ferry 1.5 hours and I get seasick | TRANSPORT | t2 | propose
Grace | fly ok, AirAsia RM180 return | DECISION | t2 | agree
Leon | ok fly | DECISION | t2 | agree
Grace | rent a car there, everything far apart | TRANSPORT | t3 | propose
Hana | car ok, Leon drive 😂 | DECISION | t3 | agree
Leon | why me 😂😂 | OTHER | - | none
Iqbal | haha | OTHER | - | none
Leon | ok fine I drive | DECISION | t3 | agree
Grace | cable car + sky bridge | ATTRACTION | t4 | propose
Hana | I scared of heights... I wait at the bottom can? | PREFERENCE | - | none
Grace | sure 😂 | OTHER | - | none
Iqbal | mangrove tour by boat | ATTRACTION | t5 | propose
Leon | mangrove nice, saw eagles last time | DECISION | t5 | agree
Hana | ok work calling, brb | OTHER | - | none
Grace | duty free chocolate shopping 🍫 | ATTRACTION | t6 | propose
Iqbal | lol you and your chocolate | OTHER | - | none
""", "topics": {"t1": ("DESTINATION", "Langkawi", "confirmed"), "t2": ("TRANSPORT", "fly AirAsia", "confirmed"),
                "t3": ("TRANSPORT", "rent a car", "confirmed"), "t4": ("ATTRACTION", "cable car and sky bridge", "pending"),
                "t5": ("ATTRACTION", "mangrove boat tour", "pending"), "t6": ("ATTRACTION", "duty free chocolate shopping", "pending")},
     "prefs": [("Hana", "is scared of heights")],
     "facts": {"destination": "Langkawi", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-08-ipoh", "destination": "Ipoh", "members": ["Ah Seng", "Mei Yee", "Jordan"], "lines": """
Ah Seng | Ipoh makan trip this Sunday? | DESTINATION | t1 | propose
Mei Yee | wah ok | DECISION | t1 | agree
Jordan | 好 | DECISION | t1 | agree
Ah Seng | take ETS train, 2.5 hours from KL Sentral | TRANSPORT | t2 | propose
Jordan | ETS sold out already for Sunday morning | TRANSPORT | t2 | info
Mei Yee | then I drive lor | TRANSPORT | t3 | propose
Ah Seng | ok Mei Yee drive, we share petrol | DECISION | t3 | agree
Jordan | 可以 | DECISION | t3 | agree
Jordan | 芽菜鸡 must eat, Lou Wong | ATTRACTION | t4 | propose
Mei Yee | Lou Wong queue long, Onn Kee opposite also same taste | ATTRACTION | t5 | propose
Ah Seng | Onn Kee la, no need queue | DECISION | t5 | agree
Jordan | ok Onn Kee | DECISION | t5 | agree
Mei Yee | white coffee at the original Old Town shop | ATTRACTION | t6 | propose
Jordan | 好啊 | DECISION | t6 | agree
Ah Seng | Concubine Lane for photos | ATTRACTION | t7 | propose
Mei Yee | very touristy now, skip? | DECISION | t7 | reject
Jordan | I don't mind skipping | DECISION | t7 | reject
Mei Yee | budget RM100 each enough for food and petrol | BUDGET | t8 | propose
Ah Seng | more than enough | DECISION | t8 | agree
Jordan | 我不吃辣的 | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Ipoh", "confirmed"), "t2": ("TRANSPORT", "ETS train", "rejected"),
                "t3": ("TRANSPORT", "Mei Yee drives", "confirmed"), "t4": ("ATTRACTION", "Lou Wong", "rejected"),
                "t5": ("ATTRACTION", "Onn Kee", "confirmed"), "t6": ("ATTRACTION", "Old Town white coffee", "confirmed"),
                "t7": ("ATTRACTION", "Concubine Lane", "rejected"), "t8": ("BUDGET", "RM100 each", "confirmed")},
     "prefs": [("Jordan", "can't eat spicy food")],
     "facts": {"destination": "Ipoh", "budget": 100, "budget_basis": "per_person", "dates": None}},

    {"id": "man-09-sydney", "destination": "Sydney", "members": ["Chloe", "Ethan", "Mum", "Dad"], "lines": """
Chloe | Mum, Dad, for your 30th anniversary Ethan and I want to bring you both to Sydney 🥰 | DESTINATION | t1 | propose
Mum | Aiyo so expensive, no need la | DECISION | t1 | reject
Ethan | we already saved up, please come with us | DECISION | t1 | agree
Dad | if you all insist then ok lah, thank you | DECISION | t1 | agree
Mum | ok lor 😊 | DECISION | t1 | agree
Chloe | we're thinking 10 days in early November, weather is nice | DATE | t2 | propose
Dad | November ok, after my medical checkup on the 2nd | DECISION | t2 | agree
Ethan | Opera House and Harbour Bridge first day | ATTRACTION | t3 | propose
Mum | must see the Opera House! | DECISION | t3 | agree
Dad | I won't climb anything high ah, too old for that | PREFERENCE | - | none
Chloe | Blue Mountains day trip, the Three Sisters view | ATTRACTION | t4 | propose
Dad | that one I like, nature | DECISION | t4 | agree
Mum | can, but not too much walking | DECISION | t4 | agree
Ethan | Bondi beach also, can walk the coastal path | ATTRACTION | t5 | propose
Mum | walk again 😅 | DECISION | t5 | defer
Ethan | ok we see how you feel that day | DECISION | t5 | defer
Chloe | apartment in Darling Harbour with 2 rooms, about AUD 350 a night | ACCOMMODATION | t6 | propose
Ethan | good location, I'll book | DECISION | t6 | finalize
Dad | I need proper rice every day hor, cannot eat sandwiches every meal | PREFERENCE | - | none
Chloe | haha ok we find Asian food | OTHER | - | none
Ethan | we take the train and ferry around, Opal card | TRANSPORT | t7 | propose
Chloe | yes public transport is very good there | DECISION | t7 | agree
""", "topics": {"t1": ("DESTINATION", "Sydney", "confirmed"), "t2": ("DATE", "early Nov", "pending"),
                "t3": ("ATTRACTION", "Opera House and Harbour Bridge", "pending"), "t4": ("ATTRACTION", "Blue Mountains", "confirmed"),
                "t5": ("ATTRACTION", "Bondi coastal walk", "pending"), "t6": ("ACCOMMODATION", "apartment in Darling Harbour", "confirmed"),
                "t7": ("TRANSPORT", "train and ferry with Opal card", "pending")},
     "prefs": [("Dad", "won't climb anything high"), ("Dad", "needs rice every day")],
     "facts": {"destination": "Sydney", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-10-jeju", "destination": "Jeju", "members": ["Ivy", "Raymond", "Shu Fen", "Nadia", "Ben"], "lines": """
Ivy | where to go for the October break? I'm thinking Jeju | DESTINATION | t1 | propose
Raymond | Busan better, can take KTX to Seoul also | DESTINATION | t2 | propose
Shu Fen | Jeju! nature + cafes | DECISION | t1 | agree
Nadia | Jeju for me too | DECISION | t1 | agree
Ben | either also can | DECISION | t1 | defer
Raymond | ok ok majority Jeju 😂 | DECISION | t1 | agree
Ivy | yay Jeju confirmed! | DECISION | t1 | finalize
Shu Fen | 5D4N, 10 to 14 Oct? | DATE | t3 | propose
Nadia | 10-14 Oct can | DECISION | t3 | agree
Ben | ok | DECISION | t3 | agree
Raymond | ok | DECISION | t3 | agree
Ivy | need to rent car there, buses are slow | TRANSPORT | t4 | propose
Ben | I have international license | TRANSPORT | t4 | info
Nadia | ok rent car, Ben drive | DECISION | t4 | agree
Raymond | 👍 | DECISION | t4 | agree
Shu Fen | Hallasan hike? 8-9 hours though | ATTRACTION | t5 | propose
Nadia | 9 hours no way 😂 | DECISION | t5 | reject
Ben | I'm ok to try | DECISION | t5 | agree
Ivy | Seongsan Ilchulbong sunrise is shorter, 1 hour | ATTRACTION | t6 | propose
Nadia | that one ok | DECISION | t6 | agree
Raymond | sunrise means wake up 5am... | DECISION | t6 | defer
Shu Fen | I'm ok with early | DECISION | t6 | agree
Ben | budget around RM3500 per person? | BUDGET | t7 | propose
Ivy | ok | DECISION | t7 | agree
Shu Fen | ok for me | DECISION | t7 | agree
Nadia | ok | DECISION | t7 | agree
Nadia | I don't eat pork, Jeju black pork restaurants I'll skip | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Jeju", "confirmed"), "t2": ("DESTINATION", "Busan", "rejected"),
                "t3": ("DATE", "10-14 Oct", "confirmed"), "t4": ("TRANSPORT", "rent a car", "confirmed"),
                "t5": ("ATTRACTION", "Hallasan hike", "pending"), "t6": ("ATTRACTION", "Seongsan Ilchulbong sunrise", "confirmed"),
                "t7": ("BUDGET", "RM3500 per person", "confirmed")},
     "prefs": [("Nadia", "doesn't eat pork")],
     "facts": {"destination": "Jeju", "budget": 3500, "budget_basis": "per_person", "dates": "10-14 Oct"}},

    {"id": "man-11-kl-staycation", "destination": "Kuala Lumpur", "members": ["Zul", "Mei", "Arun"], "lines": """
Zul | staycation this weekend? KL city | DESTINATION | t1 | propose
Mei | yes need a break | DECISION | t1 | agree
Arun | sure | DECISION | t1 | agree
Mei | Sat-Sun, 15-16 Mar | DATE | t2 | propose
Arun | ok 15-16 | DECISION | t2 | agree
Zul | EQ hotel got promo RM650 per night | ACCOMMODATION | t3 | propose
Arun | 650 too much la for 1 night | DECISION | t3 | reject
Mei | Traders Hotel KLCC view, RM420 | ACCOMMODATION | t4 | propose
Zul | Traders ok, the sky bar there nice | DECISION | t4 | agree
Arun | 420 split 3 ok la | DECISION | t4 | agree
Mei | booked Traders! 🎉 | DECISION | t4 | finalize
Arun | dinner at Jalan Alor? | ATTRACTION | t5 | propose
Zul | Jalan Alor so touristy | DECISION | t5 | reject
Mei | Lot 10 Hutong then | ATTRACTION | t6 | propose
Arun | ok | DECISION | t6 | agree
Zul | ok | DECISION | t6 | agree
Zul | Grab everywhere, parking in KLCC mahal | TRANSPORT | t7 | propose
Mei | ya Grab | DECISION | t7 | agree
Arun | I'm on diet so salad for me 😂 | PREFERENCE | - | none
Mei | lol sure | OTHER | - | none
""", "topics": {"t1": ("DESTINATION", "KL staycation", "confirmed"), "t2": ("DATE", "15-16 Mar", "confirmed"),
                "t3": ("ACCOMMODATION", "EQ hotel", "rejected"), "t4": ("ACCOMMODATION", "Traders Hotel", "confirmed"),
                "t5": ("ATTRACTION", "Jalan Alor", "rejected"), "t6": ("ATTRACTION", "Lot 10 Hutong", "confirmed"),
                "t7": ("TRANSPORT", "Grab", "confirmed")},
     "prefs": [("Arun", "is on a diet")],
     "facts": {"destination": "Kuala Lumpur", "budget": None, "budget_basis": None, "dates": "15-16 Mar"}},

    {"id": "man-12-bangkok", "destination": "Bangkok", "members": ["Siew Ling", "Hakim", "Teresa", "Daniel"], "lines": """
Siew Ling | 曼谷 trip 有人要吗？ | DESTINATION | t1 | propose
Hakim | aku nak! | DECISION | t1 | agree
Teresa | me too | DECISION | t1 | agree
Daniel | I need to check my leave first | DECISION | t1 | defer
Hakim | bila nak pergi? | DATE | - | ask
Siew Ling | 七月中？mid July | DATE | t2 | propose
Teresa | mid July ok | DECISION | t2 | agree
Hakim | Julai ok | DECISION | t2 | agree
Teresa | 住哪里比较好？ | ACCOMMODATION | - | ask
Hakim | Sukhumvit, dekat BTS | ACCOMMODATION | t3 | propose
Siew Ling | Sukhumvit 好，交通方便 | DECISION | t3 | agree
Teresa | Chatuchak market weekend | ATTRACTION | t4 | propose
Daniel | Chatuchak only Sat Sun ya | ATTRACTION | t4 | info
Teresa | Wat Arun sunset | ATTRACTION | t5 | propose
Siew Ling | 我想按摩！泰式按摩 | ATTRACTION | t6 | propose
Hakim | massage every night 😂 | DECISION | t6 | agree
Teresa | hahaha yes | DECISION | t6 | agree
Daniel | ok leave approved, I'm in | DECISION | t1 | agree
Hakim | budget RM2000 seorang? | BUDGET | t7 | propose
Siew Ling | 两千够 | DECISION | t7 | agree
Teresa | I'm allergic to peanuts, careful with pad thai | PREFERENCE | - | none
Daniel | noted! | OTHER | - | none
""", "topics": {"t1": ("DESTINATION", "Bangkok", "confirmed"), "t2": ("DATE", "mid Jul", "confirmed"),
                "t3": ("ACCOMMODATION", "Sukhumvit near BTS", "pending"), "t4": ("ATTRACTION", "Chatuchak market", "pending"),
                "t5": ("ATTRACTION", "Wat Arun sunset", "pending"), "t6": ("ATTRACTION", "Thai massage", "confirmed"),
                "t7": ("BUDGET", "RM2000 per person", "pending")},
     "prefs": [("Teresa", "is allergic to peanuts")],
     "facts": {"destination": "Bangkok", "budget": None, "budget_basis": None, "dates": "mid Jul"}},
]


from manual_data_batch2 import CHATS_BATCH2  # noqa: E402
from manual_data_batch3 import CHATS_BATCH3  # noqa: E402

CHATS = CHATS + CHATS_BATCH2 + CHATS_BATCH3

if __name__ == "__main__":
    out = to_convs(CHATS, "manual")
    write_jsonl(DATA / "manual.jsonl", out)
    print(f"wrote {len(out)} hand-written training chats, {sum(len(c['messages']) for c in out)} messages")
