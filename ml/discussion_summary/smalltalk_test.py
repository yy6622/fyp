"""Frozen small-talk test set: messages that are NOT about the trip (all gold OTHER).
Written before the small-talk fixes and never used for training or tuning.
Measures the problem reported on 2026-10-13: "hi" was classified as a destination.

Run: python smalltalk_test.py -> data/smalltalk.jsonl (split test_smalltalk)
"""
from common import DATA, write_jsonl

MESSAGES = """
hi
Hi
hii
hiii guys
hai
hello
hellooo
helo
hey
hey guys
heyyy
yo
sup
morning
good morning!!
gm
good afternoon
good evening
good night
gn
nite
night all
bye
byeee
see ya
ttyl
brb
back
im back
ok noted
noted
noted with thanks
thanks
thank you!
thx
tq
tqvm
ty
lol
lmao
haha
hahahaha
hehe
wkwkwk
😂😂😂
🤣
😊
👋
🙏
❤️
?
??
...
test
testing 123
is this working
are you there
anyone here?
where are you
what time is it
i'm hungry
so sleepy
just woke up
going to shower first
on the way
reached home
my phone almost die
my wifi so slow today
work so busy today
traffic jam again
raining heavily here
it's so hot today
happy birthday!!
congrats!!
sorry late reply
sorry just saw
nvm
oops wrong group
wrong chat sorry
who changed the group photo
nice photo
cute
same lol
true true
omg really
wah seriously
you ok?
take care
get well soon
good luck for your exam
早
早安
早上好
你好
大家好
嗨
在吗
在不在
哈哈哈
笑死我了
晚安
拜拜
谢谢
谢谢你
收到
好累
刚起床
在开会
吃饱了吗
下雨了
生日快乐
不好意思刚看到
发错群了
测试
hai semua
selamat pagi
selamat malam
assalamualaikum
apa khabar
terima kasih
tq ye
ok noted ya
jap
nanti aku reply
sorry baru nampak
otw
dah sampai rumah
penat gila
lapar la
hujan lebat
happy birthday bro
""".strip().splitlines()


def build():
    # strings that also appear word-for-word in the training templates are left out,
    # so the test only contains messages the model has never seen
    from features import normalize
    from generate_template_data import OTHER
    seen = {normalize(x) for v in OTHER.values() for x in v}
    msgs = [m.strip() for m in MESSAGES if m.strip() and normalize(m) not in seen]
    convs = []
    for k in range(0, len(msgs), 20):
        part = msgs[k:k + 20]
        members = ["Ann", "Bob", "Cai", "Dee"]
        convs.append({
            "conv_id": f"smalltalk-{k // 20 + 1:02d}", "source": "smalltalk", "destination": None, "members": members,
            "messages": [{"id": f"m{i + 1:03d}", "speaker": members[i % 4], "text": t, "label": "OTHER", "topic": None,
                          "stance": "none"} for i, t in enumerate(part)],
            "topics": [], "preferences": [],
            "facts": {"destination": None, "budget": None, "budget_basis": None, "dates": None},
            "reference_summary": "",
        })
    write_jsonl(DATA / "smalltalk.jsonl", convs)
    print(f"wrote {len(msgs)} small-talk test messages")


if __name__ == "__main__":
    build()
