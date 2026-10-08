# Voya — 群聊讨论 → 行程改动 的 AI 模型（v2）

模型读取三样东西：

1. 群组的 **saved list**（全组成员为这个 trip 收藏的景点和餐厅）
2. **现有的 plan**
3. **群聊讨论**（英文 / 中文 / 马来文 / 混合）

然后输出大家**真正同意**的改动：

| 输出 | 意思 |
|---|---|
| `add` | 要新增的活动。地点在 saved list 里就用收藏里的名字，并标 `saved: true`；不在就标 `false`（app 会显示提示） |
| `update` | plan 里已有的活动要改天或改时间 |
| `remove` | plan 里已有的活动要取消 |
| `unresolved` | 提过但没结论的地点 |

没被讨论到的现有活动，模型不会碰。

做法：在 Vertex AI 上对 Gemini 做 supervised fine-tuning，再由 Cloud Function `generateItinerary` 调用。

> v1（只看聊天、输出整份行程）的评估结果保留在 `results_v1/report.md`，可以在报告里当作第一版写。

## 文件

| 文件 | 作用 |
|---|---|
| `system_prompt.txt` | 模型的规则 |
| `prompt_format.py` | 输入/输出格式的唯一定义 |
| `kb.py` | 14 个目的地、约 210 个真实景点/餐厅，含口语叫法和中文名 |
| `generate_dataset.py` | 合成训练数据 |
| `data/` | `train.jsonl` 600、`val.jsonl` 60、`test_seen.jsonl` 60、`test_unseen.jsonl` 60、`preview.txt` |
| `train_vertex.py` | 上传数据 + 开始微调 + 等结果 |
| `evaluate.py` | 在测试集上打分，对比 base 和 tuned |
| `test_prompt_parity.py` | 检查 Cloud Function 组出来的 prompt 和训练时一模一样 |

## 数据是怎么来的

没有现成的数据集，app 也还没有真实用户，所以数据是反过来造的：先随机定好「正确答案」，
再演一段乱糟糟的群聊把它谈出来，标签就是一开始定的答案，所以一定正确。

每条数据包含：

- **saved list**：4–10 个地点，有的会被聊到，有的只是干扰项；约 15% 的群组什么都没收藏。
  收藏里的名字有时和「官方名字」不一样，模型必须照抄收藏里的写法。
- **现有 plan**：约 40% 是空的（刚开始规划），其余每天有 0–3 个活动。
- **群聊**里会出现的情况：

| 情况 | 例子 | 正确结果 |
|---|---|---|
| 提议 + 同意 | `day 2 pagi pergi batu caves` / `boleh` | `add` |
| 被否决 / 被替换 | `太远了，不要`、`不要 A 啦，去 B` | 不加 / 只加 B |
| 聊天里改天、改时间、追问时间 | `几点？` / `10.30am` | `add`，用最后的决定 |
| 聊天里同意后又取消 | `cancel X la` | 不加 |
| **plan 里已有的要改天** | `move klcc to Saturday la` | `update` |
| **plan 里已有的要改时间** | `klcc 改下午3点` | `update` |
| **plan 里已有的要取消** | `cancel klcc la, tak sempat` | `remove` |
| **提议的东西已经在 plan 里** | `day 1 去 klcc？` / `已经排了啊` | 什么都不做 |
| 没结论 | `see first la` | `unresolved` |
| 只是提到 / 闲聊 | `my cousin went X last year` | 忽略 |
| 口语叫法 | `klcc`、`双峰塔` | 对应到 saved list 或官方名字 |

`test_unseen` 用的是大阪和亚庇，**完全没出现在训练数据里**。

重新生成：`python generate_dataset.py --train 800 --seed 7`

## 训练步骤

```bash
cd ml/itinerary_model
python train_vertex.py --name voya-itinerary-v2
```

（第一次的环境设置 `pip install -r requirements.txt`、`gcloud auth application-default login` 等已经做过，不用再做。）

跑完会更新 `tuned_model.json`，里面的 `endpoint` 就是新模型。

可调参数：`--epochs`（默认 3）、`--adapter-size`（默认 4）、`--lr-multiplier`、`--base-model`。

## 评估

```bash
python evaluate.py --model gemini-3.5-flash --label base
python evaluate.py --model "<tuned_model.json 里的 endpoint>" --label tuned
python evaluate.py --report      # 输出对比表，同时存到 results/report.md
```

| 指标 | 意思 |
|---|---|
| `valid_json` | 输出能不能读成合格的 JSON |
| `add_f1` / `add_p` / `add_r` | 新增的活动：地点对、日期对（名字允许长短不同）。精确率低 = 乱加；召回率低 = 漏掉 |
| `add_exact_f1` | 严格版：名字要一字不差（收藏的地点就是收藏里的名字） |
| `time_acc` | 排对的新增活动里，时间完全正确的比例 |
| `saved_acc` | 排对的新增活动里，「在不在 saved list」判断正确的比例 |
| `update_f1` | 对现有活动的改天/改时间：项目、新日期、新时间都对 |
| `remove_f1` | 对现有活动的移除 |
| `change_p` | 模型提出的所有改动/移除里有多少是对的。这项最要紧：错的会破坏用户已有的 plan |
| `unresolved_f1` | 「没结论」清单 |
| `exact` | 整份答案一字不差 |

## 部署

```bash
# 1. 把新模型的 endpoint 写进 functions/.env（覆盖旧的那行）
#    ITINERARY_MODEL=projects/1020854066179/locations/us/endpoints/....
# 2. 部署
cd C:\Users\Admin\StudioProjects\Voya
firebase deploy --only functions:generateItinerary
```

**顺序很重要**：新的 Cloud Function 发给模型的是 v2 格式，必须配 v2 训练出来的模型。
先训练、再改 `.env`、再部署。

Cloud Function 做的事：

1. 确认调用的人是这个 trip 的成员
2. 读取聊天（最近 300 条）、全组成员的 saved list、现有 plan
3. 调用模型
4. **不信任模型的输出，逐项核对**：
   - 「在不在 saved list」由代码实际比对决定，对上了就用收藏里的名字和地点
   - `update` / `remove` 必须对得上 plan 里真实存在的项目，对不上就丢弃
5. 回传建议。它**不会写入** Firestore，由用户在 app 里勾选后才生效

## 改了格式之后

`system_prompt.txt` 或 `prompt_format.py` 一改，就要：

```bash
cp system_prompt.txt ../../functions/itinerary_system_prompt.txt
python test_prompt_parity.py     # 确认 JS 和 Python 的 prompt 还是一样
python generate_dataset.py && python train_vertex.py --name voya-itinerary-v3
```

## 局限（报告里应该老实写）

- 训练数据是模板合成的，真实群聊会更乱。等有真实聊天后，挑一些人工标注加进 `train.jsonl` 再训一次会更好。
- 「同意」的定义是：有人赞成、没人反对。模型不会数票。
- saved list 只包含景点和餐厅，不包含收藏的酒店和航班。
- 把活动移到另一天时，它在那一天的票数会重新计算。
- 不在 saved list 里的地点，名称和区域来自模型自己的知识，冷门地点可能不准，所以 app 会标出提示并让用户确认。
