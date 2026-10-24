# Travel Group Discussion Summarisation

Voya's own model for reading a trip's group chat (English / Chinese / Malay, often mixed) and turning it
into a structured summary and an organised plan:

- **What was discussed** — destination, dates, budget, places, transport, accommodation;
  each item is marked **agreed / undecided / turned down**, plus each member's preferences.
- **AI Summarise** — the agreed places become a day-by-day plan that respects the group's saved list,
  the current plan, flights and check-in times.

No external AI service is used, neither for training nor at run time. Training uses generated chats,
hand-written chats and three public human-written dialogue datasets (Section 2). The trained classifier
is exported to JSON and runs inside the Cloud Functions.

In the app: group chat → attachment → **AI Summarise**.

## 1. Pipeline

```
group chat messages
  │ 1. preprocessing  features.py          NFKC, lower case, URLs removed; zzmoney / zzdate / zzquestion tags
  │ 2. TF-IDF character n-grams (2-5)      works for mixed Chinese / English / Malay without word segmentation
  │ 3. linear classifier (Experiment A)    9 classes: BUDGET DATE DESTINATION ATTRACTION TRANSPORT
  │                                                  ACCOMMODATION PREFERENCE DECISION OTHER
  ▼
summariser.py (own algorithm)
  4. stance detection                    agree / reject / defer / finalize (rules, three languages, lexicons.json)
  5. topic tracking                      each concrete proposal is a topic; replies are linked to the topic
                                         they refer to (cosine similarity) or to the latest proposal
  6. group decision rule                 confirmed / rejected / pending (below)
  7. importance score S(m) = wR·R + wD·D + wN·N + wC·C
        R relevance   classifier confidence that the message is about the trip
        D decision    role of the message in a decision (confirmed proposal 1.0, open proposal 0.7, ...)
        N novelty     1 − highest similarity to any earlier message
        C centrality  TextRank (PageRank on the message similarity graph)
  8. structured summary                  facts / sections / preferences / pending / highlights / text
  ▼
functions/planner/ (place-level planning, Section 6)
  9. real places only, decisions per place, wishes filled from the saved list, day-by-day schedule
```

**Group decision rule** — "if someone proposes it and nobody objects, it is agreed".
Each member's last stance counts; the proposer counts as agreeing.
- A later agreed option for a single-value topic (destination, dates, budget, hotel) replaces the earlier one → **rejected**
- objectors ≥ supporters + hesitant → **rejected**
- someone objects but more people support it → **pending**
- someone finalises it ("ok confirm, I book") → **confirmed**
- the only reaction is hesitation and nobody else agrees → **pending**
- otherwise, including **no reaction at all** → **confirmed**

## 2. Data

| Source | File | Size | Used for |
|---|---|---|---|
| Generated chats | `generate_template_data.py` | 260 chats / ~9,400 messages | training, test_seen, test_unseen (Osaka and Kota Kinabalu never appear in training) |
| Hand-written training chats | `manual_data.py`, `manual_data_batch2.py`, `manual_data_batch3.py` | 44 chats / 935 messages | training (each message weighted ×5) |
| Challenge set 1 | `challenge_data.py` → `CHATS` | 6 chats / 174 messages | test only |
| Challenge set 2 | `challenge_data.py` → `CHATS2` | 6 chats / 140 messages | test only; frozen before the last training rounds, never used to change the model |
| Small-talk set | `smalltalk_test.py` | 126 messages | test only; every message must be OTHER |
| **MultiWOZ 2.2** (English, MIT) | `import_public_datasets.py` | ~3,000 training messages; 150 test chats | real (crowd-sourced) hotel / attraction / restaurant / train / taxi dialogues |
| **CrossWOZ** (Chinese, Apache-2.0) | `import_public_datasets.py` | ~3,000 training messages; 150 test chats | real Beijing travel dialogues: attractions, restaurants, hotels, metro, taxis |
| **DialogSum** (English, CC BY-NC-SA 4.0) | `import_public_datasets.py` | ~3,000 training messages; 72 test chats | real everyday conversations with no travel content → all OTHER |
| Real group chats (optional) | `export_firestore_chats.js`, `prepare_real_labelling.py` | — | test only (test_real) |

Generated chats are built backwards from a hidden plan, so every message label, stance, topic and final
status is exact. The public datasets are downloaded from GitHub on the first run
(github.com/budzianowski/multiwoz, github.com/thu-coai/CrossWOZ, github.com/cylnlp/dialogsum). Only the
user side of each dialogue is used, and its human-annotated dialogue acts are mapped to our labels:
hotel → ACCOMMODATION; attraction, restaurant → ATTRACTION; train, taxi, metro → TRANSPORT; greet / thank /
bye only → OTHER; turns that span two labels are dropped. These are one-person-to-clerk dialogues with no
group decisions, so they train and test the **message classifier** only. DialogSum is licensed for
non-commercial use (academic use is fine; cite it).

The Chinese and Malay text in the data files, `lexicons.json` and `kb_pois.py` is intentional: it is what
lets the model and the planner understand chats in those languages.

## 3. Running it

```bash
cd ml/discussion_summary
pip install -r requirements.txt
python run_pipeline.py            # full run: data, Experiment A (19 configs × 5 folds + learning curve),
                                  # Experiment A3, Experiment B, parity and planner tests (30-40 min)
python run_pipeline.py --quick    # retrain the selected model and evaluate (~1 min)
```

Results are written to `results/` (`experiment_A.md`, `experiment_B.md`, `experiment_public.md`, confusion matrices).

**Adding real group chats (optional):**
```bash
gcloud auth application-default login
node export_firestore_chats.js        # → data/raw/firestore_messages.csv
python prepare_real_labelling.py      # the model pre-fills labels into data/real_*.csv
```
Correct the three CSV files (instructions at the top of `prepare_real_labelling.py`), save as UTF-8 CSV and
run the pipeline again; a `test_real` column appears in the results.

**Deploying:** `python export_model.py --deploy` copies `model.json`, `lexicons.json` and the planner's
`gazetteer.json` into `functions/`; then `firebase deploy --only functions`.

**Tests without Firebase** (from `functions/`):
```bash
node ../ml/discussion_summary/test_functions_mock.js   # the three Cloud Functions against a fake Firestore
node ../ml/discussion_summary/test_planner.js          # AI Summarise builds a sensible plan
node ../ml/discussion_summary/test_optimise.js         # Optimise (no AI) reworks a plan sensibly
node ../ml/discussion_summary/test_osm_places.js       # wishes without a place name: catalog_places / OpenStreetMap
python ../ml/discussion_summary/test_parity.py         # JavaScript port == Python, chat by chat
```

## 4. Results

Numbers come from `results/*.md` and are rewritten on every full run.

### Experiment A — message classifier (macro-F1 %)

The model is chosen using training data only: 5-fold cross-validation grouped by chat. *CV-hand* is the
score on hand-written training chats (closest to real chat), *CV-public* the score on the public training
chats; the selection score is their mean.

| Model | CV-hand | CV-public | challenge | challenge 2 |
|---|---|---|---|---|
| Majority class | 6.1 | 10.3 | 7.7 | 7.8 |
| Naive Bayes + char | 49.5 | 88.3 | 63.3 | 50.3 |
| LogReg + word | 57.8 | 78.5 | 69.2 | 53.4 |
| Linear SVM + word | 54.1 | 80.4 | 67.7 | 52.8 |
| Linear SVM + char, C=0.3 | 59.5 | 91.9 | 72.2 | 52.8 |
| LogReg + char, C=10 | 60.8 | 91.3 | 74.4 | 55.9 |
| **LogReg + char, C=3, sqrt class weights (selected)** | **60.6** | **91.7** | **74.9** | **55.9** |

- Character n-grams clearly beat word n-grams (Chinese has no spaces).
- Weighting the hand-written chats ×5 beats ×1 (59.5 vs 55.7 CV-hand for the SVM).
- Learning curve (CV-hand vs number of hand-written chats): 0 → 45.5, 11 → 52.1, 22 → 56.5, 33 → 58.6, 44 → 60.6.
  It is still rising: more real, varied chat data is the most effective improvement.
- Template test sets score 96-100 %, which only shows the templates were learned.

### Experiment A3 — adding the public datasets (`results/experiment_public.md`)

| Training data | CV-hand | small talk → OTHER | real travel sentences (public test) | everyday chat → OTHER |
|---|---|---|---|---|
| generated + hand-written | 63.2 | 72.2 % | 15.2 % | 7.5 % |
| **+ public datasets (used)** | 60.6 | 81.7 % | **92.5 %** | **97.6 %** |

Without the public data the classifier scored only 15 % on real human-written travel sentences and
labelled almost all everyday chat as trip content. The cost is a small drop on our own hand-written chats
(63.2 → 60.6 CV-hand), whose style is closer to the generated data.

### Experiment B — summary (in brackets: the same pipeline with the gold message labels)

| Metric | challenge | challenge 2 |
|---|---|---|
| Topic detection F1 | 84.7 (95.6) | 61.7 (91.3) |
| Decision (status) accuracy | 74.5 (85.2) | 72.0 (88.1) |
| False "confirmed" rate ↓ | 33.3 (23.5) | 83.3 (50.0) |
| Reply-to-topic linking | 68.5 (85.9) | 41.3 (81.3) |
| ROUGE-L F1 | 32.9 (40.5) | 33.4 (45.9) |
| Key messages F1: S(m) / Lead-20 % / Random-20 % | 61.9 / 24.7 / 27.6 | 44.4 / 27.8 / 26.7 |

On real everyday chats (72 DialogSum test chats) 98.0 % of messages are recognised as small talk, with
0.11 false trip topics per chat (0.29 on the small-talk set).

**Reading the results**
1. With gold labels, challenge set 2 reaches 91 topic F1 and 88 % decision accuracy, so the summary rules
   generalise; end to end it is 62 / 72, so most errors come from the classifier, and the learning curve
   shows the classifier is short of data.
2. All character n-gram linear models are within noise of each other on CV-hand. The selection rule was
   fixed in advance; a model that scores higher on a test set was not picked because of it.
3. Key-message selection: D (decision role) matters most; removing it costs the most F1.
4. Each challenge set has only 6 chats (~45 topics), so their numbers move a lot; the false-confirmed rate
   on challenge set 2 has a very small denominator.
5. Known limits: cross-language references (proposal in English, reply in Chinese) are not linked;
   conditional agreement counts as agreement; one label per message.

## 5. Small talk ("hi" must not become a destination)

| | small talk recognised | false proposals in 7 small-talk chats |
|---|---|---|
| first version | 30.5 % | 22 |
| more small talk in the generated data | 72.2 % | – |
| + rule gate `gate()` (greetings / thanks / laughter / emoji → OTHER; place labels need content) | 87.3 % | 6 |
| + public datasets | **90.5 %** | **2** |

## 6. Planner — from agreed messages to an organised plan (`functions/planner/`)

1. **Real places only** (`places.js`): the group's saved list → the app's catalog for the city →
   Voya's place database `gazetteer.json` (generated by `export_gazetteer.py`: 235 places in 15 cities with
   Chinese names, district, suitable time of day and visit length) → name patterns ("… Road", "… Temple", and their Chinese equivalents).
   A message without a place name never becomes a plan item.
2. **Who agreed to which place** (`decide.js`): each message's stance is attached to the place it names, or
   to the place discussed just before; comparisons ("same as the Pearl Tower") and complaints about the
   pace are not votes; banter is not an objection. The group decision rule above is applied per place.
   A choice made in the app ("Decide now") always wins and is stored per place.
3. **Wishes without a place** (`needs.js`): "a museum", "café with a view", "brunch", local food, dessert …
   are filled from the saved list (category / cuisine tags); if nothing fits they are shown as ideas.
4. **Schedule** (`schedule.js`): days and times named in the chat first; a theme park gets its own day;
   places mentioned together stay together; same-district places share a day; at most 3 sights a day
   (2 when someone asks for a relaxed trip); arrival day after check-in, last day ends at noon; meals at
   lunch / dinner, cafés in the afternoon, night views and river cruises in the evening; nothing within an
   hour of an existing plan item; flight times respected.
5. A saved place keeps its exact saved name, so the plan shows it as a rich activity card.
6. **Flights and hotels** (`logistics_plan.js`): booked flights (exact times from Explore bookings, or the
   typed-in date / time) set the earliest start on arrival day (landing + 90 min) and the latest end on
   the last day (3 hours before the flight home); with no flight booked, arrival / departure times said
   in the chat are used. A booked hotel adds check-in (15:00, or after landing) and check-out (11:00)
   under its exact name, and is compared with the area the group agreed to stay in. With no hotel booked,
   a hotel the group saved in that area is suggested; otherwise "book a hotel / flights" is shown as an idea.

`test_planner.js` checks this on a 71-message test chat, on a 182-message real group chat
(`real_chats/shanghai_group.json`), on the same chat with a saved list and an existing plan, and with booked flights and a hotel.

### Wishes without a place name

People often say what they want, not where: "去泰国一定要逛夜市", "想去按摩", "a café", "本帮菜".
`needs.js` recognises these wishes (night market, street food, massage / spa, café, brunch, dessert,
dumplings, local food, museum, mall, park, temple, beach, rooftop bar, floating market). When the group
agrees on one, it is filled in this order:

1. a place of that kind in the group's **saved list** (it becomes a rich activity card);
2. a place Voya already knows in that city: the app's catalog and the gazetteer (category, cuisine and
   `tags`; "local food" means that country's cuisine, e.g. Thai in Bangkok);
3. **Firestore `catalog_places`**, then **OpenStreetMap** (`osm_places.js`: Nominatim finds the city,
   Overpass finds places of that kind within 12 km, well-known ones first). What OSM returns is written to
   `catalog_places` with `needKeys` (e.g. `"TH:night market"`) and `type`, so the next trip to that city
   finds it without asking OSM again. At most 4 OSM lookups per run, 9 s timeout each.
4. if nothing is found (or OSM is unreachable), the wish itself goes into the plan as a time block at the
   right time of day ("Night market", evening) with a "Pick a place" badge.

Food stops are spread out: at most 3 food stops and one café / dessert stop a day.
`test_osm_places.js` checks steps 3 and 4 with a fake OSM and a fake Firestore.

### Optimise (no AI)

Optimise (`functions/optimise_engine.js`) reorders and re-times the activities already in the plan.
It uses no AI model and no external service: fixed rules plus the same place knowledge base.

1. **Profile** each activity: a place Voya knows (gazetteer or saved list) brings its visit length, its
   district and its best time (morning / afternoon / evening only / full day); otherwise words in the label
   decide (breakfast, lunch, dinner, supper, café, sunrise, sunset, night market ...). Flights and timed
   hotel check-ins / check-outs never move.
2. **Logistics** (`logistics_plan.js`): booked or typed-in flights set when each day starts and ends; a
   booked hotel blocks check-in (15:00) and check-out (11:00).
3. **Whole trip**: a theme park gets its day to itself; a day too short for its activities (flight day)
   hands the extra ones to the day with the most free time; a museum / garden that would only get an
   evening slot moves to a day where it fits in daylight; places in the same district share a day;
   days are balanced without splitting a district group (unless a day has more than 3 sights).
4. **Each day**: meals at meal times (a sight never runs more than 30 min into lunch / dinner), evening
   places in the evening, the rest in order of their best time with same-district places next to each
   other, each for its visit length, plus 15 min (same district) or 30 min (another district) to get there.
5. Every change comes with its reason ("Best in the evening", "Shanghai Disneyland takes the whole of
   Day 2", "Day 1 is short because of your flight"); what cannot be fixed in "this day" mode comes back as
   a note suggesting Optimise Whole Trip.

`test_optimise.js` checks one day, a whole trip with a theme park, typed-in flights with a booked hotel,
that a second run changes nothing, and unknown places.

## 7. Files

| File | Purpose |
|---|---|
| `common.py` | labels, data format, paths |
| `generate_template_data.py`, `kb.py`, `kb_pois.py` | generated chats and the place knowledge base |
| `manual_data.py`, `manual_data_batch2.py`, `manual_data_batch3.py` | hand-written training chats |
| `challenge_data.py`, `smalltalk_test.py` | hand-written test sets |
| `import_public_datasets.py` | downloads MultiWOZ / CrossWOZ / DialogSum and maps their labels |
| `export_firestore_chats.js`, `prepare_real_labelling.py` | optional real-chat export and model-assisted labelling |
| `build_dataset.py` | merges all sources and splits by chat |
| `features.py`, `lexicons.json` | preprocessing and stance word lists (shared with the JavaScript port) |
| `train_classifier.py` | Experiment A and the learning curve |
| `experiment_public.py` | Experiment A3 (with / without the public datasets) |
| `export_model.py`, `model_runtime.py` | exports the classifier to `models/model.json` and checks it predicts exactly like scikit-learn |
| `summariser.py` | the summary algorithm |
| `evaluate_summary.py` | Experiment B, S(m) ablation, oracle comparison |
| `export_gazetteer.py` | builds the planner's place database |
| `test_parity.py`, `parity_runner.js` | the Cloud Function port gives identical output to Python |
| `test_functions_mock.js`, `test_planner.js`, `test_optimise.js`, `test_osm_places.js`, `plan_test_chat.json`, `real_chats/` | Cloud Function, planner, Optimise and OSM lookup tests |
| `run_pipeline.py` | runs everything in order |
| `data/`, `models/`, `results/` | datasets and splits, trained model, experiment results |
