import sys
import codecs
sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')
import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

def main():
    model_dir = 'ml/models/checkpoints/best'
    output_path = 'ml/models/saar_nlu.onnx'
    
    print(f"Loading model from {model_dir}...")
    tokenizer = AutoTokenizer.from_pretrained(model_dir)
    model = AutoModelForSequenceClassification.from_pretrained(model_dir)
    model.eval()

    dummy_text = "test sequence"
    inputs = tokenizer(dummy_text, return_tensors="pt", padding='max_length', max_length=64, truncation=True)
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    print(f"Exporting to ONNX format at {output_path}...")
    torch.onnx.export(
        model,
        (inputs['input_ids'], inputs['attention_mask']),
        output_path,
        export_params=True,
        opset_version=14,
        do_constant_folding=True,
        input_names=['input_ids', 'attention_mask'],
        output_names=['logits'],
        dynamic_axes={
            'input_ids': {0: 'batch_size', 1: 'sequence_length'},
            'attention_mask': {0: 'batch_size', 1: 'sequence_length'},
            'logits': {0: 'batch_size'}
        }
    )
    print("Export complete.")

if __name__ == '__main__':
    main()
