import argparse

def export():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", type=str, required=True)
    parser.add_argument("--output_path", type=str, required=True)
    args = parser.parse_args()
    print(f"Exporting model from {args.model_path} to {args.output_path} in ONNX format...")

if __name__ == "__main__":
    export()
