"""Synthesise (saved places + current plan + group discussion -> plan changes) training data for Voya.

Why synthetic: there is no public dataset of Malaysian-style group travel
chats labelled with the itinerary the group settled on, and the app has no
real users yet. So each example is built backwards:

  1. sample a hidden "ground truth" plan (which place, which day, what time)
  2. act out a messy group chat that arrives at that plan - proposals,
     agreement, rejections, counter-proposals, changes of mind, undecided
     ideas, small talk - in English / Mandarin / Malay, mixed per speaker
  3. the label is the hidden plan, so it is correct by construction

Each example also has a list of places the group saved (some relevant, some
not, sometimes none) and a plan that already exists (sometimes empty). The
answer is the set of CHANGES the chat implies: things to add (flagged
saved / not saved), planned things to move or re-time, planned things to
drop.

Usage:
    python generate_dataset.py                 # 600 train / 60 val / 60+60 test
    python generate_dataset.py --train 600 --seed 7

Outputs (./data):
    train.jsonl, val.jsonl      Vertex AI tuning format
    test_seen.jsonl             unseen chats, destinations seen in training
    test_unseen.jsonl           destinations never seen in training
    preview.txt                 a few examples to read by eye
"""
import argparse
import datetime as dt
import json
import random
from pathlib import Path

from kb import DESTINATIONS, HELD_OUT
from prompt_format import build_user_prompt, dump_answer, to_gemini_example

# ----------------------------------------------------------------- slots
SLOT_ORDER = "BMLAEDN"
SLOT_DEFAULT = {"B": "08:00", "M": "10:00", "L": "12:30", "A": "14:30", "E": "17:00", "D": "19:00", "N": "21:00"}
# explicit times a group might say for each part of the day; windows never
# overlap, so two items on one day can never end up with the same time
SLOT_TIMES = {
    "B": ["07:30", "08:30", "09:00"],
    "M": ["09:30", "10:30", "11:00", "11:30"],
    "L": ["12:00", "13:00", "13:30"],
    "A": ["14:00", "15:00", "15:30", "16:00"],
    "E": ["16:30", "17:30", "18:00"],
    "D": ["18:30", "19:30", "20:00"],
    "N": ["20:30", "21:30", "22:00"],
}
SLOT_WORDS = {
    "en": {"B": ["for breakfast", "breakfast"], "M": ["in the morning", "morning"], "L": ["for lunch", "lunch time"],
           "A": ["in the afternoon", "afternoon", "after lunch"], "E": ["in the evening", "evening"],
           "D": ["for dinner", "dinner time"], "N": ["at night", "after dinner"]},
    "zh": {"B": ["早餐", "早餐时间"], "M": ["早上", "上午"], "L": ["午餐", "中午"],
           "A": ["下午", "午餐过后"], "E": ["傍晚"], "D": ["晚餐", "晚餐时间"], "N": ["晚上", "晚餐过后"]},
    "ms": {"B": ["time sarapan", "time breakfast"], "M": ["pagi", "waktu pagi"], "L": ["time lunch", "tengah hari"],
           "A": ["petang", "lepas lunch"], "E": ["lewat petang", "waktu senja"],
           "D": ["time dinner", "time makan malam"], "N": ["malam", "lepas dinner"]},
}

WEEKDAY_SHORT = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
WEEKDAY_FULL = {
    "en": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
    "zh": ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期天"],
    "ms": ["hari Isnin", "hari Selasa", "hari Rabu", "hari Khamis", "hari Jumaat", "hari Sabtu", "hari Ahad"],
}
ORDINAL = {
    "en": ["first day", "second day", "third day", "fourth day", "fifth day"],
    "zh": ["第一天", "第二天", "第三天", "第四天", "第五天"],
    "ms": ["hari pertama", "hari kedua", "hari ketiga", "hari keempat", "hari kelima"],
}
LAST_DAY = {"en": ["last day", "the last day"], "zh": ["最后一天"], "ms": ["hari last", "hari terakhir"]}

NAMES = {
    "zh": ["Wei Jie", "Xin Yi", "Jia Hui", "Zhi Hao", "Mei Ling", "Kai Xuan", "Yong Yun", "Jun Hao", "Hui Min", "Shu Ting"],
    "ms": ["Aina", "Hafiz", "Nurul", "Amir", "Syafiq", "Farah", "Danial", "Aisyah", "Irfan", "Siti"],
    "en": ["Kumar", "Priya", "Arjun", "Divya", "Daniel", "Sarah", "Ryan", "Michelle", "Jason", "Rachel"],
}

# ------------------------------------------------------------- templates
# {poi} place as the speaker would call it, {when} day (+ part of day / time)
T = {
    "propose": {
        "en": ["{poi} {when}?", "how about {poi} {when}", "eh {when} we go {poi} la", "i wanna go {poi}, {when} can?",
               "{when} go {poi} ok or not", "guys, {when} - {poi}?", "can we do {poi} {when}", "{when} i suggest {poi}",
               "{when} lets go {poi}", "what about {poi}? {when}", "{when} put {poi} can?", "I vote {poi} {when}"],
        "zh": ["{when}去{poi}怎样？", "{when}我想去{poi}", "不如{when}去{poi}", "{when}可以去{poi}吗", "{poi}要不要排{when}",
               "{when}去{poi}啦", "我建议{when}去{poi}", "{when}排{poi}好不好", "{when}我们去{poi}", "{poi}放{when}可以吗"],
        "ms": ["{when} pergi {poi} nak tak?", "jom {poi} {when}", "{when} kita pergi {poi} la", "aku nak pergi {poi}, {when} boleh?",
               "apa kata {when} kita singgah {poi}", "{poi} {when} ok tak", "cadang {when} pergi {poi}",
               "{when} kita ke {poi} boleh?", "korang, {when} {poi} nak?", "{when} letak {poi} la"],
    },
    "propose_food": {
        "en": ["{when} eat at {poi}?", "{when} makan at {poi} la", "{poi} {when}, heard it's damn good", "{when} lets try {poi}"],
        "zh": ["{when}吃{poi}怎样？", "{when}去吃{poi}", "{when}想吃{poi}", "听说{poi}很好吃，{when}去？"],
        "ms": ["{when} makan kat {poi} nak?", "jom makan {poi} {when}", "{when} try {poi} la, sedap katanya", "{when} makan dekat {poi} boleh?"],
    },
    "propose_nowhen": {
        "en": ["should we go {poi} also?", "anyone keen on {poi}?", "what about {poi}?", "do we want to squeeze in {poi}?"],
        "zh": ["要不要也去{poi}？", "有人想去{poi}吗", "{poi}要不要去？", "还要不要加{poi}"],
        "ms": ["nak pergi {poi} jugak tak?", "ada sapa nak pergi {poi}?", "{poi} macam mana?", "nak masukkan {poi} sekali ke?"],
    },
    "agree": {
        "en": ["ok can", "on", "sure", "good idea", "ok set", "can can", "+1", "nice, lock it in", "yes pls", "ok i'm in",
               "steady", "ok no problem", "sounds good", "can, i'm ok"],
        "zh": ["可以", "好啊", "没问题", "赞成", "ok可以", "好，就这样", "+1", "行", "可以可以", "好，我ok", "没意见"],
        "ms": ["boleh", "ok jom", "set", "setuju", "on je", "cun", "ok boleh", "jom", "ok set", "boleh je", "aku ok"],
    },
    "reject": {
        "en": ["nah {poi} too far la", "been there already, skip", "too expensive leh, skip {poi}", "{poi} very touristy, no need",
               "don't want la, tiring", "skip la that one", "{poi} not worth it honestly, pass"],
        "zh": ["不要啦，太远了", "去过了，跳过吧", "太贵了，不要", "{poi}很多人，不去了", "算了啦那边没什么", "{poi}不值得去，pass"],
        "ms": ["tak payah la, jauh sangat", "dah pernah pergi, skip je", "mahal la, tak nak", "{poi} ramai orang sangat, tak payah",
               "malas la yang tu", "{poi} tak berbaloi, pass"],
    },
    "concede": {
        "en": ["ok fine skip", "okok nvm then", "alright drop it", "fine la", "ok forget it"],
        "zh": ["好吧那不去", "ok那算了", "行，跳过", "好啦不去了"],
        "ms": ["ok la skip", "takpe la kalau macam tu", "ok cancel yang tu", "baiklah tak jadi"],
    },
    "counter": {
        "en": ["{old} not really my thing, {new} better?", "instead of {old} why not {new}", "skip {old}, go {new} la same timing",
               "i prefer {new} over {old}", "{old} boring la, change to {new}?"],
        "zh": ["{old}不如换{new}", "不要{old}啦，去{new}比较好", "我比较想去{new}，{old}就算了", "{old}换成{new}可以吗", "同样时间去{new}吧，不要{old}"],
        "ms": ["tak nak {old} la, tukar {new} boleh?", "{new} lagi best dari {old}", "ganti {old} dengan {new} la",
               "daripada {old} baik pergi {new}", "time tu pergi {new} je la, {old} tak payah"],
    },
    "move": {
        "en": ["actually move {poi} to {day} la, {oldday} too packed", "can we shift {poi} to {day} instead",
               "change of plan: {poi} on {day} better", "{poi} push to {day} can? same timing"],
        "zh": ["{poi}改去{day}吧，{oldday}太赶了", "把{poi}换到{day}可以吗", "{poi}还是{day}去比较好", "{poi}移到{day}，时间一样"],
        "ms": ["tukar {poi} ke {day} la, {oldday} padat sangat", "boleh pindah {poi} ke {day} tak", "{poi} baik buat {day}",
               "{poi} anjak ke {day} la, masa sama"],
    },
    "cancel": {
        "en": ["eh cancel {poi} la, no time", "drop {poi} bah, too rushed", "on second thought skip {poi}", "{poi} take out la, cannot make it"],
        "zh": ["{poi}取消吧，时间不够", "{poi}还是不要了，太赶", "想了一下{poi}不去了", "{poi}拿掉吧，来不及"],
        "ms": ["cancel {poi} la, tak sempat", "{poi} tak jadi la, rushing sangat", "fikir balik, skip {poi} je", "buang {poi} la, tak sempat"],
    },
    "unsure": {
        "en": ["hmm see first la", "not sure leh, decide later", "depends on weather, tbc", "maybe? see how", "let me think first"],
        "zh": ["再看看吧", "不确定咧，迟点再决定", "看天气吧，到时再说", "可能吧，再讲", "我想一下先"],
        "ms": ["tengok dulu la", "tak sure lagi, nanti decide", "ikut cuaca la, tbc", "mungkin, tengok macam mana", "bagi aku fikir dulu"],
    },
    "park": {
        "en": ["ok tbc then", "ok we decide later", "alright keep it open first"],
        "zh": ["ok那先保留", "好，迟点再决定", "那先放着"],
        "ms": ["ok kita tengok nanti", "ok nanti decide", "takpe, hold dulu"],
    },
    "ask_time": {
        "en": ["what time ah?", "what time we go {poi}?", "{poi} what time?"],
        "zh": ["几点？", "{poi}几点去", "那{poi}要几点"],
        "ms": ["pukul berapa?", "{poi} nak pergi pukul berapa", "{poi} jam berapa?"],
    },
    "give_time": {
        "en": ["{time}", "{time} la", "let's say {time}", "{time} should be ok"],
        "zh": ["{time}", "{time}吧", "就{time}"],
        "ms": ["{time}", "{time} la", "{time} kot", "kita set {time}"],
    },
    "change_time": {
        "en": ["{poi} make it {time} instead", "change {poi} to {time} la", "{poi} {time} better, can?"],
        "zh": ["{poi}改{time}", "{poi}还是{time}去吧", "{poi}换成{time}可以吗"],
        "ms": ["{poi} tukar ke {time} la", "{poi} buat {time} je", "{poi} {time} lagi ok, boleh?"],
    },
    "hotel": {
        "en": ["hotel check in is {time} btw, drop bags first", "check in at {time} ya", "first day {time} we check in hotel"],
        "zh": ["酒店{time}check in，先放行李", "第一天{time}办入住", "{time}先去酒店check in"],
        "ms": ["check in hotel {time}, letak beg dulu", "hotel check in {time} tau", "hari pertama {time} kita check in hotel"],
    },
    "airport": {
        "en": ["last day leave for airport by {time} ya", "last day need to go airport at {time}", "flight back is late, {time} we go airport on the last day"],
        "zh": ["最后一天{time}要出发去机场", "回程那天{time}去机场", "最后一天{time}就要去机场了"],
        "ms": ["hari last kena gerak ke airport {time}", "hari terakhir {time} pergi airport", "hari last {time} kita gerak pergi airport"],
    },
    "noise": {
        "en": ["who's bringing the powerbank", "i haven't applied leave yet lol", "eh passport all valid right", "weather there now how ah",
               "i transfer deposit tonight", "remind me to buy sim card", "so excited!!", "lol", "my mum ask me buy souvenir",
               "anyone got luggage scale?", "booked my leave liao", "eh who handling the money", "need to change currency this week",
               "hahaha ok", "wait i reading back the chat"],
        "zh": ["谁带充电宝", "我还没请假哈哈", "护照都没过期吧", "那边现在天气怎样", "我今晚转账", "好期待！！", "哈哈哈", "要记得买sim卡",
               "行李限重多少", "我妈叫我买手信", "假期批了！", "谁负责管钱", "这星期要去换钱", "等下，我看回聊天记录"],
        "ms": ["sapa bawa powerbank", "aku belum apply cuti lagi haha", "passport semua valid kan", "cuaca sana macam mana sekarang",
               "malam ni aku transfer duit", "tak sabar!!", "hahaha", "jangan lupa beli sim card", "luggage berapa kg eh",
               "mak aku kirim souvenir", "cuti dah lulus!", "sapa pegang duit", "minggu ni kena tukar duit", "jap aku baca balik chat"],
    },
    # a place is named but nobody is proposing it - must NOT end up in the plan
    # someone suggests a thing that is already in the plan -> no change
    "already_planned": {
        "en": ["that one already in the plan", "eh already inside the itinerary what", "we already put that"],
        "zh": ["这个已经在行程里了", "已经排了啊", "行程里有了"],
        "ms": ["yang tu dah ada dalam plan", "dah masuk itinerary dah", "kita dah letak yang tu"],
    },
    "mention_only": {
        "en": ["my cousin went {poi} last year btw", "saw {poi} on tiktok yesterday lol", "{poi} is where my sis got food poisoning haha"],
        "zh": ["我朋友上次有去{poi}", "昨天在小红书看到{poi}", "我姐上次去{poi}拍了很多照"],
        "ms": ["kawan aku pernah pergi {poi} dulu", "semalam nampak {poi} kat tiktok", "kakak aku pergi {poi} tahun lepas"],
    },
}
PARTICLES = {"en": [" la", " lah", " lor", " leh", " ah", " wei"], "zh": ["啦", "咯", "啊", " lo"], "ms": [" la", " je", " kot", " weh"]}


# ------------------------------------------------------------- rendering
def fmt_time(hhmm: str, lang: str, rng) -> str:
    h, m = int(hhmm[:2]), int(hhmm[3:])
    h12 = h % 12 or 12
    if lang == "en":
        ap = "am" if h < 12 else "pm"
        base = f"{h12}" if m == 0 else rng.choice([f"{h12}.{m:02d}", f"{h12}:{m:02d}"])
        return rng.choice([f"{base}{ap}", f"{base} {ap}"])
    if lang == "zh":
        period = "早上" if h < 12 else "中午" if h < 13 else "下午" if h < 18 else "晚上"
        return f"{period}{h12}点" + ("" if m == 0 else "半" if m == 30 else f"{m}分")
    period = "pagi" if h < 12 else "tengah hari" if h < 14 else "petang" if h < 19 else "malam"
    base = f"{h12}" if m == 0 else f"{h12}.{m:02d}"
    return rng.choice([f"pukul {base} {period}", f"jam {base} {period}", f"{base} {period}"])


class Chat:
    """One group, one trip, and the helpers that make them talk."""

    def __init__(self, rng, dest_name):
        self.rng = rng
        self.dest_name = dest_name
        dest = DESTINATIONS[dest_name]
        self.airport = dest["airport"]
        self.pool = [dict(label=p[0], location=p[1], icon=p[2], slots=p[3], aliases=p[4], zh=p[5]) for p in dest["pois"]]
        rng.shuffle(self.pool)

        n_days = rng.choices([2, 3, 4, 5], weights=[2, 4, 3, 1])[0]
        start = dt.date(2026, 11, 1) + dt.timedelta(days=rng.randrange(300))
        self.dates = [start + dt.timedelta(days=i) for i in range(n_days)]
        self.n_days = n_days

        # 3-5 members, each with a home language; most groups are mixed
        group_langs = rng.choice([["en", "zh", "ms"], ["en", "zh"], ["en", "ms"], ["zh", "en", "zh"], ["ms", "en", "ms"],
                                  ["en"], ["zh"], ["ms"], ["en", "zh", "ms"]])
        self.members = []
        used = set()
        for i in range(rng.randint(3, 5)):
            lang = group_langs[i % len(group_langs)]
            name_pool = NAMES[lang] if rng.random() < 0.8 else NAMES[rng.choice(["en", "zh", "ms"])]
            name = rng.choice([n for n in name_pool if n not in used] or [n for ns in NAMES.values() for n in ns if n not in used])
            used.add(name)
            self.members.append((name, lang))
        self.group_langs = sorted(set(group_langs))

    # -- who / which language
    def speaker(self, exclude=()):
        return self.rng.choice([m for m in self.members if m[0] not in exclude])

    def lang_of(self, member):
        # people mostly use their own language but code-switch sometimes
        return member[1] if self.rng.random() < 0.82 else self.rng.choice(self.group_langs + ["en"])

    # -- phrases
    def poi_name(self, poi, lang):
        rng = self.rng
        if lang == "zh" and poi["zh"] and rng.random() < 0.7:
            return poi["zh"]
        r = rng.random()
        if r < 0.6 and poi["aliases"]:
            return rng.choice(poi["aliases"])
        return poi["label"] if rng.random() < 0.6 else poi["label"].lower()

    def day_ref(self, day, lang):
        rng, date = self.rng, self.dates[day - 1]
        opts = [f"day {day}", f"day {day}", ORDINAL[lang][day - 1], WEEKDAY_FULL[lang][date.weekday()]]
        opts.append({"en": f"{date.day} {MONTH_SHORT[date.month - 1]}", "zh": f"{date.day}号", "ms": f"{date.day}hb"}[lang])
        if day == self.n_days and self.n_days > 1:
            opts += LAST_DAY[lang]
        return rng.choice(opts)

    def when(self, day, slot, time, lang):
        d = self.day_ref(day, lang)
        part = fmt_time(time, lang, self.rng) if time else self.rng.choice(SLOT_WORDS[lang][slot])
        if lang == "zh":
            return d + part
        if lang == "en" and time:
            return self.rng.choice([f"{d} {part}", f"{d} at {part}"])
        return f"{d} {part}"

    def say(self, member, act, **kw):
        rng = self.rng
        lang = self.lang_of(member)
        fmt = {}
        for k, v in kw.items():
            if k in ("poi", "old", "new"):
                fmt[k] = self.poi_name(v, lang)
            elif k in ("day", "oldday"):
                fmt[k] = self.day_ref(v, lang)
            elif k == "time":
                fmt[k] = fmt_time(v, lang, rng)
            elif k == "when":
                fmt[k] = self.when(*v, lang)
        text = rng.choice(T[act][lang]).format(**fmt)
        ends_with_particle = text.split(" ")[-1] in ("la", "lah", "lor", "leh", "ah", "wei", "je", "kot", "weh", "lol", "haha", "ya", "tau")
        if act != "give_time" and text[-1] not in "?？!！啦吧了" and not ends_with_particle and rng.random() < 0.2:
            text += rng.choice(PARTICLES[lang])
        if lang != "zh" and rng.random() < 0.15:
            text = text[0].upper() + text[1:]
        return (member[0], text)

    def agrees(self, exclude, lo=1, hi=2):
        out, seen = [], set(exclude)
        for _ in range(self.rng.randint(lo, hi)):
            cands = [m for m in self.members if m[0] not in seen]
            if not cands:
                break
            m = self.rng.choice(cands)
            seen.add(m[0])
            out.append(self.say(m, "agree"))
        return out

    def propose(self, member, poi, day, slot, time):
        act = "propose_food" if poi["icon"] == "food" and slot in "BLD" and self.rng.random() < 0.5 else "propose"
        return self.say(member, act, poi=poi, when=(day, slot, time))

    def take(self, slot=None):
        for i, p in enumerate(self.pool):
            if slot is None or slot in p["slots"]:
                return self.pool.pop(i)
        return None


def _display(alias):
    return " ".join(w.capitalize() for w in alias.split())


def make_example(rng, dest_name):
    c = Chat(rng, dest_name)
    days = list(range(1, c.n_days + 1))
    threads = []    # (kind, messages)
    deferred = []   # (parent_index, messages) - must come after their parent thread
    unresolved_in_thread = {}
    gold_add, gold_update, gold_remove = [], [], []

    # ---- what the group has saved (about 15% of groups saved nothing)
    saved = [] if rng.random() < 0.15 else rng.sample(c.pool, min(rng.randint(4, 10), len(c.pool)))
    for poi in saved:
        # The catalog does not always use the name people would call "official",
        # so the model must copy whatever SAVED PLACES says rather than recite one.
        longer = [a for a in poi["aliases"] if len(a) >= 8 and not a.startswith("the ")]
        poi["saved_name"] = _display(rng.choice(longer)) if longer and rng.random() < 0.3 else poi["label"]
    # saved places are more likely to be what the group ends up talking about
    c.pool.sort(key=lambda p: 0 if "saved_name" in p and rng.random() < 0.8 else 1)

    def name(poi):
        return poi.get("saved_name", poi["label"])

    # ---- what is already in the plan (40% of trips: nothing yet)
    existing = []
    occupied = {d: set() for d in days}   # parts of the day already taken, per day
    if rng.random() >= 0.4:
        for d in days:
            for slot in rng.sample(SLOT_ORDER, rng.choice([0, 1, 1, 2, 3])):
                poi = c.take(slot)
                if poi is None:
                    continue
                existing.append({"poi": poi, "day": d, "slot": slot,
                                 "time": rng.choice([SLOT_DEFAULT[slot]] + SLOT_TIMES[slot])})
                occupied[d].add(slot)
    final_times = {d: {e["time"] for e in existing if e["day"] == d} for d in days}

    # ---- the chat changes some of what is already planned
    for e in existing:
        poi, r = e["poi"], rng.random()
        targets = [d for d in days if d != e["day"] and e["slot"] not in occupied[d]]
        if r < 0.12 and targets:  # move to another day
            new_day = rng.choice(targets)
            occupied[new_day].add(e["slot"])
            final_times[new_day].add(e["time"])
            q = c.speaker()
            threads.append(("plan_move", [c.say(q, "move", poi=poi, day=new_day, oldday=e["day"])] + c.agrees(exclude=[q[0]])))
            gold_update.append({"label": name(poi), "from_day": e["day"], "day": new_day, "time": e["time"]})
        elif r < 0.22:  # same day, new time
            new_time = rng.choice([t for t in SLOT_TIMES[e["slot"]] if t != e["time"]])
            final_times[e["day"]].add(new_time)
            q = c.speaker()
            threads.append(("plan_retime", [c.say(q, "change_time", poi=poi, time=new_time)] + c.agrees(exclude=[q[0]], lo=0, hi=1)))
            gold_update.append({"label": name(poi), "from_day": e["day"], "day": e["day"], "time": new_time})
        elif r < 0.32:  # dropped
            q = c.speaker()
            threads.append(("plan_remove", [c.say(q, "cancel", poi=poi)] + c.agrees(exclude=[q[0]], lo=1, hi=1)))
            gold_remove.append({"day": e["day"], "label": name(poi)})
        elif r < 0.40:  # suggested again although it is already planned -> nothing to do
            p = c.speaker()
            q = c.speaker(exclude=[p[0]])
            threads.append(("plan_repeat", [c.propose(p, poi, e["day"], e["slot"], None), c.say(q, "already_planned")]))

    def item(poi, day, time):
        return {"day": day, "time": time, "label": name(poi), "location": poi["location"], "icon": poi["icon"],
                "saved": "saved_name" in poi}

    # ---- new things the group agrees on, each reached a different way
    for day in days:
        free = [s for s in SLOT_ORDER if s not in occupied[day]]
        k = rng.choices([0, 1, 2, 3, 4], weights=[2, 3, 3, 2, 1] if existing else [0, 2, 4, 3, 2])[0]
        for slot in sorted(rng.sample(free, min(k, len(free))), key=SLOT_ORDER.index):
            poi = c.take(slot)
            if poi is None:
                continue
            occupied[day].add(slot)
            p = c.speaker()
            explicit = rng.choice(SLOT_TIMES[slot]) if rng.random() < 0.3 else None
            final_time = explicit or SLOT_DEFAULT[slot]
            r = rng.random()
            other = c.take(slot) if 0.58 <= r < 0.72 else None

            if other is not None:  # A proposed, B counter-proposed and accepted
                q = c.speaker(exclude=[p[0]])
                msgs = [c.propose(p, other, day, slot, explicit), c.say(q, "counter", old=other, new=poi)]
                msgs += c.agrees(exclude=[q[0]])
                threads.append(("replace", msgs))
            elif 0.72 <= r < 0.82 and c.n_days > 1:  # agreed for one day, moved to another later
                d0 = rng.choice([d for d in days if d != day])
                msgs = [c.propose(p, poi, d0, slot, explicit)] + c.agrees(exclude=[p[0]])
                threads.append(("move", msgs))
                q = c.speaker()
                later = [c.say(q, "move", poi=poi, day=day, oldday=d0)] + c.agrees(exclude=[q[0]])
                deferred.append((len(threads) - 1, later))
            elif 0.82 <= r < 0.90:  # agreed, then the time was changed
                msgs = [c.propose(p, poi, day, slot, explicit)] + c.agrees(exclude=[p[0]])
                threads.append(("retime", msgs))
                final_time = rng.choice([t for t in SLOT_TIMES[slot] if t != explicit])
                q = c.speaker()
                later = [c.say(q, "change_time", poi=poi, time=final_time)] + c.agrees(exclude=[q[0]], lo=0, hi=1)
                deferred.append((len(threads) - 1, later))
            elif 0.90 <= r:  # agreed, then someone asks what time
                final_time = rng.choice(SLOT_TIMES[slot])
                msgs = [c.propose(p, poi, day, slot, None)] + c.agrees(exclude=[p[0]], lo=1, hi=1)
                q = c.speaker(exclude=[p[0]])
                msgs += [c.say(q, "ask_time", poi=poi), c.say(p, "give_time", time=final_time)]
                msgs += c.agrees(exclude=[p[0]], lo=0, hi=1)
                threads.append(("asktime", msgs))
            else:  # plain proposal + agreement
                msgs = [c.propose(p, poi, day, slot, explicit)] + c.agrees(exclude=[p[0]])
                threads.append(("accept", msgs))
            gold_add.append(item(poi, day, final_time))
            final_times[day].add(final_time)

    # ---- things that must NOT be added
    for _ in range(rng.choice([0, 1, 1, 2])):  # rejected outright
        poi = c.take()
        if poi is None:
            break
        p = c.speaker()
        q = c.speaker(exclude=[p[0]])
        first = (c.say(p, "propose_nowhen", poi=poi) if rng.random() < 0.4
                 else c.propose(p, poi, rng.randint(1, c.n_days), rng.choice(poi["slots"]), None))
        threads.append(("reject", [first, c.say(q, "reject", poi=poi), c.say(p, "concede")]))

    if rng.random() < 0.4:  # agreed in the chat, then cancelled before it reached the plan
        poi = c.take()
        if poi is not None:
            p = c.speaker()
            msgs = [c.propose(p, poi, rng.randint(1, c.n_days), rng.choice(poi["slots"]), None)] + c.agrees(exclude=[p[0]])
            threads.append(("cancel", msgs))
            q = c.speaker()
            deferred.append((len(threads) - 1, [c.say(q, "cancel", poi=poi)] + c.agrees(exclude=[q[0]], lo=1, hi=1)))

    for _ in range(rng.choice([0, 0, 1, 1, 2])):  # raised but never decided
        poi = c.take()
        if poi is None:
            break
        p = c.speaker()
        q = c.speaker(exclude=[p[0]])
        first = (c.say(p, "propose_nowhen", poi=poi) if rng.random() < 0.5
                 else c.propose(p, poi, rng.randint(1, c.n_days), rng.choice(poi["slots"]), None))
        msgs = [first, c.say(q, "unsure")]
        if rng.random() < 0.6:
            msgs.append(c.say(p, "park"))
        threads.append(("unresolved", msgs))
        unresolved_in_thread[id(msgs)] = name(poi)

    if rng.random() < 0.3:  # a place is name-dropped, nobody proposes it
        poi = c.take()
        if poi is not None:
            threads.append(("mention", [c.say(c.speaker(), "mention_only", poi=poi)]))

    # ---- logistics
    if rng.random() < 0.35:
        t = rng.choice([x for x in ["14:00", "15:00", "15:30", "16:00", "13:45"] if x not in final_times[1]])
        m = c.speaker()
        threads.append(("hotel", [c.say(m, "hotel", time=t)] + c.agrees(exclude=[m[0]], lo=0, hi=1)))
        gold_add.append({"day": 1, "time": t, "label": "Hotel check-in", "location": "", "icon": "hotel", "saved": False})
    if c.airport and rng.random() < 0.3:
        t = rng.choice([x for x in ["11:00", "13:00", "15:00", "16:30", "18:00", "10:15"] if x not in final_times[c.n_days]])
        m = c.speaker()
        threads.append(("airport", [c.say(m, "airport", time=t)] + c.agrees(exclude=[m[0]], lo=0, hi=1)))
        gold_add.append({"day": c.n_days, "time": t, "label": "Depart for airport", "location": c.airport,
                         "icon": "flight", "saved": False})

    for _ in range(rng.randint(2, 6)):
        threads.append(("noise", [c.say(c.speaker(), "noise")]))

    # ---- order the conversation: shuffle topics, later changes come later
    order = list(range(len(threads)))
    rng.shuffle(order)
    sequence = [threads[i][1] for i in order]
    for parent, later in deferred:
        pos = next(i for i, msgs in enumerate(sequence) if msgs is threads[parent][1])
        sequence.insert(rng.randint(pos + 1, len(sequence)), later)

    messages = [{"sender": s, "text": t} for msgs in sequence for s, t in msgs]
    gold = {
        "add": sorted(gold_add, key=lambda it: (it["day"], it["time"], it["label"])),
        "update": sorted(gold_update, key=lambda u: (u["from_day"], u["label"])),
        "remove": sorted(gold_remove, key=lambda r: (r["day"], r["label"])),
        "unresolved": [unresolved_in_thread[id(msgs)] for msgs in sequence if id(msgs) in unresolved_in_thread],
    }
    rng.shuffle(saved)
    trip = {
        "destination": dest_name,
        "days": [{"day": i + 1, "weekday": WEEKDAY_SHORT[d.weekday()], "date": f"{d.day} {MONTH_SHORT[d.month - 1]}"}
                 for i, d in enumerate(c.dates)],
        "members": [m[0] for m in c.members],
        "saved": [{"name": p["saved_name"], "location": p["location"],
                   "type": "restaurant" if p["icon"] == "food" else "attraction"} for p in saved],
        "plan": {d: sorted(({"time": e["time"], "label": name(e["poi"]), "location": e["poi"]["location"],
                             "icon": e["poi"]["icon"]} for e in existing if e["day"] == d),
                           key=lambda it: (it["time"], it["label"])) for d in days},
    }
    return {"trip": trip, "messages": messages, "gold": gold,
            "meta": {"destination": dest_name, "kinds": sorted({threads[i][0] for i in order}), "langs": c.group_langs}}


def write_split(path, examples):
    with open(path, "w", encoding="utf-8") as f:
        for ex in examples:
            row = to_gemini_example(build_user_prompt(ex["trip"], ex["messages"]), dump_answer(ex["gold"]))
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--train", type=int, default=600)
    ap.add_argument("--val", type=int, default=60)
    ap.add_argument("--test", type=int, default=60, help="size of EACH test split")
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--out", default=str(Path(__file__).parent / "data"))
    args = ap.parse_args()

    rng = random.Random(args.seed)
    seen = sorted(d for d in DESTINATIONS if d not in HELD_OUT)
    unseen = sorted(HELD_OUT)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    def batch(n, dests):
        return [make_example(rng, dests[i % len(dests)]) for i in range(n)]

    splits = {"train": batch(args.train, seen), "val": batch(args.val, seen),
              "test_seen": batch(args.test, seen), "test_unseen": batch(args.test, unseen)}

    # no test/val conversation may also appear in train
    train_prompts = {build_user_prompt(e["trip"], e["messages"]) for e in splits["train"]}
    for name in ("val", "test_seen", "test_unseen"):
        assert not any(build_user_prompt(e["trip"], e["messages"]) in train_prompts for e in splits[name]), name

    for name, examples in splits.items():
        write_split(out / f"{name}.jsonl", examples)
        n_msgs = sum(len(e["messages"]) for e in examples) / len(examples)
        avg = lambda key: sum(len(e["gold"][key]) for e in examples) / len(examples)
        print(f"{name:12s} {len(examples):4d} examples | avg {n_msgs:4.1f} messages | "
              f"add {avg('add'):.1f}  update {avg('update'):.2f}  remove {avg('remove'):.2f}  unresolved {avg('unresolved'):.2f}")

    with open(out / "preview.txt", "w", encoding="utf-8") as f:
        for ex in splits["train"][:4] + splits["test_unseen"][:2]:
            f.write(build_user_prompt(ex["trip"], ex["messages"]) + "\n\n>>> EXPECTED\n")
            f.write(json.dumps(ex["gold"], ensure_ascii=False, indent=1) + "\n\n" + "=" * 70 + "\n\n")
    print(f"written to {out}")


if __name__ == "__main__":
    main()
