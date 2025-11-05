#!/usr/bin/env python3
"""
convert_bert_to_coreml.py
Converts BERT model from Hugging Face to CoreML format for PDFOS

Requirements:
    pip install transformers torch coremltools
"""

import argparse
import torch
import coremltools as ct
from transformers import BertModel, BertTokenizer


def convert_bert_to_coreml(
    model_name="bert-base-uncased",
    output_path="bert-base-uncased.mlmodel",
    max_seq_length=512
):
    """
    Converts BERT model to CoreML format.

    Args:
        model_name: Name of the Hugging Face BERT model
        output_path: Output path for the CoreML model
        max_seq_length: Maximum sequence length (default: 512)
    """
    print(f"Loading BERT model: {model_name}")

    # Load pretrained model and tokenizer
    model = BertModel.from_pretrained(model_name)
    tokenizer = BertTokenizer.from_pretrained(model_name)

    # Set model to evaluation mode
    model.eval()

    print("Converting to TorchScript...")

    # Create example inputs
    example_text = "This is an example sentence for BERT conversion."
    inputs = tokenizer(
        example_text,
        return_tensors="pt",
        max_length=max_seq_length,
        padding="max_length",
        truncation=True
    )

    # Trace the model with example inputs
    with torch.no_grad():
        traced_model = torch.jit.trace(
            model,
            (inputs["input_ids"], inputs["attention_mask"])
        )

    print("Converting to CoreML...")

    # Convert to CoreML
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(
                name="input_ids",
                shape=(1, max_seq_length),
                dtype=int
            ),
            ct.TensorType(
                name="attention_mask",
                shape=(1, max_seq_length),
                dtype=int
            )
        ],
        outputs=[
            ct.TensorType(name="last_hidden_state"),
            ct.TensorType(name="pooler_output")
        ],
        convert_to="mlprogram"  # Use ML Program for better performance on Apple Silicon
    )

    # Add metadata
    mlmodel.short_description = f"BERT model ({model_name}) for semantic embedding"
    mlmodel.author = "PDFOS"
    mlmodel.license = "Apache 2.0"
    mlmodel.version = "1.0"

    # Add input descriptions
    mlmodel.input_description["input_ids"] = "Token IDs from BERT tokenizer"
    mlmodel.input_description["attention_mask"] = "Attention mask (1 for real tokens, 0 for padding)"

    # Add output descriptions
    mlmodel.output_description["last_hidden_state"] = "Hidden states from all layers (batch_size, sequence_length, hidden_size)"
    mlmodel.output_description["pooler_output"] = "Pooled output for the [CLS] token (batch_size, hidden_size)"

    print(f"Saving CoreML model to: {output_path}")
    mlmodel.save(output_path)

    print("Conversion complete!")

    # Save vocabulary
    vocab_path = output_path.replace(".mlmodel", "_vocab.txt")
    print(f"Saving vocabulary to: {vocab_path}")

    vocab = tokenizer.get_vocab()
    sorted_vocab = sorted(vocab.items(), key=lambda x: x[1])

    with open(vocab_path, 'w') as f:
        for token, _ in sorted_vocab:
            f.write(f"{token}\n")

    print(f"\nModel info:")
    print(f"  - Max sequence length: {max_seq_length}")
    print(f"  - Hidden size: {model.config.hidden_size}")
    print(f"  - Vocabulary size: {model.config.vocab_size}")
    print(f"  - Number of layers: {model.config.num_hidden_layers}")

    return mlmodel


def quantize_model(model_path, output_path):
    """
    Quantizes the CoreML model to reduce size.

    Args:
        model_path: Path to the CoreML model
        output_path: Output path for quantized model
    """
    print(f"Loading model from: {model_path}")
    model = ct.models.MLModel(model_path)

    print("Quantizing model (float16)...")

    # Quantize to float16
    quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(
        model,
        nbits=16
    )

    print(f"Saving quantized model to: {output_path}")
    quantized_model.save(output_path)

    original_size = os.path.getsize(model_path)
    quantized_size = os.path.getsize(output_path)

    print(f"\nQuantization complete!")
    print(f"  - Original size: {original_size / (1024**2):.2f} MB")
    print(f"  - Quantized size: {quantized_size / (1024**2):.2f} MB")
    print(f"  - Reduction: {(1 - quantized_size/original_size) * 100:.1f}%")


def main():
    parser = argparse.ArgumentParser(
        description="Convert BERT model to CoreML format for PDFOS"
    )
    parser.add_argument(
        "--model",
        type=str,
        default="bert-base-uncased",
        help="Hugging Face model name (default: bert-base-uncased)"
    )
    parser.add_argument(
        "--output",
        type=str,
        default="bert-base-uncased.mlmodel",
        help="Output path for CoreML model"
    )
    parser.add_argument(
        "--max-seq-length",
        type=int,
        default=512,
        help="Maximum sequence length (default: 512)"
    )
    parser.add_argument(
        "--quantize",
        action="store_true",
        help="Quantize model to float16 after conversion"
    )

    args = parser.parse_args()

    # Convert model
    mlmodel = convert_bert_to_coreml(
        model_name=args.model,
        output_path=args.output,
        max_seq_length=args.max_seq_length
    )

    # Optionally quantize
    if args.quantize:
        quantized_output = args.output.replace(".mlmodel", "_quantized.mlmodel")
        quantize_model(args.output, quantized_output)


if __name__ == "__main__":
    import os
    main()
