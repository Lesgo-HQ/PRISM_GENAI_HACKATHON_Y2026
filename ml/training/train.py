import json
import argparse
import os
import torch
from torch.utils.data import Dataset
from transformers import AutoTokenizer, AutoModelForSequenceClassification, Trainer, TrainingArguments

class IntentDataset(Dataset):
    def __init__(self, texts, labels, tokenizer, label2id, max_length=64):
        self.encodings = tokenizer(texts, truncation=True, padding='max_length', max_length=max_length)
        self.labels = [label2id[l] for l in labels]

    def __getitem__(self, idx):
        item = {key: torch.tensor(val[idx]) for key, val in self.encodings.items()}
        item['labels'] = torch.tensor(self.labels[idx])
        return item

    def __len__(self):
        return len(self.labels)

def load_data(path):
    texts, intents = [], []
    with open(path) as f:
        for line in f:
            data = json.loads(line)
            texts.append(data['text'])
            intents.append(data['intent'])
    return texts, intents

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--train', default='ml/dataset/train.jsonl')
    parser.add_argument('--dev', default='ml/dataset/dev.jsonl')
    parser.add_argument('--model-name', default='google/bert_uncased_L-2_H-128_A-2')
    parser.add_argument('--output-dir', default='ml/models/checkpoints')
    parser.add_argument('--epochs', type=int, default=3)
    args = parser.parse_args()

    print(f"Loading data from {args.train} and {args.dev}...")
    train_texts, train_intents = load_data(args.train)
    dev_texts, dev_intents = load_data(args.dev)

    unique_intents = sorted(list(set(train_intents + dev_intents)))
    label2id = {label: i for i, label in enumerate(unique_intents)}
    id2label = {i: label for label, i in label2id.items()}

    os.makedirs(args.output_dir, exist_ok=True)
    with open(os.path.join(args.output_dir, 'intent_labels.json'), 'w') as f:
        json.dump(id2label, f)

    tokenizer = AutoTokenizer.from_pretrained(args.model_name)
    model = AutoModelForSequenceClassification.from_pretrained(
        args.model_name, num_labels=len(unique_intents), label2id=label2id, id2label=id2label
    )

    train_dataset = IntentDataset(train_texts, train_intents, tokenizer, label2id)
    dev_dataset = IntentDataset(dev_texts, dev_intents, tokenizer, label2id)

    training_args = TrainingArguments(
        output_dir=args.output_dir,
        num_train_epochs=args.epochs,
        per_device_train_batch_size=32,
        per_device_eval_batch_size=64,
        eval_strategy="epoch",
        save_strategy="epoch",
        
        load_best_model_at_end=True,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=dev_dataset,
    )

    print("Starting training...")
    trainer.train()
    
    print(f"Saving best model to {args.output_dir}/best")
    trainer.save_model(f"{args.output_dir}/best")
    tokenizer.save_pretrained(f"{args.output_dir}/best")

if __name__ == '__main__':
    main()
