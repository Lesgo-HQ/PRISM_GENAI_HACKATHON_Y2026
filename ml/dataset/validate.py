import json
import sys
from collections import Counter

def validate(path):
    counts = Counter()
    errors = 0
    total = 0
    with open(path) as f:
        for i, line in enumerate(f, 1):
            total += 1
            try:
                obj = json.loads(line)
                assert 'text' in obj, f'Line {i}: missing text'
                assert 'intent' in obj, f'Line {i}: missing intent'
                assert 'slots' in obj, f'Line {i}: missing slots'
                assert isinstance(obj['slots'], dict), f'Line {i}: slots not dict'
                counts[obj['intent']] += 1
            except Exception as e:
                print(f'ERROR line {i}: {e}')
                errors += 1
    print(f'\nValidated {path}: {total} samples, {errors} errors')
    print('Distribution:')
    for intent, count in sorted(counts.items(), key=lambda x: -x[1]):
        print(f'  {intent}: {count}')
    return errors == 0

if __name__ == '__main__':
    paths = sys.argv[1:] or ['ml/dataset/train.jsonl', 'ml/dataset/dev.jsonl', 'ml/dataset/test.jsonl']
    all_ok = all(validate(p) for p in paths)
    sys.exit(0 if all_ok else 1)
