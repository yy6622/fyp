# Experiment A3 - adding public human-written datasets

Model: LogReg + char, C=3, sqrt class weights. Public data: MultiWOZ 2.2 (English), CrossWOZ (Chinese), DialogSum (English chit-chat), converted by import_public_datasets.py.

Selection uses only cross-validation on the training data: the variant with the best mean of CV-hand (our hand-written group chats) and CV-public (the public training chats) is chosen. Selected: **+ all public, weight 1**.

| Training data | Messages | CV-hand F1 | CV-public F1 | challenge F1 | challenge2 F1 | small talk → OTHER % | public test acc | public test F1 | off-topic → OTHER % |
|---|---|---|---|---|---|---|---|---|---|
| No public data (before) | 7876 | 63.2 | 20.9 | 77.9 | 55.4 | 72.2 | 15.2 | 25.5 | 7.5 |
| + all public, weight 1 | 16892 | 60.6 | 91.7 | 74.9 | 55.9 | 81.7 | 92.5 | 92.4 | 97.6 |
| + all public, weight 0.5 | 16892 | 60.4 | 91.0 | 75.0 | 57.4 | 77.0 | 92.0 | 91.9 | 96.0 |
| + all public, weight 0.3 | 16892 | 61.5 | 90.0 | 75.9 | 58.2 | 77.0 | 90.8 | 90.8 | 95.0 |
| + DialogSum only (chit-chat), weight 1 | 10882 | 61.4 | 27.4 | 76.2 | 57.4 | 78.6 | 14.7 | 17.6 | 98.2 |
| + MultiWOZ + CrossWOZ only, weight 1 | 13886 | 61.7 | 69.2 | 75.9 | 57.2 | 73.8 | 93.3 | 93.6 | 17.4 |
