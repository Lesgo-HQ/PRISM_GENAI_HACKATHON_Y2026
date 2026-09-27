import argparse

def quantize():
    parser = argparse.ArgumentParser()
    parser.add_argument("--onnx_model", type=str, required=True)
    parser.add_argument("--output_model", type=str, required=True)
    args = parser.parse_args()
    print(f"Quantizing ONNX model {args.onnx_model} to INT8 at {args.output_model}...")

if __name__ == "__main__":
    quantize()
