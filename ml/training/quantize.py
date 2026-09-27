import argparse
import os
from onnxruntime.quantization import quantize_dynamic, QuantType

def quantize():
    parser = argparse.ArgumentParser()
    # Default to assuming script is run from project root, but allow override
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    model_path = os.path.join(script_dir, 'models', 'saar_nlu.onnx')
    output_path = os.path.join(script_dir, 'models', 'saar_nlu_int8.onnx')
    
    parser.add_argument("--onnx_model", type=str, default=model_path)
    parser.add_argument("--output_model", type=str, default=output_path)
    args = parser.parse_args()
    
    print(f"Quantizing ONNX model {args.onnx_model} to INT8 at {args.output_model}...")
    
    quantize_dynamic(
        model_input=args.onnx_model,
        model_output=args.output_model,
        weight_type=QuantType.QUInt8,
    )
    print("Quantization complete! Your INT8 ONNX model is ready.")

if __name__ == "__main__":
    quantize()
