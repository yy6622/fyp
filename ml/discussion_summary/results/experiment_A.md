# Experiment A - message classification

Training data: 16892 messages from 1444 chats. Test messages: test_seen 1699, test_unseen 1414, test_challenge 174, test_challenge2 140, test_smalltalk 126, test_public 2312, test_offtopic 505.

Macro-F1 (%) - every class counts equally, so the frequent DECISION/OTHER classes cannot hide weak ones.

Model selection uses only the training chats (5-fold GroupKFold). *CV-hand* = macro-F1 on the
hand-written training chats when they are in the validation fold; the model is chosen by CV-hand.

*CV-public* = macro-F1 (over the 4 labels that exist there) on the public training chats when they are in
the validation fold. With public data the model is chosen by the mean of CV-hand and CV-public.
For test_public / test_offtopic use the accuracy table: they only contain 4 / 1 of the 9 labels.

| Model | CV (all) | CV-hand | CV-public | test_seen | test_unseen | test_challenge | test_challenge2 | test_smalltalk | test_public | test_offtopic |
|---|---|---|---|---|---|---|---|---|---|---|
| Majority class | 4.4 ± 0.8 | 6.1 | 10.3 | 6.7 | 6.9 | 7.7 | 7.8 | 0.0 | 0.0 | 0.0 |
| Naive Bayes + word | 83.2 ± 1.4 | 51.0 | 80.8 | 91.9 | 89.3 | 68.5 | 53.0 | 7.9 | 36.2 | 10.9 |
| Naive Bayes + char | 84.4 ± 1.0 | 49.5 | 88.3 | 87.5 | 84.5 | 63.3 | 50.3 | 9.5 | 38.0 | 11.1 |
| LogReg + word | 76.3 ± 2.2 | 57.8 | 78.5 | 92.6 | 87.1 | 69.2 | 53.4 | 7.7 | 35.0 | 10.8 |
| LogReg + char, C=3 | 90.8 ± 1.4 | 60.6 | 91.1 | 96.4 | 96.1 | 74.5 | 56.9 | 9.6 | 41.0 | 10.9 |
| LogReg + char, C=10 | 92.5 ± 1.6 | 60.8 | 91.3 | 97.8 | 98.8 | 74.4 | 55.9 | 9.6 | 41.2 | 11.0 |
| LogReg + char, C=30 | 92.9 ± 1.5 | 60.4 | 91.3 | 99.0 | 99.2 | 73.5 | 55.4 | 9.8 | 41.3 | 10.9 |
| Linear SVM + word | 82.4 ± 1.5 | 54.1 | 80.4 | 94.0 | 89.5 | 67.7 | 52.8 | 8.0 | 36.0 | 10.8 |
| Linear SVM + char (no tags), C=0.3 | 92.2 ± 1.5 | 58.2 | 91.9 | 97.9 | 97.6 | 70.8 | 52.5 | 10.1 | 41.0 | 11.0 |
| Linear SVM + char, C=0.1 | 89.0 ± 1.4 | 59.7 | 91.1 | 94.5 | 93.3 | 71.0 | 53.0 | 9.6 | 40.8 | 10.9 |
| Linear SVM + char, C=0.3 | 92.4 ± 1.7 | 59.5 | 91.9 | 97.8 | 97.6 | 72.2 | 52.8 | 10.2 | 41.0 | 11.0 |
| Linear SVM + char, C=1 | 93.1 ± 1.9 | 58.1 | 92.0 | 98.7 | 98.1 | 72.0 | 54.8 | 10.2 | 41.2 | 11.0 |
| Linear SVM + char, C=3 | 93.2 ± 1.6 | 55.9 | 91.7 | 99.5 | 98.8 | 68.3 | 55.5 | 10.0 | 41.1 | 11.0 |
| Linear SVM + char, C=0.3, hand-written weight 1 | 92.7 ± 1.8 | 55.7 | 92.5 | 97.8 | 97.9 | 65.2 | 51.0 | 10.3 | 41.2 | 11.1 |
| Linear SVM + char, C=0.3, hand-written weight 15 | 91.6 ± 1.7 | 59.8 | 91.3 | 96.6 | 96.4 | 75.0 | 55.3 | 9.2 | 40.8 | 11.0 |
| LogReg + char, C=3, + stance-cue tags | 90.8 ± 1.3 | 60.7 | 90.5 | 96.3 | 95.3 | 74.2 | 55.6 | 10.3 | 40.9 | 10.9 |
| LogReg + char, C=3, sqrt class weights **(selected)** | 93.0 ± 1.8 | 60.6 | 91.7 | 97.8 | 97.8 | 74.9 | 55.9 | 10.0 | 41.1 | 11.0 |
| LogReg + char, C=3, no class weights | 93.1 ± 1.8 | 57.3 | 91.9 | 98.0 | 97.6 | 74.9 | 53.6 | 10.0 | 40.8 | 11.0 |
| Linear SVM + char, C=0.3, sqrt class weights | 93.1 ± 1.6 | 59.7 | 92.0 | 98.3 | 97.8 | 73.1 | 55.9 | 10.2 | 40.9 | 11.0 |

Accuracy (%):

| Model | test_seen | test_unseen | test_challenge | test_challenge2 | test_smalltalk | test_public | test_offtopic |
|---|---|---|---|---|---|---|---|
| Majority class | 43.3 | 45.5 | 52.9 | 53.6 | 0.0 | 0.0 | 0.0 |
| Naive Bayes + word | 93.1 | 91.6 | 74.1 | 65.0 | 55.6 | 79.3 | 95.4 |
| Naive Bayes + char | 88.8 | 87.4 | 69.0 | 58.6 | 74.6 | 86.5 | 99.2 |
| LogReg + word | 93.6 | 90.5 | 74.1 | 66.4 | 53.2 | 70.0 | 94.3 |
| LogReg + char, C=3 | 96.9 | 97.0 | 78.2 | 70.7 | 76.2 | 92.4 | 97.0 |
| LogReg + char, C=10 | 98.0 | 98.4 | 79.3 | 70.0 | 75.4 | 92.7 | 97.4 |
| LogReg + char, C=30 | 99.2 | 98.9 | 78.2 | 67.9 | 79.4 | 92.7 | 96.6 |
| Linear SVM + word | 94.3 | 91.5 | 73.0 | 64.3 | 56.3 | 77.9 | 94.5 |
| Linear SVM + char (no tags), C=0.3 | 98.4 | 98.5 | 77.0 | 65.0 | 83.3 | 92.2 | 98.0 |
| Linear SVM + char, C=0.1 | 95.6 | 95.4 | 75.9 | 64.3 | 75.4 | 91.8 | 97.0 |
| Linear SVM + char, C=0.3 | 98.1 | 98.4 | 78.2 | 66.4 | 84.1 | 92.3 | 97.8 |
| Linear SVM + char, C=1 | 98.8 | 98.4 | 78.2 | 66.4 | 84.1 | 92.6 | 98.2 |
| Linear SVM + char, C=3 | 99.5 | 98.8 | 75.3 | 65.0 | 81.7 | 92.3 | 98.0 |
| Linear SVM + char, C=0.3, hand-written weight 1 | 98.4 | 98.7 | 70.1 | 59.3 | 86.5 | 92.8 | 99.2 |
| Linear SVM + char, C=0.3, hand-written weight 15 | 96.6 | 96.3 | 80.5 | 69.3 | 70.6 | 91.8 | 97.2 |
| LogReg + char, C=3, + stance-cue tags | 96.9 | 96.6 | 78.7 | 67.9 | 85.7 | 92.0 | 96.0 |
| LogReg + char, C=3, sqrt class weights | 98.1 | 98.4 | 79.3 | 69.3 | 81.7 | 92.5 | 97.6 |
| LogReg + char, C=3, no class weights | 98.5 | 98.3 | 79.9 | 67.9 | 82.5 | 92.1 | 98.2 |
| Linear SVM + char, C=0.3, sqrt class weights | 98.5 | 98.4 | 78.2 | 68.6 | 84.9 | 92.2 | 98.2 |

## Learning curve (selected model, CV-hand)

Templates always included; only the number of hand-written training chats changes.

| Hand-written chats | CV-hand macro-F1 |
|---|---|
| 0 | 45.5 |
| 11 | 52.1 |
| 22 | 56.5 |
| 33 | 58.6 |
| 44 | 60.6 |

## Selected model per class - test_seen

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| BUDGET | 98.2 | 100.0 | 99.1 | 56 |
| DATE | 92.3 | 100.0 | 96.0 | 48 |
| DESTINATION | 100.0 | 98.4 | 99.2 | 64 |
| ATTRACTION | 98.3 | 98.7 | 98.5 | 228 |
| TRANSPORT | 93.8 | 97.8 | 95.7 | 46 |
| ACCOMMODATION | 93.8 | 96.8 | 95.3 | 63 |
| PREFERENCE | 100.0 | 100.0 | 100.0 | 112 |
| DECISION | 98.4 | 97.8 | 98.1 | 736 |
| OTHER | 98.5 | 97.1 | 97.8 | 346 |

## Selected model per class - test_unseen

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| BUDGET | 97.5 | 100.0 | 98.7 | 39 |
| DATE | 100.0 | 100.0 | 100.0 | 36 |
| DESTINATION | 97.4 | 92.5 | 94.9 | 40 |
| ATTRACTION | 95.8 | 98.9 | 97.3 | 185 |
| TRANSPORT | 97.6 | 93.0 | 95.2 | 43 |
| ACCOMMODATION | 94.6 | 98.6 | 96.6 | 71 |
| PREFERENCE | 98.9 | 100.0 | 99.4 | 87 |
| DECISION | 99.5 | 98.1 | 98.8 | 643 |
| OTHER | 98.5 | 99.3 | 98.9 | 270 |

## Selected model per class - test_challenge

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| BUDGET | 75.0 | 100.0 | 85.7 | 6 |
| DATE | 66.7 | 66.7 | 66.7 | 9 |
| DESTINATION | 100.0 | 50.0 | 66.7 | 8 |
| ATTRACTION | 72.7 | 84.2 | 78.0 | 19 |
| TRANSPORT | 63.6 | 77.8 | 70.0 | 9 |
| ACCOMMODATION | 69.2 | 81.8 | 75.0 | 11 |
| PREFERENCE | 100.0 | 80.0 | 88.9 | 10 |
| DECISION | 88.2 | 81.5 | 84.7 | 92 |
| OTHER | 50.0 | 70.0 | 58.3 | 10 |

## Selected model per class - test_challenge2

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| BUDGET | 100.0 | 100.0 | 100.0 | 4 |
| DATE | 83.3 | 71.4 | 76.9 | 7 |
| DESTINATION | 37.5 | 50.0 | 42.9 | 6 |
| ATTRACTION | 66.7 | 38.1 | 48.5 | 21 |
| TRANSPORT | 40.0 | 44.4 | 42.1 | 9 |
| ACCOMMODATION | 75.0 | 75.0 | 75.0 | 8 |
| PREFERENCE | 33.3 | 33.3 | 33.3 | 6 |
| DECISION | 82.3 | 86.7 | 84.4 | 75 |
| OTHER | 0.0 | 0.0 | 0.0 | 4 |

## Selected model per class - test_smalltalk

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| BUDGET | 0.0 | 0.0 | 0.0 | 0 |
| DATE | 0.0 | 0.0 | 0.0 | 0 |
| DESTINATION | 0.0 | 0.0 | 0.0 | 0 |
| ATTRACTION | 0.0 | 0.0 | 0.0 | 0 |
| TRANSPORT | 0.0 | 0.0 | 0.0 | 0 |
| ACCOMMODATION | 0.0 | 0.0 | 0.0 | 0 |
| PREFERENCE | 0.0 | 0.0 | 0.0 | 0 |
| DECISION | 0.0 | 0.0 | 0.0 | 0 |
| OTHER | 100.0 | 81.7 | 90.0 | 126 |

## Selected model per class - test_public

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| BUDGET | 0.0 | 0.0 | 0.0 | 0 |
| DATE | 0.0 | 0.0 | 0.0 | 0 |
| DESTINATION | 0.0 | 0.0 | 0.0 | 0 |
| ATTRACTION | 93.8 | 94.4 | 94.1 | 1097 |
| TRANSPORT | 93.5 | 93.2 | 93.4 | 340 |
| ACCOMMODATION | 94.4 | 85.0 | 89.5 | 539 |
| PREFERENCE | 0.0 | 0.0 | 0.0 | 0 |
| DECISION | 0.0 | 0.0 | 0.0 | 0 |
| OTHER | 87.9 | 97.6 | 92.5 | 336 |

## Selected model per class - test_offtopic

| Class | Precision | Recall | F1 | Support |
|---|---|---|---|---|
| BUDGET | 0.0 | 0.0 | 0.0 | 0 |
| DATE | 0.0 | 0.0 | 0.0 | 0 |
| DESTINATION | 0.0 | 0.0 | 0.0 | 0 |
| ATTRACTION | 0.0 | 0.0 | 0.0 | 0 |
| TRANSPORT | 0.0 | 0.0 | 0.0 | 0 |
| ACCOMMODATION | 0.0 | 0.0 | 0.0 | 0 |
| PREFERENCE | 0.0 | 0.0 | 0.0 | 0 |
| DECISION | 0.0 | 0.0 | 0.0 | 0 |
| OTHER | 100.0 | 97.6 | 98.8 | 505 |
