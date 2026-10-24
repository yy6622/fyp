"""Third batch of hand-written TRAINING chats (16 chats). Imported by manual_data.py."""

CHATS_BATCH3 = [
    {"id": "man-29-macau", "destination": "Macau", "members": ["Eddie", "Fiona", "Raj"], "lines": """
Fiona | 澳门一日游？从香港坐船过去 | DESTINATION | t1 | propose
Eddie | 好啊，吃葡挞！ | DECISION | t1 | agree
Raj | sure, never been | DECISION | t1 | agree
Eddie | turbojet ferry from Sheung Wan, every 30 mins | TRANSPORT | t2 | propose
Raj | or the bridge bus, cheaper | TRANSPORT | t3 | propose
Fiona | 港珠澳大桥巴士便宜一半 | DECISION | t3 | agree
Eddie | ok bus then | DECISION | t3 | agree
Raj | Ruins of St Paul's | ATTRACTION | t4 | propose
Fiona | 大三巴必去 | DECISION | t4 | agree
Eddie | 安德鲁饼店在路环，有点远 | ATTRACTION | t5 | propose
Raj | how far? | ATTRACTION | - | ask
Eddie | 30 min bus | ATTRACTION | t5 | info
Fiona | 远就算了，市区也有玛嘉烈 | DECISION | t5 | reject
Raj | Venetian at night for the lights | ATTRACTION | t6 | propose
Eddie | 好 | DECISION | t6 | agree
Fiona | 我不赌钱的哦，只看看 | PREFERENCE | - | none
Raj | 😂 same | OTHER | - | none
""", "topics": {"t1": ("DESTINATION", "Macau", "confirmed"), "t2": ("TRANSPORT", "turbojet ferry", "rejected"),
                "t3": ("TRANSPORT", "bridge bus", "confirmed"), "t4": ("ATTRACTION", "Ruins of St Paul's", "confirmed"),
                "t5": ("ATTRACTION", "Lord Stow's in Coloane", "rejected"), "t6": ("ATTRACTION", "Venetian at night", "confirmed")},
     "prefs": [("Fiona", "doesn't gamble")],
     "facts": {"destination": "Macau", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-30-bandung", "destination": "Bandung", "members": ["Nabila", "Sharul", "Izzah", "Akmal"], "lines": """
Nabila | Bandung shopping trip!! 🛍️ | DESTINATION | t1 | propose
Izzah | Bandung murah gila, jom | DECISION | t1 | agree
Sharul | ok tapi aku tak nak shopping je, nak tengok gunung juga | DECISION | t1 | agree
Akmal | ok | DECISION | t1 | agree
Sharul | Tangkuban Perahu volcano | ATTRACTION | t2 | propose
Akmal | Kawah Putih lagi cantik | ATTRACTION | t3 | propose
Izzah | buat dua-dua, same day trip | DECISION | t2 | agree
Nabila | ok dua-dua | DECISION | t3 | agree
Nabila | factory outlet di Jalan Riau | ATTRACTION | t4 | propose
Izzah | wajib! | DECISION | t4 | agree
Sharul | aku tunggu kat kafe 😂 | DECISION | t4 | defer
Akmal | sewa van dengan driver, RM250 sehari | TRANSPORT | t5 | propose
Nabila | ok van | DECISION | t5 | agree
Izzah | setuju | DECISION | t5 | agree
Sharul | ok | DECISION | t5 | agree
Izzah | hotel dekat Dago, RM120 semalam | ACCOMMODATION | t6 | propose
Akmal | Dago ok, banyak kafe | DECISION | t6 | agree
Nabila | 5 hingga 8 Ogos? | DATE | t7 | propose
Sharul | 5-8 Ogos set | DECISION | t7 | agree
Akmal | ok | DECISION | t7 | agree
Izzah | ok | DECISION | t7 | agree
Akmal | aku alergi kacang, hati-hati dengan sambal kacang | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Bandung", "confirmed"), "t2": ("ATTRACTION", "Tangkuban Perahu", "pending"),
                "t3": ("ATTRACTION", "Kawah Putih", "pending"), "t4": ("ATTRACTION", "factory outlets on Jalan Riau", "pending"),
                "t5": ("TRANSPORT", "van with driver", "confirmed"), "t6": ("ACCOMMODATION", "hotel near Dago", "pending"),
                "t7": ("DATE", "5-8 Aug", "confirmed")},
     "prefs": [("Akmal", "is allergic to peanuts")],
     "facts": {"destination": "Bandung", "budget": None, "budget_basis": None, "dates": "5-8 Aug"}},

    {"id": "man-31-siemreap", "destination": "Siem Reap", "members": ["Wen Jie", "Ashwin", "Carmen"], "lines": """
Ashwin | Angkor Wat sunrise has been on my list forever. Siem Reap in December? | DESTINATION | t1 | propose
Carmen | December is the best weather there, yes | DECISION | t1 | agree
Wen Jie | I'm in | DECISION | t1 | agree
Carmen | 3 day Angkor pass is USD 62 | ATTRACTION | t2 | info
Ashwin | 3 day pass then, 1 day is too rushed | ATTRACTION | t2 | propose
Wen Jie | agree, 3 days | DECISION | t2 | agree
Carmen | ok | DECISION | t2 | agree
Wen Jie | tuk tuk driver for all 3 days, USD 20 per day | TRANSPORT | t3 | propose
Carmen | or rent bicycles? | TRANSPORT | t4 | propose
Ashwin | too hot for cycling la | DECISION | t4 | reject
Carmen | ok tuk tuk | DECISION | t3 | agree
Ashwin | tuk tuk 👍 | DECISION | t3 | agree
Carmen | Phare circus one night | ATTRACTION | t5 | propose
Wen Jie | sure | DECISION | t5 | agree
Ashwin | Pub Street for drinks after | ATTRACTION | t6 | propose
Carmen | I don't drink but can come | DECISION | t6 | agree
Wen Jie | boutique hotel with pool, USD 45 a night | ACCOMMODATION | t7 | propose
Ashwin | pool is a must after temples | DECISION | t7 | agree
Carmen | booked! | DECISION | t7 | finalize
Wen Jie | 12 to 16 Dec | DATE | t8 | propose
Ashwin | let me confirm with work first | DECISION | t8 | defer
""", "topics": {"t1": ("DESTINATION", "Siem Reap", "confirmed"), "t2": ("ATTRACTION", "3-day Angkor pass", "confirmed"),
                "t3": ("TRANSPORT", "tuk tuk driver", "confirmed"), "t4": ("TRANSPORT", "rent bicycles", "rejected"),
                "t5": ("ATTRACTION", "Phare circus", "confirmed"), "t6": ("ATTRACTION", "Pub Street", "confirmed"),
                "t7": ("ACCOMMODATION", "boutique hotel with pool", "confirmed"), "t8": ("DATE", "12-16 Dec", "pending")},
     "prefs": [],
     "facts": {"destination": "Siem Reap", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-32-paris", "destination": "Paris", "members": ["Valerie", "Hao", "Qian", "Danny"], "lines": """
Valerie | so... Paris for our 10th friendship anniversary? 🥐 | DESTINATION | t1 | propose
Qian | 哇 巴黎！我要 | DECISION | t1 | agree
Hao | Paris is so expensive though | DECISION | t1 | defer
Danny | once in a lifetime bro | DECISION | t1 | agree
Hao | ok fine, I'm in 😂 | DECISION | t1 | agree
Valerie | budget RM10k per person, 8 days | BUDGET | t2 | propose
Hao | 10k is my absolute max | DECISION | t2 | agree
Qian | 可以 | DECISION | t2 | agree
Danny | ok | DECISION | t2 | agree
Danny | Eiffel Tower summit tickets sell out, book 2 months ahead | ATTRACTION | t3 | propose
Valerie | yes book now | DECISION | t3 | agree
Qian | 卢浮宫一定要 | ATTRACTION | t4 | propose
Hao | Louvre half day is enough for me | DECISION | t4 | agree
Valerie | day trip to Versailles? | ATTRACTION | t5 | propose
Danny | Versailles is huge, full day | ATTRACTION | t5 | info
Hao | skip, I rather walk around Montmartre | ATTRACTION | t6 | propose
Qian | Montmartre 好 | DECISION | t6 | agree
Valerie | apartment in Le Marais, EUR 220 a night | ACCOMMODATION | t7 | propose
Hao | central, ok | DECISION | t7 | agree
Qian | 我想要有电梯的，行李重 | PREFERENCE | - | none
Danny | metro pass for the week | TRANSPORT | t8 | propose
""", "topics": {"t1": ("DESTINATION", "Paris", "confirmed"), "t2": ("BUDGET", "RM10000 per person", "confirmed"),
                "t3": ("ATTRACTION", "Eiffel Tower summit", "pending"), "t4": ("ATTRACTION", "Louvre", "pending"),
                "t5": ("ATTRACTION", "Versailles", "rejected"), "t6": ("ATTRACTION", "Montmartre", "pending"),
                "t7": ("ACCOMMODATION", "apartment in Le Marais", "pending"), "t8": ("TRANSPORT", "weekly metro pass", "pending")},
     "prefs": [("Qian", "wants a lift")],
     "facts": {"destination": "Paris", "budget": 10000, "budget_basis": "per_person", "dates": None}},

    {"id": "man-33-hualien", "destination": "Hualien", "members": ["Pei Yu", "Jun Hao", "Natalie"], "lines": """
Pei Yu | 花莲太鲁阁！台北出发 | DESTINATION | t1 | propose
Jun Hao | 好，我想看清水断崖 | DECISION | t1 | agree
Natalie | ok can | DECISION | t1 | agree
Jun Hao | 台北坐火车到花莲，两个小时 | TRANSPORT | t2 | propose
Natalie | train tickets sell out on weekends | TRANSPORT | t2 | info
Pei Yu | 那我们平日去，礼拜三到礼拜五 | DATE | t3 | propose
Jun Hao | 平日可以 | DECISION | t3 | agree
Natalie | ok weekday | DECISION | t3 | agree
Jun Hao | 太鲁阁要包车，一天大概3000台币 | TRANSPORT | t4 | propose
Natalie | split 3 ok | DECISION | t4 | agree
Pei Yu | 好 | DECISION | t4 | agree
Natalie | 七星潭看日出 | ATTRACTION | t5 | propose
Jun Hao | 日出要5点起床欸 | DECISION | t5 | defer
Pei Yu | 我可以！ | DECISION | t5 | agree
Natalie | 东大门夜市 dinner | ATTRACTION | t6 | propose
Jun Hao | 好啊 | DECISION | t6 | agree
Pei Yu | 我晕车，山路要坐前面 | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Hualien / Taroko", "confirmed"), "t2": ("TRANSPORT", "train from Taipei", "pending"),
                "t3": ("DATE", "weekday Wed-Fri", "confirmed"), "t4": ("TRANSPORT", "chartered car in Taroko", "confirmed"),
                "t5": ("ATTRACTION", "Qixingtan sunrise", "confirmed"), "t6": ("ATTRACTION", "Dongdamen night market", "confirmed")},
     "prefs": [("Pei Yu", "gets carsick")],
     "facts": {"destination": "Hualien", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-34-okinawa", "destination": "Okinawa", "members": ["Teck", "Ain", "Mandy", "Shun"], "lines": """
Mandy | Okinawa > Tokyo for a beach holiday, agree? | DESTINATION | t1 | propose
Shun | agree, Tokyo too crowded | DECISION | t1 | agree
Ain | Okinawa ok, I want the aquarium | DECISION | t1 | agree
Teck | ok | DECISION | t1 | agree
Teck | need to rent car, no train there except the monorail | TRANSPORT | t2 | propose
Shun | I can drive, have IDP | DECISION | t2 | agree
Mandy | ok car | DECISION | t2 | agree
Ain | Churaumi aquarium, the whale sharks 🦈 | ATTRACTION | t3 | propose
Mandy | must | DECISION | t3 | agree
Teck | yes | DECISION | t3 | agree
Shun | Kouri island bridge drive | ATTRACTION | t4 | propose
Ain | nice | DECISION | t4 | agree
Mandy | dates 20 to 25 June? | DATE | t5 | propose
Teck | June is rainy season leh | DECISION | t5 | reject
Shun | then early July? after rainy season | DATE | t6 | propose
Ain | early Jul ok | DECISION | t6 | agree
Mandy | ok early July | DECISION | t6 | agree
Teck | ok | DECISION | t6 | agree
Ain | hotel in Onna village by the beach | ACCOMMODATION | t7 | propose
Shun | I'll compare prices first | DECISION | t7 | defer
Ain | I need halal or seafood options | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Okinawa", "confirmed"), "t2": ("TRANSPORT", "rent a car", "confirmed"),
                "t3": ("ATTRACTION", "Churaumi aquarium", "confirmed"), "t4": ("ATTRACTION", "Kouri island bridge", "pending"),
                "t5": ("DATE", "20-25 Jun", "rejected"), "t6": ("DATE", "early Jul", "confirmed"),
                "t7": ("ACCOMMODATION", "hotel in Onna village", "pending")},
     "prefs": [("Ain", "needs halal or seafood")],
     "facts": {"destination": "Okinawa", "budget": None, "budget_basis": None, "dates": "early Jul"}},

    {"id": "man-35-lombok", "destination": "Lombok", "members": ["Firdaus", "Kar Men", "Jolene"], "lines": """
Jolene | Bali too touristy now, Lombok instead? | DESTINATION | t1 | propose
Firdaus | Lombok setuju, Gili islands! | DECISION | t1 | agree
Kar Men | ok but how to get there | TRANSPORT | - | ask
Jolene | direct flight KL to Lombok AirAsia | TRANSPORT | t2 | propose
Kar Men | oh good | DECISION | t2 | agree
Firdaus | Gili Trawangan 2 nights, no cars there only bicycles | ACCOMMODATION | t3 | propose
Jolene | love it | DECISION | t3 | agree
Kar Men | ok | DECISION | t3 | agree
Kar Men | Mount Rinjani trek? | ATTRACTION | t4 | propose
Firdaus | Rinjani 3 days hardcore, aku tak larat | DECISION | t4 | reject
Jolene | same, no Rinjani | DECISION | t4 | reject
Jolene | snorkel with turtles at Gili Air | ATTRACTION | t5 | propose
Kar Men | yesss turtles | DECISION | t5 | agree
Firdaus | on | DECISION | t5 | agree
Kar Men | budget? RM2000 each enough I think | BUDGET | t6 | propose
Jolene | should be | DECISION | t6 | agree
Firdaus | cukup | DECISION | t6 | agree
""", "topics": {"t1": ("DESTINATION", "Lombok", "confirmed"), "t2": ("TRANSPORT", "direct AirAsia flight", "confirmed"),
                "t3": ("ACCOMMODATION", "2 nights on Gili Trawangan", "confirmed"), "t4": ("ATTRACTION", "Mount Rinjani trek", "rejected"),
                "t5": ("ATTRACTION", "turtle snorkel at Gili Air", "confirmed"), "t6": ("BUDGET", "RM2000 each", "confirmed")},
     "prefs": [],
     "facts": {"destination": "Lombok", "budget": 2000, "budget_basis": "per_person", "dates": None}},

    {"id": "man-36-fraser", "destination": "Fraser's Hill", "members": ["Uncle Lee", "Auntie May", "Kok Wai", "Siti"], "lines": """
Kok Wai | Uncle Auntie, this Sunday go Fraser's Hill for bird watching? | DESTINATION | t1 | propose
Uncle Lee | ok good, bring my binoculars | DECISION | t1 | agree
Auntie May | 要穿外套吗？ | OTHER | - | none
Siti | yes auntie, quite cold up there | OTHER | - | none
Siti | leave 6am so we reach early for the birds | DATE | t2 | propose
Auntie May | 六点太早了 | DECISION | t2 | reject
Kok Wai | 7am then? | DATE | t3 | propose
Auntie May | 七点可以 | DECISION | t3 | agree
Uncle Lee | ok | DECISION | t3 | agree
Siti | Ye Olde Smokehouse for lunch, English food | ATTRACTION | t4 | propose
Uncle Lee | 我要吃中餐 | DECISION | t4 | reject
Kok Wai | there's a Chinese restaurant at the clock tower | ATTRACTION | t5 | propose
Auntie May | 那里好 | DECISION | t5 | agree
Uncle Lee | ok | DECISION | t5 | agree
Kok Wai | I drive the Alza, can fit 4 | TRANSPORT | t6 | propose
Siti | ok | DECISION | t6 | agree
Auntie May | 我腰不好，不要走山路 | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Fraser's Hill", "pending"), "t2": ("DATE", "leave 6am", "rejected"),
                "t3": ("DATE", "leave 7am", "confirmed"), "t4": ("ATTRACTION", "Ye Olde Smokehouse", "rejected"),
                "t5": ("ATTRACTION", "Chinese restaurant at the clock tower", "confirmed"), "t6": ("TRANSPORT", "Kok Wai drives", "pending")},
     "prefs": [("Auntie May", "has a bad back")],
     "facts": {"destination": None, "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-37-yogyakarta", "destination": "Yogyakarta", "members": ["Haikal", "Rina", "Joel"], "lines": """
Rina | Yogya for Borobudur sunrise? | DESTINATION | t1 | propose
Haikal | Borobudur + Prambanan, jom | DECISION | t1 | agree
Joel | sure | DECISION | t1 | agree
Joel | how much the Borobudur sunrise ticket ah? | ATTRACTION | - | ask
Rina | around RM180 including the climb permit | ATTRACTION | t2 | info
Rina | Borobudur sunrise | ATTRACTION | t2 | propose
Haikal | worth it | DECISION | t2 | agree
Joel | ok | DECISION | t2 | agree
Haikal | Prambanan sunset same day? | ATTRACTION | t3 | propose
Joel | too tiring same day, next day | DECISION | t3 | defer
Rina | Malioboro street for shopping batik | ATTRACTION | t4 | propose
Joel | ok | DECISION | t4 | agree
Haikal | ok | DECISION | t4 | agree
Joel | stay near Malioboro then, easy | ACCOMMODATION | t5 | propose
Rina | ok | DECISION | t5 | agree
Haikal | Grab car around the city, cheap | TRANSPORT | t6 | propose
Rina | yup Grab | DECISION | t6 | agree
Joel | 4D3N, 14 to 17 Nov | DATE | t7 | propose
Haikal | ok 14-17 Nov | DECISION | t7 | agree
Rina | ok | DECISION | t7 | agree
""", "topics": {"t1": ("DESTINATION", "Yogyakarta", "confirmed"), "t2": ("ATTRACTION", "Borobudur sunrise", "confirmed"),
                "t3": ("ATTRACTION", "Prambanan sunset", "pending"), "t4": ("ATTRACTION", "Malioboro street", "confirmed"),
                "t5": ("ACCOMMODATION", "near Malioboro", "confirmed"), "t6": ("TRANSPORT", "Grab car", "confirmed"),
                "t7": ("DATE", "14-17 Nov", "confirmed")},
     "prefs": [],
     "facts": {"destination": "Yogyakarta", "budget": None, "budget_basis": None, "dates": "14-17 Nov"}},

    {"id": "man-38-kathmandu", "destination": "Nepal", "members": ["Prakash", "Sabrina", "Ming"], "lines": """
Prakash | Everest base camp trek next April, who's crazy enough? 🏔️ | DESTINATION | t1 | propose
Ming | me!!! | DECISION | t1 | agree
Sabrina | EBC is 12 days of walking... I'm not fit enough | DECISION | t1 | reject
Prakash | Annapurna Poon Hill is easier, 4-5 days | DESTINATION | t2 | propose
Sabrina | Poon Hill I can try | DECISION | t2 | agree
Ming | ok Poon Hill, EBC next time | DECISION | t2 | agree
Prakash | Poon Hill then | DECISION | t2 | finalize
Ming | fly KL to Kathmandu then bus to Pokhara | TRANSPORT | t3 | propose
Sabrina | bus 8 hours?? domestic flight 25 min | TRANSPORT | t4 | propose
Prakash | flight better, roads bad | DECISION | t4 | agree
Ming | ok fly | DECISION | t4 | agree
Prakash | hire a guide + porter, USD 50 per day | ATTRACTION | t5 | propose
Ming | guide yes, porter I carry my own | DECISION | t5 | agree
Sabrina | I need porter 😅 | DECISION | t5 | agree
Ming | budget RM5000 each including flights? | BUDGET | t6 | propose
Prakash | 5k ok | DECISION | t6 | agree
Sabrina | ok | DECISION | t6 | agree
Sabrina | I get altitude sickness easily, need to go slow | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Everest base camp", "rejected"), "t2": ("DESTINATION", "Poon Hill", "confirmed"),
                "t3": ("TRANSPORT", "bus to Pokhara", "rejected"), "t4": ("TRANSPORT", "domestic flight to Pokhara", "confirmed"),
                "t5": ("ATTRACTION", "guide + porter", "confirmed"), "t6": ("BUDGET", "RM5000 each", "confirmed")},
     "prefs": [("Sabrina", "gets altitude sickness")],
     "facts": {"destination": "Poon Hill", "budget": 5000, "budget_basis": "per_person", "dates": None}},

    {"id": "man-39-desaru", "destination": "Desaru", "members": ["Azlan", "Joanne", "Mei Mei", "Kevin"], "lines": """
Joanne | Desaru beach resort 2D1N? company long weekend | DESTINATION | t1 | propose
Azlan | ok | DECISION | t1 | agree
Kevin | can | DECISION | t1 | agree
Mei Mei | 好啊 | DECISION | t1 | agree
Azlan | Hard Rock Hotel Desaru, RM550 per night | ACCOMMODATION | t2 | propose
Kevin | 550 for one night quite steep | DECISION | t2 | reject
Joanne | Anantara more expensive 😂 | ACCOMMODATION | t2 | info
Mei Mei | 有没有便宜一点的？ | ACCOMMODATION | - | ask
Kevin | Desaru Coast Riverside, RM300 | ACCOMMODATION | t3 | propose
Joanne | Riverside ok | DECISION | t3 | agree
Azlan | ok la Riverside | DECISION | t3 | agree
Mei Mei | 水上乐园 Adventure Waterpark | ATTRACTION | t4 | propose
Joanne | yes! | DECISION | t4 | agree
Kevin | ok | DECISION | t4 | agree
Azlan | Ostrich farm 😂 | ATTRACTION | t5 | propose
Mei Mei | 哈哈 可以 | DECISION | t5 | agree
Joanne | I drive, pick everyone at 8am | TRANSPORT | t6 | propose
Kevin | 8am ok | DECISION | t6 | agree
Azlan | ok | DECISION | t6 | agree
Mei Mei | 我会晕车 | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Desaru", "confirmed"), "t2": ("ACCOMMODATION", "Hard Rock Hotel", "rejected"),
                "t3": ("ACCOMMODATION", "Desaru Coast Riverside", "confirmed"), "t4": ("ATTRACTION", "Adventure Waterpark", "confirmed"),
                "t5": ("ATTRACTION", "Ostrich farm", "pending"), "t6": ("TRANSPORT", "Joanne drives at 8am", "confirmed")},
     "prefs": [("Mei Mei", "gets carsick")],
     "facts": {"destination": "Desaru", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-40-srilanka", "destination": "Sri Lanka", "members": ["Thanuja", "Kelvin", "Aqil", "Wan Ting"], "lines": """
Thanuja | Sri Lanka in March? I can show you around, my relatives in Kandy | DESTINATION | t1 | propose
Kelvin | that's awesome, yes | DECISION | t1 | agree
Wan Ting | yes!! | DECISION | t1 | agree
Aqil | in | DECISION | t1 | agree
Thanuja | Kandy to Ella train, the famous blue train | TRANSPORT | t2 | propose
Wan Ting | the one in all the photos? yes | DECISION | t2 | agree
Kelvin | book reserved seats early ya | TRANSPORT | t2 | info
Aqil | Sigiriya rock climb | ATTRACTION | t3 | propose
Kelvin | 1200 steps, early morning only | ATTRACTION | t3 | info
Wan Ting | ok I can | DECISION | t3 | agree
Thanuja | safari in Yala for leopards | ATTRACTION | t4 | propose
Aqil | Yala very far south | DECISION | t4 | defer
Kelvin | maybe Udawalawe instead, elephants, closer | ATTRACTION | t5 | propose
Thanuja | Udawalawe good also | DECISION | t5 | agree
Wan Ting | budget RM4500 per person? | BUDGET | t6 | propose
Aqil | I think 4k enough | BUDGET | t7 | propose
Kelvin | ok 4k | DECISION | t7 | agree
Thanuja | 4k enough since we stay with my family some nights | DECISION | t7 | agree
Wan Ting | ok RM4000 | DECISION | t7 | agree
Aqil | I can't take too spicy curry 😅 | PREFERENCE | - | none
""", "topics": {"t1": ("DESTINATION", "Sri Lanka", "confirmed"), "t2": ("TRANSPORT", "Kandy to Ella train", "pending"),
                "t3": ("ATTRACTION", "Sigiriya rock", "pending"), "t4": ("ATTRACTION", "Yala safari", "pending"),
                "t5": ("ATTRACTION", "Udawalawe safari", "pending"), "t6": ("BUDGET", "RM4500 per person", "rejected"),
                "t7": ("BUDGET", "RM4000", "confirmed")},
     "prefs": [("Aqil", "can't eat very spicy food")],
     "facts": {"destination": "Sri Lanka", "budget": 4000, "budget_basis": "per_person", "dates": None}},

    {"id": "man-41-pangkor", "destination": "Pangkor", "members": ["Zack", "Elena", "Rosli"], "lines": """
Rosli | Pangkor island weekend, simple trip | DESTINATION | t1 | propose
Elena | ok simple trip I like | DECISION | t1 | agree
Zack | jom | DECISION | t1 | agree
Zack | ferry from Lumut 30 min | TRANSPORT | t2 | propose
Rosli | yup | DECISION | t2 | agree
Elena | stay at Teluk Nipah chalet | ACCOMMODATION | t3 | propose
Zack | Teluk Nipah ok, can see hornbills | DECISION | t3 | agree
Rosli | ok | DECISION | t3 | agree
Elena | rent motorbike to go around the island | TRANSPORT | t4 | propose
Rosli | aku tak reti bawa motor | DECISION | t4 | reject
Zack | the pink taxi van also can | TRANSPORT | t5 | propose
Elena | ok pink van then | DECISION | t5 | agree
Rosli | ok | DECISION | t5 | agree
Zack | ikan bakar dinner at the jetty | ATTRACTION | t6 | propose
Elena | yes seafood | DECISION | t6 | agree
Rosli | I'm allergic to prawns but fish ok | PREFERENCE | - | none
Elena | 27 to 28 Sep | DATE | t7 | propose
Zack | can | DECISION | t7 | agree
""", "topics": {"t1": ("DESTINATION", "Pangkor", "confirmed"), "t2": ("TRANSPORT", "ferry from Lumut", "confirmed"),
                "t3": ("ACCOMMODATION", "chalet at Teluk Nipah", "confirmed"), "t4": ("TRANSPORT", "rent motorbike", "rejected"),
                "t5": ("TRANSPORT", "pink taxi van", "confirmed"), "t6": ("ATTRACTION", "ikan bakar at the jetty", "confirmed"),
                "t7": ("DATE", "27-28 Sep", "confirmed")},
     "prefs": [("Rosli", "is allergic to prawns")],
     "facts": {"destination": "Pangkor", "budget": None, "budget_basis": None, "dates": "27-28 Sep"}},

    {"id": "man-42-maldives", "destination": "Maldives", "members": ["Sharon", "Ivan"], "lines": """
Sharon | honeymoon: Maldives or Mauritius? | DESTINATION | - | ask
Ivan | Maldives, closer and direct flight | DESTINATION | t2 | propose
Sharon | ok Maldives 🥰 | DECISION | t2 | agree
Ivan | water villa for at least 2 nights | ACCOMMODATION | t3 | propose
Sharon | yes!!! | DECISION | t3 | agree
Sharon | all inclusive package so we don't worry about food | ACCOMMODATION | t4 | propose
Ivan | all inclusive more expensive but ok | DECISION | t4 | agree
Ivan | seaplane transfer is like USD 700 return 😳 | TRANSPORT | t5 | propose
Sharon | speedboat resort then, cheaper | TRANSPORT | t6 | propose
Ivan | but seaplane view is the highlight | DECISION | t5 | agree
Sharon | hmm ok let's decide after we see total price | DECISION | t6 | defer
Ivan | budget RM25000 total for both | BUDGET | t7 | propose
Sharon | ok max 25k | DECISION | t7 | agree
Sharon | I want a spa day 💆‍♀️ | PREFERENCE | - | none
""", "topics": {"t2": ("DESTINATION", "Maldives", "confirmed"), "t3": ("ACCOMMODATION", "water villa", "confirmed"),
                "t4": ("ACCOMMODATION", "all inclusive package", "confirmed"), "t5": ("TRANSPORT", "seaplane transfer", "pending"),
                "t6": ("TRANSPORT", "speedboat resort", "pending"), "t7": ("BUDGET", "RM25000 total", "confirmed")},
     "prefs": [("Sharon", "wants a spa day")],
     "facts": {"destination": "Maldives", "budget": 25000, "budget_basis": "total", "dates": None}},

    {"id": "man-43-fireflies", "destination": "Kuala Selangor", "members": ["Dev", "Huey", "Ammar", "Lily"], "lines": """
Huey | anyone wants to see fireflies at Kuala Selangor this Saturday night? | DESTINATION | t1 | propose
Dev | first time! yes | DECISION | t1 | agree
Lily | can | DECISION | t1 | agree
Ammar | I have dinner with family, next week? | DATE | t2 | propose
Huey | next Saturday also ok | DECISION | t2 | agree
Dev | ok next Sat | DECISION | t2 | agree
Lily | ok | DECISION | t2 | agree
Dev | seafood dinner at Pasir Penambang first | ATTRACTION | t3 | propose
Ammar | yes ikan bakar there best | DECISION | t3 | agree
Lily | I don't eat seafood 😢 | PREFERENCE | - | none
Huey | they have chicken also don't worry | OTHER | - | none
Huey | Bukit Melawati monkeys in the afternoon | ATTRACTION | t4 | propose
Lily | monkeys snatch food leh | DECISION | t4 | defer
Ammar | I drive, can fit 3 more | TRANSPORT | t5 | propose
Dev | thanks bro | DECISION | t5 | agree
Lily | ok | DECISION | t5 | agree
Huey | 👍 | DECISION | t5 | agree
""", "topics": {"t1": ("DESTINATION", "Kuala Selangor fireflies", "confirmed"), "t2": ("DATE", "next Saturday", "confirmed"),
                "t3": ("ATTRACTION", "seafood at Pasir Penambang", "pending"), "t4": ("ATTRACTION", "Bukit Melawati", "pending"),
                "t5": ("TRANSPORT", "Ammar drives", "confirmed")},
     "prefs": [("Lily", "doesn't eat seafood")],
     "facts": {"destination": "Kuala Selangor", "budget": None, "budget_basis": None, "dates": None}},

    {"id": "man-44-kotabharu", "destination": "Kota Bharu", "members": ["Nik", "Faizah", "Hong Wei"], "lines": """
Nik | jom balik kampung aku Kota Bharu cuti ni, makan nasi kerabu! | DESTINATION | t1 | propose
Hong Wei | wah ok, never been Kelantan | DECISION | t1 | agree
Faizah | on! | DECISION | t1 | agree
Faizah | naik flight ke KB, RM150 je | TRANSPORT | t2 | propose
Hong Wei | flight ok, driving 7 hours no way | DECISION | t2 | agree
Nik | ok flight | DECISION | t2 | agree
Nik | stay rumah family aku, free 😎 | ACCOMMODATION | t3 | propose
Faizah | best!! terima kasih | DECISION | t3 | agree
Hong Wei | thank you Nik! | DECISION | t3 | agree
Nik | Pasar Siti Khadijah pagi-pagi | ATTRACTION | t4 | propose
Faizah | wajib, beli kain | DECISION | t4 | agree
Hong Wei | I can't take very spicy food ah | PREFERENCE | - | none
Nik | Pantai Cahaya Bulan petang | ATTRACTION | t5 | propose
Faizah | ok | DECISION | t5 | agree
Hong Wei | Wat Phothivihan reclining Buddha? | ATTRACTION | t6 | propose
Nik | boleh, 30 min dari bandar | DECISION | t6 | agree
""", "topics": {"t1": ("DESTINATION", "Kota Bharu", "confirmed"), "t2": ("TRANSPORT", "flight to KB", "confirmed"),
                "t3": ("ACCOMMODATION", "Nik's family house", "confirmed"), "t4": ("ATTRACTION", "Pasar Siti Khadijah", "confirmed"),
                "t5": ("ATTRACTION", "Pantai Cahaya Bulan", "confirmed"), "t6": ("ATTRACTION", "Wat Phothivihan", "confirmed")},
     "prefs": [("Hong Wei", "can't eat very spicy food")],
     "facts": {"destination": "Kota Bharu", "budget": None, "budget_basis": None, "dates": None}},
]
