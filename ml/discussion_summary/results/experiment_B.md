# Experiment B - summary quality

Importance weights tuned on the training chats: {'R': 0.7, 'D': 0.3, 'N': 0.0, 'C': 0.0}

All numbers are %, except compression (a ratio). In brackets: the same pipeline fed the gold message labels (an oracle classifier), which shows how much error comes from classification versus the summary rules.

| Metric | test_seen | test_unseen | test_challenge | test_challenge2 | test_smalltalk | test_offtopic |
|---|---|---|---|---|---|---|
| Topic detection F1 | 94.2 (95.2) | 95.0 (95.9) | 84.7 (95.6) | 61.7 (91.3) | 0.0 (0.0) | 0.0 (0.0) |
| Decision (status) accuracy | 82.5 (83.7) | 82.0 (84.0) | 74.5 (85.2) | 72.0 (88.1) | 0.0 (0.0) | 0.0 (0.0) |
| False 'confirmed' rate (lower is better) | 19.2 (16.8) | 21.3 (18.3) | 33.3 (23.5) | 83.3 (50.0) | 0.0 (0.0) | 0.0 (0.0) |
| End-to-end status F1 | 77.7 (79.7) | 77.9 (80.5) | 63.1 (81.4) | 44.4 (80.4) | 0.0 (0.0) | 0.0 (0.0) |
| Stance accuracy | 95.9 (97.4) | 95.3 (97.2) | 66.3 (77.2) | 70.7 (76.0) | 0.0 (0.0) | 0.0 (0.0) |
| Reply-to-topic linking accuracy | 79.6 (81.9) | 80.6 (83.0) | 68.5 (85.9) | 41.3 (81.3) | 0.0 (0.0) | 0.0 (0.0) |
| Coverage of confirmed + pending topics | 92.5 (93.8) | 93.8 (94.6) | 93.0 (100.0) | 51.4 (91.9) | 0.0 (0.0) | 0.0 (0.0) |
| Fact: budget amount | 91.1 (91.1) | 97.1 (97.1) | 83.3 (100.0) | 100.0 (83.3) | 100.0 (100.0) | 100.0 (100.0) |
| Fact: budget per person / total | 93.3 (93.3) | 94.1 (94.1) | 83.3 (100.0) | 83.3 (66.7) | 100.0 (100.0) | 100.0 (100.0) |
| Fact: dates | 86.7 (86.7) | 88.2 (88.2) | 33.3 (50.0) | 100.0 (100.0) | 100.0 (100.0) | 100.0 (100.0) |
| Fact: destination | 77.8 (77.8) | 73.5 (82.4) | 66.7 (83.3) | 16.7 (50.0) | 85.7 (100.0) | 98.6 (100.0) |
| ROUGE-1 F1 | 52.8 (53.0) | 49.4 (49.6) | 53.1 (56.4) | 45.7 (54.5) | 0.0 (0.0) | 0.0 (0.0) |
| ROUGE-L F1 | 40.7 (40.8) | 35.8 (36.3) | 32.9 (40.5) | 33.4 (45.9) | 0.0 (0.0) | 0.0 (0.0) |
| Compression (summary / chat chars) | 0.79 (0.79) | 0.75 (0.76) | 0.79 (0.84) | 0.68 (0.87) | 0.07 (0.00) | 0.02 (0.00) |
| Message label accuracy (classifier + rules) | 97.9 (100.0) | 98.0 (100.0) | 78.2 (100.0) | 70.0 (100.0) | 90.5 (100.0) | 98.0 (100.0) |
| Topics created per chat (small talk should be 0) | 8.91 (8.91) | 9.97 (9.97) | 9.50 (9.83) | 5.83 (7.67) | 0.29 (0.00) | 0.11 (0.00) |

## Highlights: which messages does S(m) pick? (F1 % against gold important messages, top 20%)

| Selection | test_seen | test_unseen | test_challenge | test_challenge2 | test_smalltalk | test_offtopic |
|---|---|---|---|---|---|---|
| Lead-20% | 28.2 | 27.8 | 24.7 | 27.8 | 0.0 | 0.0 |
| Random-20% | 24.8 | 24.3 | 27.6 | 26.7 | 0.0 | 0.0 |
| R only (relevance) | 33.2 | 30.5 | 26.8 | 13.9 | 0.0 | 0.0 |
| D only (decision) | 70.1 | 70.0 | 59.8 | 50.0 | 0.0 | 0.0 |
| N only (novelty) | 18.9 | 22.4 | 24.4 | 26.5 | 0.0 | 0.0 |
| C only (TextRank) | 32.5 | 30.3 | 37.1 | 19.4 | 0.0 | 0.0 |
| S default weights | 68.0 | 68.9 | 61.9 | 44.4 | 0.0 | 0.0 |
| S tuned weights | 69.8 | 70.0 | 59.8 | 41.7 | 0.0 | 0.0 |
| S tuned without R | 70.1 | 70.0 | 59.8 | 50.0 | 0.0 | 0.0 |
| S tuned without D | 33.2 | 30.5 | 26.8 | 13.9 | 0.0 | 0.0 |
| S tuned without N | 69.8 | 70.0 | 59.8 | 41.7 | 0.0 | 0.0 |
| S tuned without C | 69.8 | 70.0 | 59.8 | 41.7 | 0.0 | 0.0 |

Chats per split: test_seen 45, test_unseen 34, test_challenge 6, test_challenge2 6, test_smalltalk 7, test_offtopic 72
