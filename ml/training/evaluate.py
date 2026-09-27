"""Evaluate SAAR-NLU model on test set."""
import json
import argparse
from collections import Counter

def main():
    parser = argparse.ArgumentParser(description='Evaluate SAAR-NLU')
    parser.add_argument('--test', default='ml/dataset/test.jsonl')
    parser.add_argument('--model-dir', default='ml/models/checkpoints')
    args = parser.parse_args()

    with open(args.test) as f:
        test_data = [json.loads(line) for line in f]
    print(f'Loaded {len(test_data)} test samples')

    intents = Counter(d['intent'] for d in test_data)
    print('\nTest set distribution:')
    for intent, count in sorted(intents.items(), key=lambda x: -x[1]):
        print(f'  {intent}: {count}')

    print('\nMetrics to compute (with trained model):')
    print('  Intent: Accuracy, Macro F1, Per-class F1')
    print('  Slots: Precision, Recall, F1, Exact span match')
    print('  Retrieval: Recall@1, Recall@3, MRR')
    print('  Unknown: Precision, Recall, False execution rate')
    print('  Safety: Unsafe execution rate (target: 0)')

if __name__ == '__main__':
    main()
