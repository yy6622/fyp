"""Template-based synthetic travel group chats (English / Chinese / Malay, mixed).

Built "backwards": first a hidden trip plan is sampled (destination, dates,
budget, hotels, attractions, transport, who prefers what), then each topic
is acted out as chat messages (proposal -> agree / reject / hesitate /
finalise), interleaved with small talk. Because the plan is known, every
message gets a gold label, a gold stance and a gold topic, and every topic
gets a gold final status computed with the group-decision rule in
decision_rule() — the same definition the report uses.

Usage:  python generate_template_data.py --n 260 --seed 2026
Output: data/template.jsonl
"""

import argparse
import random

from common import DATA, SINGLE_VALUE, write_jsonl
from kb import CITY_NAMES, DESTINATIONS, HOTEL_BRANDS, MEMBER_NAMES, TRANSPORT

# --------------------------------------------------------------------------
# Phrase banks. {r} = how the speaker refers to the topic value.
# --------------------------------------------------------------------------

PROPOSE = {
    "ATTRACTION": {
        "en": ["Let's go {r}", "We should visit {r}", "{r} looks nice, want to go?", "I really want to see {r}",
               "how about {r} on day {d}?", "Can we add {r}?", "must go {r} leh", "Heard {r} is worth it, let's go",
               "{r} anyone?", "Put {r} in the plan pls", "I'm thinking {r} for day {d}", "let's do {r} in the {part}"],
        "zh": ["我们去{r}吧", "{r}一定要去", "要不要去{r}？", "我想去{r}", "第{d}天去{r}怎么样", "{r}好像不错欸，去吗",
               "加{r}进去好不好", "{r}听说很值得去"],
        "ms": ["Jom pergi {r}", "Kita kena pergi {r}", "{r} best tau, nak pergi tak?", "Aku nak sangat pergi {r}",
               "Hari {d} pergi {r} ok tak?", "Masukkan {r} dalam plan"],
    },
    "FOOD": {
        "en": ["Let's eat at {r}", "{r} for {meal}?", "We must try {r}", "I want to makan at {r}", "heard {r} is super good, go?"],
        "zh": ["我们去{r}吃", "{r}一定要吃", "{meal_zh}去{r}吃怎样", "听说{r}很好吃"],
        "ms": ["Jom makan kat {r}", "{r} sedap gila, nak try?", "Makan {r} jom"],
    },
    "DESTINATION": {
        "en": ["Let's go {r} this year!", "How about {r}?", "I vote {r}", "{r} trip anyone?", "What about {r} for this trip?",
               "{r} lah, been wanting to go"],
        "zh": ["去{r}好不好", "我想去{r}", "今年去{r}吧", "{r}怎么样？"],
        "ms": ["Jom pergi {r}", "Apa kata kita pergi {r}?", "{r} best ni"],
    },
    "BUDGET": {
        "en": ["My budget is around {r}", "{r} should be enough right?", "let's keep it under {r}", "How about budget {r}?",
               "I can only afford {r} max", "I think {r} is reasonable"],
        "zh": ["预算{r}可以吗？", "我预算大概{r}", "不要超过{r}", "{r}应该够吧"],
        "ms": ["Budget aku dalam {r}", "{r} cukup kot?", "Jangan lebih {r} la"],
    },
    "DATE": {
        "en": ["Let's go {r}", "How about {r}?", "{r} ok for everyone?", "I can only take leave {r}", "{r} works for me, you guys?"],
        "zh": ["{r}去怎样？", "我们{r}出发吧", "{r}大家可以吗", "我只能{r}请假"],
        "ms": ["{r} boleh tak?", "Kita pergi {r} la", "Aku free {r}"],
    },
    "TRANSPORT": {
        "en": ["We can {r}", "I think we should {r}", "easier to {r}", "let's {r}, cheaper", "how about we {r}?"],
        "zh": ["我们{r}就好", "我觉得{r}比较方便", "{r}吧，比较便宜", "要不要{r}？"],
        "ms": ["Kita {r} je", "Senang {r}", "Apa kata kita {r}?"],
    },
    "ACCOMMODATION": {
        "en": ["How about {r}? RM{price} per night", "I found {r}, reviews are good", "{r} is cheaper, RM{price}/night",
               "let's book {r}?", "This one looks ok: {r}, RM{price} a night"],
        "zh": ["我看了{r}，评价不错", "{r}比较便宜，一晚RM{price}", "住{r}怎样？", "{r}一晚才RM{price}"],
        "ms": ["{r} murah gila, RM{price} semalam", "Apa kata stay kat {r}?", "Aku jumpa {r}, review ok"],
    },
}

# Counter-proposal that rejects the previous value in the same breath.
COUNTER = {
    "BUDGET": {"en": ["{old} too much la, {r} can?", "hmm {old} is a bit much for me, {r}?"],
               "zh": ["{old}太多了，{r}可以吗？", "{old}有点贵，{r}吧"],
               "ms": ["{old} mahal sangat, {r} boleh?"]},
    "DATE": {"en": ["{old} cannot for me, {r}?", "I'm busy {old}, how about {r}"],
             "zh": ["{old}我不行，{r}呢？", "{old}没空，改{r}好吗"],
             "ms": ["{old} aku tak boleh, {r}?"]},
    "ACCOMMODATION": {"en": ["{old} looks old leh, {r} better?", "nah {old} too far, how about {r}? RM{price}"],
                      "zh": ["{old}太远了，{r}好一点", "{old}评价不好，换{r}吧"],
                      "ms": ["{old} jauh la, {r} lagi ok"]},
    "DESTINATION": {"en": ["{old} went before already, {r}?", "nah {old} too expensive, {r} better"],
                    "zh": ["{old}去过了，{r}吧", "{old}太贵，去{r}好了"],
                    "ms": ["{old} dah pergi, {r} pulak?"]},
    "TRANSPORT": {"en": ["{old} so troublesome, let's {r}"], "zh": ["{old}太麻烦，{r}吧"], "ms": ["{old} leceh, {r} je"]},
}

AGREE = {
    "en": ["ok", "agree", "sure, I'm in", "sounds good", "+1", "can can", "ok lor", "yes!! let's do it", "I'm ok with that",
           "fine by me", "👍", "deal", "yesss", "ok no problem", "same, ok"],
    "zh": ["好", "可以", "同意", "好啊", "没问题", "我ok", "赞成", "可以啊", "行"],
    "ms": ["ok setuju", "boleh", "on!", "set", "aku ok je", "boleh je", "setuju"],
}
AGREE_REF = {
    "en": ["ok {r} sounds good", "agree with {r}", "{r} ok for me", "I'm in for {r}", "+1 for {r}", "{r} can"],
    "zh": ["{r}可以", "就{r}吧", "{r}我同意", "{r}好啊"],
    "ms": ["{r} boleh", "setuju {r}", "{r} on"],
}
FINALIZE_PLAIN = {
    "en": ["ok confirmed then, {r}", "settled, {r} it is", "final: {r}", "so {r} confirm ya", "ok we go with {r}"],
    "zh": ["那就这样定了，{r}", "定了！{r}", "{r}就这样决定"],
    "ms": ["Ok confirm {r}", "Settle, {r}"],
}
FINALIZE = {
    "en": ["ok confirmed then, {r}", "settled, {r} it is", "final: {r}", "Done, booking {r} now", "ok I'll book {r} tonight",
           "so {r} confirm ya"],
    "zh": ["那就这样定了，{r}", "定了！{r}", "我去订{r}了", "{r}就这样决定"],
    "ms": ["Ok confirm {r}", "Settle, {r}", "Aku book {r} sekarang"],
}
REJECT = {
    "en": ["no la, {r} too expensive", "not keen on {r}", "I don't think {r} is a good idea", "skip {r} lah",
           "{r}? no thanks", "hmm I'd rather not do {r}", "pass on {r}", "{r} not worth it la"],
    "zh": ["{r}不要啦", "{r}太贵了", "不想去{r}", "我觉得{r}不太好", "{r}算了吧"],
    "ms": ["Tak nak lah {r}", "{r} mahal sangat", "skip {r} je la", "{r} tak best"],
}
REJECT_SHORT = {"en": ["nah", "no la", "don't want"], "zh": ["不要", "不好"], "ms": ["tak nak", "tak payah"]}
WITHDRAW = {
    "en": ["ok fine, never mind then", "ok skip it", "ok la forget {r}"],
    "zh": ["好吧那算了", "那{r}就不去了"],
    "ms": ["ok la takpe, cancel", "takpe la skip {r}"],
}
DEFER = {
    "en": ["hmm let me think", "not sure yet", "maybe? need to check my leave first", "let's decide later",
           "depends on the price", "can we discuss {r} later?", "hmm {r} ah... not sure"],
    "zh": ["我再想想", "还不确定", "看情况吧", "之后再决定", "{r}再看看"],
    "ms": ["Tengok dulu", "tak pasti lagi", "nanti kita decide", "{r} nanti la fikir"],
}
INFO = {
    "ATTRACTION": {"en": ["{r} opens at 9am btw", "{r} entrance is free", "{r} is quite far from the city leh",
                          "need to book {r} tickets online"],
                   "zh": ["{r}门票好像要100多", "{r}早上比较少人", "{r}要提前订票"],
                   "ms": ["{r} tutup hari Isnin", "Tiket {r} kena beli online"]},
    "ACCOMMODATION": {"en": ["check-in is 3pm", "breakfast included for that one", "the room fits 4 pax"],
                      "zh": ["三点才能check in", "含早餐", "一间房可以住四个人"],
                      "ms": ["check in pukul 3", "termasuk sarapan"]},
    "TRANSPORT": {"en": ["the metro card is around RM20", "Grab there quite cheap", "parking is expensive there"],
                  "zh": ["地铁卡要先买吗", "那边Grab很便宜", "停车很贵"],
                  "ms": ["kad MRT dalam RM20", "Grab kat sana murah"]},
    "BUDGET": {"en": ["flight alone is about RM{x}", "hotel will take like RM{x} each", "what's our budget ah?"],
               "zh": ["机票大概RM{x}", "预算多少？", "住宿一个人大概RM{x}"],
               "ms": ["tiket flight dalam RM{x}", "budget berapa ni?"]},
    "DATE": {"en": ["when are we going ah?", "how many days are we going?", "I need to apply leave early"],
             "zh": ["什么时候去？", "去几天？", "我要早点请假"],
             "ms": ["bila nak pergi?", "berapa hari?"]},
    "DESTINATION": {"en": ["{area} area is more convenient", "is {area} near the city centre?"],
                    "zh": ["{area}那边比较方便", "{area}离市中心近吗"],
                    "ms": ["kawasan {area} lagi senang"]},
}
# (en, zh, ms, canonical summary text)
PREFERENCES = [
    ("I prefer less crowded places", "我比较喜欢人少的地方", "Aku suka tempat tak ramai orang", "prefers less crowded places"),
    ("I can't eat spicy food ah", "我不太能吃辣", "Aku tak tahan pedas", "can't eat spicy food"),
    ("I need halal food ya", "我要清真食物", "Aku nak makanan halal", "needs halal food"),
    ("I'm vegetarian btw", "我吃素", "Aku vegetarian", "is vegetarian"),
    ("can we not wake up too early, no 6am start pls", "不要太早起床啦", "Jangan bangun awal sangat", "doesn't want early starts"),
    ("I want more shopping time", "我想要多一点购物时间", "Aku nak masa shopping lebih", "wants more shopping time"),
    ("can we not walk too much, my knee pain", "不要走太多路，我膝盖痛", "Jangan jalan banyak sangat, lutut aku sakit", "can't walk too much"),
    ("I prefer cheaper options, saving money", "我想便宜一点的", "Aku nak yang murah je", "prefers cheaper options"),
    ("I love nature stuff more than malls", "我比较喜欢大自然", "Aku lagi suka alam semula jadi", "prefers nature over malls"),
    ("I want to try local street food", "我想吃当地小吃", "Aku nak try street food", "wants to try local street food"),
    ("I prefer staying in one hotel, don't want to keep moving", "我不想一直换酒店", "Aku tak nak tukar hotel banyak kali", "wants to stay in one hotel"),
    ("I get carsick easily", "我容易晕车", "Aku senang mabuk kereta", "gets carsick easily"),
    ("I want a chill trip, not too packed", "行程不要太赶", "Nak trip santai je", "wants a relaxed schedule"),
    ("I like taking photos so want nice spots", "我想去拍照好看的地方", "Aku nak tempat cantik untuk gambar", "wants photogenic spots"),
]
OTHER = {
    "en": ["haha", "lol", "😂😂", "brb", "ok I'm back", "omg can't wait", "anyone watched the game last night?",
           "my cat just knocked over my coffee", "eh sorry just saw the messages", "so tired today", "wahh",
           "hahaha true", "who's free for dinner tonight", "my boss is so annoying today", "lunch time!!", "same lol",
           "gonna sleep soon", "hello everyone", "this group so quiet", "happy friday guys",
           # greetings / goodbyes / thanks / fillers that are not about the trip
           "hi all", "hi everyone", "hiya", "hi hi", "hello hello", "helloooo", "hey there", "heya", "yo guys",
           "morning all", "good morning everyone", "morninggg", "gd morning", "afternoon guys", "evening all",
           "goodnight guys", "night night", "gn all", "sleep first", "bye bye", "bye all", "cya", "see you guys",
           "later guys", "talk later", "thanks guys", "thank you so much", "thanks a lot", "many thanks", "thx guys",
           "tq all", "appreciate it", "welcome", "np", "no worries", "sorry sorry", "my bad", "oops", "lolol",
           "hahah", "hehehe", "lmaooo", "rofl", "😂", "😆", "🤣🤣", "😅", "🙈", "👋👋", "😴", "🥲", "eh?",
           "huh?", "wait what", "really?", "for real", "no way lol", "so true", "exactly", "hmm ok", "i see",
           "oh i see", "ohh", "ahh ok", "test test", "testing", "can see my msg?", "anybody here", "hello? anyone",
           "ping", "just checking", "i'm at work now", "in a meeting", "driving now", "eating now", "just reached office",
           "going home", "stuck in traffic", "my phone battery low", "internet down", "rain so heavy", "so hot today",
           "weather crazy", "monday blues", "tgif", "weekend yay", "happy bday!!", "congrats bro", "well done",
           "get well soon ya", "take care guys", "miss you all", "long time no see", "wrong group lol",
           "sorry wrong chat", "who's online", "anyone awake", "bored", "i'm starving", "what you guys doing",
           "watching netflix", "gym later", "exam tomorrow 😭", "submitted my assignment", "nice pic", "so cute",
           "look at this meme", "lol this video", "omg", "wtf", "aiyo", "alamak", "walao", "aiya", "sian"],
    "zh": ["哈哈哈", "笑死", "好累啊今天", "我刚下班", "等下回你们", "大家早安", "期待！", "我先去洗澡", "今天好热", "你们吃饭了吗",
           "大家早", "早啊", "早上好呀", "哈喽", "嗨嗨", "你们好", "晚安大家", "睡了", "我先睡了", "拜拜啦", "再见",
           "谢谢大家", "感谢", "多谢", "辛苦了", "不客气", "没事", "抱歉", "不好意思", "哈哈", "呵呵", "嘻嘻", "笑死人",
           "😂", "在吗？", "有人在吗", "人呢", "我在开车", "我在上班", "刚下课", "好饿", "好困", "好无聊", "下大雨了",
           "塞车了", "手机快没电", "网络很慢", "生日快乐！", "恭喜恭喜", "加油", "保重", "发错了", "测试一下", "收到收到",
           "看到了", "真的假的", "天啊", "是哦", "对啊", "哇", "好可爱", "这张照片好看", "周末快乐"],
    "ms": ["haha", "wehh", "penat gila hari ni", "baru habis kerja", "sape nak makan lunch skrg", "selamat pagi semua",
           "tak sabar dah", "jap aku drive",
           "hai korang", "helo semua", "pagi semua", "selamat petang", "selamat malam semua", "salam semua",
           "waalaikumsalam", "bye semua", "jumpa nanti", "terima kasih semua", "tq semua", "sama-sama", "maaf lambat reply",
           "sorry baru nampak msg", "aku kat ofis", "tengah drive", "otw balik", "dah sampai", "lapar gila", "mengantuk",
           "bosan", "hujan la", "panas gila", "jem teruk", "bateri nak habis", "selamat hari jadi!", "tahniah!",
           "jaga diri", "salah group", "ada orang tak?", "hahaha", "alamak", "aduh", "mantap",
           "best gila video ni", "comel nya"],
}
PARTICLES = ["", "", "", " lah", " leh", " ah", " la", " ya"]
MEALS = [("lunch", "午餐"), ("dinner", "晚餐"), ("breakfast", "早餐"), ("supper", "宵夜")]
PARTS = ["morning", "afternoon", "evening"]
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
MONTHS_MS = ["Januari", "Februari", "Mac", "April", "Mei", "Jun", "Julai", "Ogos", "September", "Oktober", "November", "Disember"]
ZH_NUM = {1000: "一千", 1500: "一千五", 2000: "两千", 2500: "两千五", 3000: "三千", 3500: "三千五", 4000: "四千",
          4500: "四千五", 5000: "五千", 6000: "六千", 8000: "八千", 10000: "一万", 12000: "一万二", 15000: "一万五"}


# --------------------------------------------------------------------------
# Value realisation
# --------------------------------------------------------------------------

def budget_value(rng):
    amount = rng.choice([1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000])
    basis = "per_person" if rng.random() < 0.8 else "total"
    if basis == "total":
        amount = amount * rng.choice([3, 4])
        amount = min(ZH_NUM, key=lambda k: abs(k - amount))
    return amount, basis


def budget_phrases(rng, amount, basis):
    k = f"{amount / 1000:g}k"
    if basis == "per_person":
        en = rng.choice([f"RM{amount} per person", f"RM{amount:,} each", f"{k} per pax", f"RM{k} per person", f"RM {amount} per head"])
        zh = rng.choice([f"每人{ZH_NUM.get(amount, amount)}", f"每人RM{amount}", f"RM{amount}一个人", f"一个人{ZH_NUM.get(amount, amount)}块"])
        ms = rng.choice([f"RM{amount} seorang", f"{k} sorang", f"RM{amount} per orang"])
    else:
        en = rng.choice([f"RM{amount} total", f"RM{amount:,} for the whole group", f"{k} altogether"])
        zh = rng.choice([f"总共RM{amount}", f"全部{ZH_NUM.get(amount, amount)}", f"大家一共RM{amount}"])
        ms = rng.choice([f"RM{amount} semua sekali", f"total RM{amount}"])
    short = f"RM{amount}"
    return {"en": en, "zh": zh, "ms": ms, "short": short}


def date_phrases(rng):
    m = rng.randrange(12)
    if rng.random() < 0.65:
        start = rng.randint(1, 23)
        end = start + rng.randint(2, 5)
        en = rng.choice([f"{start}-{end} {MONTHS[m]}", f"{MONTHS[m]} {start} to {end}", f"{start} to {end} {MONTHS[m]}"])
        zh = f"{m + 1}月{start}号到{end}号"
        ms = f"{start} hingga {end} {MONTHS_MS[m]}"
        canon = f"{start}-{end} {MONTHS[m]}"
    else:
        which = rng.choice(["early", "mid", "end"])
        en = rng.choice([f"{which} {MONTHS[m]}", f"{which} of {MONTHS[m]}"]) if which != "mid" else f"mid {MONTHS[m]}"
        zh = {"early": f"{m + 1}月初", "mid": f"{m + 1}月中", "end": f"{m + 1}月底"}[which]
        ms = {"early": f"awal {MONTHS_MS[m]}", "mid": f"pertengahan {MONTHS_MS[m]}", "end": f"hujung {MONTHS_MS[m]}"}[which]
        canon = f"{which} {MONTHS[m]}"
    return {"en": en, "zh": zh, "ms": ms, "short": en, "canon": canon}


def poi_phrases(rng, poi):
    label, _loc, icon, _slots, aliases, zh = poi
    en = rng.choice(aliases + [label])
    return {"en": en, "zh": zh or en, "ms": rng.choice(aliases + [label]), "short": rng.choice(aliases), "canon": label,
            "food": icon == "food"}


# --------------------------------------------------------------------------
# Conversation builder
# --------------------------------------------------------------------------

class Conv:
    def __init__(self, rng, conv_id, destination):
        self.rng = rng
        self.conv_id = conv_id
        self.destination = destination
        n = rng.choices([3, 4, 5], weights=[4, 4, 2])[0]
        self.members = rng.sample(MEMBER_NAMES, n)
        # Each member has a habit: mostly English, Chinese, Malay, or code-mixing.
        self.lang = {m: rng.choices(["en", "zh", "ms", "mix"], weights=[4, 3, 1.5, 3])[0] for m in self.members}
        self.messages = []
        self.topics = []

    def speak_lang(self, who):
        lang = self.lang[who]
        if lang == "mix":
            return self.rng.choice(["en", "en", "zh", "ms"])
        if self.rng.random() < 0.12:  # everybody code-switches sometimes
            return self.rng.choice(["en", "zh", "ms"])
        return lang

    def style(self, text, lang):
        rng = self.rng
        if lang == "en" and rng.random() < 0.3 and not text.endswith(("?", "!")):
            text += rng.choice(PARTICLES)
        if rng.random() < 0.25:
            text = text.lower()
        if rng.random() < 0.08:
            text += rng.choice([" 😊", " 🤔", " !!", " haha", " 😅", "~"])
        return text

    def new_topic(self, category, value):
        t = {"id": f"t{len(self.topics) + 1}", "category": category, "value": value, "proposal": None, "status": None,
             "_proposer": None, "_events": []}
        self.topics.append(t)
        return t


def fill(template, rng, ref, lang, extra):
    return template.format(r=ref[lang] if isinstance(ref, dict) else ref, **extra)


def topic_events(conv, topic, ref, target, proposer, counter_of=None, counter_ref=None, extra=None):
    """Messages for one topic. Each event: (speaker, text_now, text_late, label, stance, rejects).
    text_late is the explicit wording used when the message ends up separated from
    its proposal by other messages."""
    rng = conv.rng
    cat = topic["category"]
    extra = dict(extra or {})
    extra.setdefault("d", rng.randint(1, 4))
    extra.setdefault("part", rng.choice(PARTS))
    meal = rng.choice(MEALS)
    extra.setdefault("meal", meal[0])
    extra.setdefault("meal_zh", meal[1])
    extra.setdefault("price", rng.choice([120, 150, 180, 200, 250, 280, 350, 420]))
    events = []
    others = [m for m in conv.members if m != proposer]
    rng.shuffle(others)
    n = len(conv.members)

    lang = conv.speak_lang(proposer)
    if counter_of is not None and cat in COUNTER and rng.random() < 0.7:
        tpl = rng.choice(COUNTER[cat][lang])
        text = tpl.format(r=ref[lang], old=counter_ref[lang], **extra)
        rejects = [counter_of["id"]]
    else:
        bank = PROPOSE["FOOD"] if (cat == "ATTRACTION" and ref.get("food") and rng.random() < 0.7) else PROPOSE[cat]
        text = fill(rng.choice(bank[lang]), rng, ref, lang, extra)
        rejects = []
    events.append((proposer, conv.style(text, lang), None, cat, "propose", rejects))

    def reply(who, kind):
        lg = conv.speak_lang(who)
        refshort = ref["short"] if lg != "zh" else ref["zh"]
        if kind == "agree":
            now = rng.choice(AGREE[lg]) if rng.random() < 0.6 else rng.choice(AGREE_REF[lg]).format(r=refshort)
            late = rng.choice(AGREE_REF[lg]).format(r=refshort)
        elif kind == "reject":
            now = rng.choice(REJECT[lg]).format(r=refshort) if rng.random() < 0.75 else rng.choice(REJECT_SHORT[lg])
            late = rng.choice(REJECT[lg]).format(r=refshort)
        elif kind == "withdraw":
            now = rng.choice(WITHDRAW[lg]).format(r=refshort)
            late = now if "{r}" in now else now + f" ({refshort})"
            kind = "reject"
        elif kind == "finalize":
            bank = FINALIZE if cat in ("ACCOMMODATION", "ATTRACTION", "TRANSPORT") else FINALIZE_PLAIN
            now = late = rng.choice(bank[lg]).format(r=refshort)
        elif kind == "defer":
            now = rng.choice(DEFER[lg]).format(r=refshort)
            late = rng.choice([t for t in DEFER[lg] if "{r}" in t] or DEFER[lg]).format(r=refshort)
        else:
            raise ValueError(kind)
        return (who, conv.style(now, lg), conv.style(late, lg), "DECISION", kind, [])

    if rng.random() < 0.25 and cat in INFO:
        who = rng.choice(conv.members)
        lg = conv.speak_lang(who)
        tpl = rng.choice(INFO[cat][lg])
        if "{r}" in tpl or "{area}" in tpl or "{x}" in tpl or "?" not in tpl:
            txt = tpl.format(r=ref["short"] if lg != "zh" else ref["zh"], area=extra.get("area", ""), x=rng.choice([300, 500, 800, 1200]))
            events.append((who, conv.style(txt, lg), None, cat, "info", []))

    majority = n // 2 + 1  # supporters (incl. proposer) needed for a plain majority
    if target == "confirmed":
        if rng.random() < 0.55:
            for who in others[: majority - 1 + rng.randint(0, max(0, len(others) - (majority - 1)))]:
                events.append(reply(who, "agree"))
            if rng.random() < 0.3:
                events.append(reply(rng.choice(conv.members), "finalize"))
        else:
            for who in others[: rng.randint(0, 1)]:
                events.append(reply(who, "agree"))
            events.append(reply(rng.choice(conv.members), "finalize"))
    elif target == "rejected":
        k = rng.randint(1, min(2, len(others)))
        for who in others[:k]:
            events.append(reply(who, "reject"))
        if rng.random() < 0.4:
            events.append(reply(proposer, "withdraw"))
    elif target == "pending":
        mode = rng.random()
        if mode < 0.45:
            for who in others[: rng.randint(1, 2)]:
                events.append(reply(who, "defer"))
        elif mode < 0.75 and len(others) >= 2:
            events.append(reply(others[0], "agree"))
            events.append(reply(others[1], "reject"))
        else:
            # one supporter is not a majority (n >= 4) -> still pending
            if n >= 4:
                events.append(reply(others[0], "agree"))
            events.append(reply(others[-1], "defer"))
    elif target == "superseded":
        # the counter-proposal does the rejecting; maybe one person liked it first
        if rng.random() < 0.4:
            events.append(reply(others[0], "agree"))
    return events


def decision_rule(topic, stances, n_members, superseded):
    """Gold definition of a group decision (the summariser uses the same rule):
    a proposal nobody argues against is agreed ("silence is consent").

    stances: list of (speaker, stance) in chat order for this topic, where the
    proposer's own proposal counts as 'agree'."""
    latest = {}
    finalized = False
    for who, st in stances:
        if st in ("agree", "finalize", "propose"):
            latest[who] = "agree"
        elif st == "reject":
            latest[who] = "reject"
        elif st == "defer":
            latest[who] = "defer"
        if st == "finalize":
            finalized = True
    support = sum(1 for v in latest.values() if v == "agree")
    oppose = sum(1 for v in latest.values() if v == "reject")
    hesitant = sum(1 for v in latest.values() if v == "defer")
    # "Silence is consent": a proposal nobody argues against is agreed.
    if superseded:
        return "rejected"
    if oppose and oppose >= support + hesitant:
        return "rejected"       # objections outweigh everyone who backed or is still considering it
    if oppose:
        return "pending"        # contested: someone objected, more people support it
    if finalized:
        return "confirmed"
    if hesitant and support <= 1:
        return "pending"        # the only reactions are "let me think" - nobody else backed it
    return "confirmed"


def build_conversation(rng, conv_id, destination):
    conv = Conv(rng, conv_id, destination)
    pois = DESTINATIONS[destination]["pois"]
    city = CITY_NAMES[destination]
    blocks = []  # list of (topic, events)

    def plan_chain(category, values, final_target):
        """1-3 proposals in a single-value category; earlier ones are rejected or superseded."""
        prev, prev_ref = None, None
        for i, (value, ref, extra) in enumerate(values):
            last = i == len(values) - 1
            target = final_target if last else rng.choice(["rejected", "superseded"])
            t = conv.new_topic(category, value)
            proposer = rng.choice(conv.members)
            ev = topic_events(conv, t, ref, target if target != "superseded" else "superseded", proposer,
                              counter_of=prev if i > 0 else None, counter_ref=prev_ref, extra=extra)
            t["_proposer"] = proposer
            blocks.append((t, ev))
            prev, prev_ref = t, ref

    # Destination
    if rng.random() < 0.75:
        vals = []
        if rng.random() < 0.35:
            alt = rng.choice([d for d in CITY_NAMES if d != destination])
            a = CITY_NAMES[alt]
            vals.append((a[0], {"en": a[0], "zh": a[1], "ms": a[2], "short": a[0]}, {}))
        vals.append((city[0], {"en": city[0], "zh": city[1], "ms": city[2], "short": city[0]}, {}))
        plan_chain("DESTINATION", vals, rng.choices(["confirmed", "pending"], [0.85, 0.15])[0])
    # Dates
    if rng.random() < 0.8:
        vals = []
        for _ in range(rng.choices([1, 2], [0.7, 0.3])[0]):
            d = date_phrases(rng)
            vals.append((d["canon"], d, {}))
        plan_chain("DATE", vals, rng.choices(["confirmed", "pending"], [0.65, 0.35])[0])
    # Budget
    if rng.random() < 0.8:
        vals = []
        for _ in range(rng.choices([1, 2], [0.65, 0.35])[0]):
            amount, basis = budget_value(rng)
            b = budget_phrases(rng, amount, basis)
            vals.append(({"amount": amount, "basis": basis}, b, {}))
        plan_chain("BUDGET", vals, rng.choices(["confirmed", "pending"], [0.7, 0.3])[0])
    # Accommodation
    if rng.random() < 0.75:
        areas = sorted({p[1] for p in pois})
        vals = []
        for brand in rng.sample(HOTEL_BRANDS, rng.choices([1, 2, 3], [0.5, 0.35, 0.15])[0]):
            area = rng.choice(areas)
            en, zh = brand[0].format(area=area), brand[1].format(area=area)
            short = en.replace("an Airbnb near", "the Airbnb").replace("a homestay in", "the homestay").replace("a capsule hotel in", "the capsule hotel")
            vals.append((en, {"en": en, "zh": zh, "ms": en, "short": short}, {"area": area}))
        plan_chain("ACCOMMODATION", vals, rng.choices(["confirmed", "pending"], [0.6, 0.4])[0])
    # Attractions (independent: many can be confirmed)
    for poi in rng.sample(pois, rng.randint(2, min(6, len(pois)))):
        t = conv.new_topic("ATTRACTION", poi[0])
        proposer = rng.choice(conv.members)
        t["_proposer"] = proposer
        target = rng.choices(["confirmed", "rejected", "pending"], [0.5, 0.2, 0.3])[0]
        blocks.append((t, topic_events(conv, t, poi_phrases(rng, poi), target, proposer)))
    # Transport
    if rng.random() < 0.7:
        tr = rng.sample(TRANSPORT, rng.choices([1, 2], [0.7, 0.3])[0])
        for i, (en, zh, ms, short) in enumerate(tr):
            t = conv.new_topic("TRANSPORT", short)
            proposer = rng.choice(conv.members)
            t["_proposer"] = proposer
            target = rng.choices(["confirmed", "rejected", "pending"], [0.5, 0.2, 0.3])[0]
            blocks.append((t, topic_events(conv, t, {"en": en, "zh": zh, "ms": ms, "short": short}, target, proposer)))

    # Destination first, then a loosely shuffled order for the rest, but a
    # chain (counter-proposals) keeps its own order.
    head = [b for b in blocks if b[0]["category"] == "DESTINATION"]
    rest = [b for b in blocks if b[0]["category"] != "DESTINATION"]
    groups = {}
    for b in rest:
        key = b[0]["category"] if b[0]["category"] in SINGLE_VALUE else b[0]["id"]
        groups.setdefault(key, []).append(b)
    group_list = list(groups.values())
    rng.shuffle(group_list)
    ordered = head + [b for g in group_list for b in g]

    # Emit: proposals in order; each reaction either right away or delayed
    # until after the next proposal (then it uses the explicit wording).
    stream = []          # (speaker, text, label, topic_id, stance, rejects)
    delayed = []
    for oi, (t, events) in enumerate(ordered):
        first = events[0]
        stream.append((first[0], first[1], first[3], t["id"], first[4], first[5]))
        flush = delayed
        delayed = []
        for ev in events[1:]:
            if ev[4] in ("agree", "reject", "defer") and ev[2] and rng.random() < 0.18 and oi < len(ordered) - 1:
                delayed.append((ev[0], ev[2], ev[3], t["id"], ev[4], ev[5]))
            else:
                text = ev[2] if (ev[2] and rng.random() < 0.15) else ev[1]
                stream.append((ev[0], text, ev[3], t["id"], ev[4], ev[5]))
        stream.extend(flush)
    stream.extend(delayed)

    # Preferences and small talk sprinkled through the chat.
    prefs = rng.sample(PREFERENCES, rng.randint(1, min(4, len(conv.members))))
    pref_speakers = rng.sample(conv.members, len(prefs))
    for (en, zh, ms, canon), who in zip(prefs, pref_speakers):
        lg = conv.speak_lang(who)
        text = {"en": en, "zh": zh, "ms": ms}[lg]
        stream.insert(rng.randint(0, len(stream)), (who, conv.style(text, lg), "PREFERENCE", None, "none", [], canon))
    for _ in range(int(len(stream) * rng.uniform(0.15, 0.4))):
        who = rng.choice(conv.members)
        lg = conv.speak_lang(who)
        stream.insert(rng.randint(0, len(stream)), (who, conv.style(rng.choice(OTHER[lg]), lg), "OTHER", None, "none", []))

    # Materialise messages, then compute gold statuses with the rule.
    by_topic = {t["id"]: t for t in conv.topics}
    stances = {t["id"]: [] for t in conv.topics}
    preferences = []
    for i, ev in enumerate(stream):
        who, text, label, tid, stance, rejects = ev[:6]
        mid = f"m{i + 1:03d}"
        conv.messages.append({"id": mid, "speaker": who, "text": text, "label": label, "topic": tid, "stance": stance})
        if label == "PREFERENCE":
            preferences.append({"speaker": who, "text": ev[6], "message": mid})
        if tid:
            if stance == "propose" and by_topic[tid]["proposal"] is None:
                by_topic[tid]["proposal"] = mid
            stances[tid].append((who, stance))
        for rid in rejects:
            stances[rid].append((who, "reject"))
            conv.messages[-1].setdefault("rejects", []).append(rid)

    n = len(conv.members)
    raw = {t["id"]: decision_rule(t, stances[t["id"]], n, False) for t in conv.topics}
    for t in conv.topics:
        superseded = False
        if t["category"] in SINGLE_VALUE:
            later = [u for u in conv.topics if u["category"] == t["category"]
                     and int(u["proposal"][1:]) > int(t["proposal"][1:]) and raw[u["id"]] == "confirmed"]
            superseded = bool(later)
        t["status"] = decision_rule(t, stances[t["id"]], n, superseded)
        for k in [k for k in t if k.startswith("_")]:
            del t[k]

    facts = {"destination": None, "budget": None, "budget_basis": None, "dates": None}
    for t in conv.topics:
        if t["status"] != "confirmed":
            continue
        if t["category"] == "DESTINATION":
            facts["destination"] = t["value"]
        elif t["category"] == "BUDGET":
            facts["budget"], facts["budget_basis"] = t["value"]["amount"], t["value"]["basis"]
        elif t["category"] == "DATE":
            facts["dates"] = t["value"]
    return {
        "conv_id": conv_id, "source": "template", "destination": destination, "members": conv.members,
        "messages": conv.messages, "topics": conv.topics, "preferences": preferences, "facts": facts,
        "reference_summary": reference_summary(conv.topics, preferences),
    }


def value_text(t):
    v = t["value"]
    if t["category"] == "BUDGET" and isinstance(v, dict):
        return f"RM{v['amount']} {'per person' if v['basis'] == 'per_person' else 'in total'}"
    return str(v)


def reference_summary(topics, preferences):
    """Plain-language gold summary, one line per area of the plan."""
    names = {"DESTINATION": "Destination", "DATE": "Dates", "BUDGET": "Budget", "ACCOMMODATION": "Accommodation",
             "ATTRACTION": "Places to visit", "TRANSPORT": "Transport"}
    lines = []
    for cat, title in names.items():
        ts = [t for t in topics if t["category"] == cat]
        if not ts:
            continue
        parts = []
        for status, word in (("confirmed", "agreed"), ("pending", "still undecided"), ("rejected", "turned down")):
            vals = [value_text(t) for t in ts if t["status"] == status]
            if vals:
                parts.append(f"{word}: {', '.join(vals)}")
        lines.append(f"{title} - " + "; ".join(parts) + ".")
    if preferences:
        lines.append("Preferences - " + "; ".join(f"{p['speaker']} {p['text']}" for p in preferences) + ".")
    pend = [value_text(t) for t in topics if t["status"] == "pending"]
    if pend:
        lines.append("Still to decide - " + ", ".join(pend) + ".")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=260, help="number of conversations")
    ap.add_argument("--seed", type=int, default=2026)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    dests = list(DESTINATIONS)
    convs = [build_conversation(rng, f"tpl-{i + 1:04d}", dests[i % len(dests)]) for i in range(args.n)]
    write_jsonl(DATA / "template.jsonl", convs)
    n_msgs = sum(len(c["messages"]) for c in convs)
    print(f"wrote {len(convs)} conversations, {n_msgs} messages -> {DATA / 'template.jsonl'}")


if __name__ == "__main__":
    main()
