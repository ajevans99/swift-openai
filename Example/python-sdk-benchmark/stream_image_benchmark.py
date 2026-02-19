#!/usr/bin/env python3
"""Compare Responses image-generation streaming timing with official OpenAI Python SDK."""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

from openai import OpenAI


def get_field(value: Any, name: str, default: Any = None) -> Any:
    if isinstance(value, dict):
        return value.get(name, default)
    return getattr(value, name, default)


def to_jsonable(value: Any) -> Any:
    if isinstance(value, dict):
        return value
    if hasattr(value, "model_dump"):
        return value.model_dump(mode="json", exclude_none=True)
    if hasattr(value, "to_dict"):
        return value.to_dict()
    return value


def payload_size_bytes(event: Any) -> int:
    if hasattr(event, "model_dump_json"):
        return len(event.model_dump_json(exclude_none=True).encode("utf-8"))
    try:
        raw = json.dumps(to_jsonable(event), separators=(",", ":"), ensure_ascii=False)
        return len(raw.encode("utf-8"))
    except Exception:
        return -1


def decode_to_file(base64_data: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(base64.b64decode(base64_data))


def build_input(prompt: str) -> list[dict[str, Any]]:
    return [
        {
            "type": "message",
            "role": "user",
            "content": [{"type": "input_text", "text": prompt}],
        }
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Benchmark Responses image-generation streaming via official Python SDK."
    )
    parser.add_argument("prompt", help="Prompt to send to the Responses API.")
    parser.add_argument("--model", default="gpt-5.2", help="Responses model.")
    parser.add_argument(
        "--image-model",
        default="gpt-image-1.5",
        help="Model for the image_generation tool.",
    )
    parser.add_argument(
        "--partial-images",
        type=int,
        default=1,
        help="Number of partial images requested (0-3).",
    )
    parser.add_argument(
        "--quality",
        default="medium",
        choices=["low", "medium", "high", "auto"],
        help="Image tool quality.",
    )
    parser.add_argument(
        "--moderation",
        default="low",
        choices=["low", "auto"],
        help="Image tool moderation.",
    )
    parser.add_argument(
        "--output-dir",
        default="generated-images/python-sdk",
        help="Directory where partial/final images are written.",
    )
    parser.add_argument(
        "--no-save-images",
        action="store_true",
        help="Do not decode and save partial/final images.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("Missing OPENAI_API_KEY", file=sys.stderr)
        return 1

    client = OpenAI(api_key=api_key)
    if not hasattr(client.responses, "stream"):
        print(
            "This installed openai package does not support responses.stream. Upgrade with: pip install -U openai",
            file=sys.stderr,
        )
        return 1

    output_dir = Path(args.output_dir).expanduser().resolve()
    partial_images = max(0, min(3, args.partial_images))

    tools = [
        {
            "type": "image_generation",
            "model": args.image_model,
            "quality": args.quality,
            "moderation": args.moderation,
            "partial_images": partial_images,
        }
    ]

    print("Starting benchmark")
    print(f"  model: {args.model}")
    print(f"  image model: {args.image_model}")
    print(f"  partial_images: {partial_images}")
    print(f"  output dir: {output_dir}")

    start = time.monotonic()
    first_seen: dict[str, float] = {}
    response_id: str | None = None
    final_response: Any | None = None

    try:
        with client.responses.stream(
            model=args.model,
            input=build_input(args.prompt),
            tools=tools,
        ) as stream:
            for event in stream:
                now = time.monotonic()
                elapsed = now - start

                event_type = get_field(event, "type", "<unknown>")
                first_seen.setdefault(event_type, elapsed)
                size = payload_size_bytes(event)
                size_display = f"{size}" if size >= 0 else "unknown"
                print(f"[+{elapsed:8.2f}s] {event_type} bytes={size_display}")

                event_response = get_field(event, "response")
                if response_id is None and event_response is not None:
                    response_id = get_field(event_response, "id", None)
                    if response_id:
                        print(f"  response_id={response_id}")

                if event_type == "response.image_generation_call.partial_image":
                    image_id = get_field(event, "item_id", "unknown")
                    index = get_field(event, "partial_image_index", 0)
                    image_b64 = get_field(event, "partial_image_b64", None)
                    if (
                        image_b64
                        and not args.no_save_images
                        and isinstance(index, int)
                        and isinstance(image_id, str)
                    ):
                        path = output_dir / f"{image_id}-partial-{index}.png"
                        decode_to_file(image_b64, path)
                        print(f"  saved partial image: {path}")

            final_response = stream.get_final_response()
    except Exception as error:
        elapsed = time.monotonic() - start
        print(f"[+{elapsed:8.2f}s] stream failed: {error}", file=sys.stderr)
        return 2

    total_elapsed = time.monotonic() - start
    print(f"[+{total_elapsed:8.2f}s] stream finished")

    if response_id is None:
        response_id = get_field(final_response, "id", None)

    if response_id:
        print(f"Final response id: {response_id}")

    if final_response is not None and not args.no_save_images:
        outputs = get_field(final_response, "output", []) or []
        saved_any = False
        for output_item in outputs:
            if get_field(output_item, "type") != "image_generation_call":
                continue
            image_id = get_field(output_item, "id", "image_generation_call")
            result_b64 = get_field(output_item, "result", None)
            status = get_field(output_item, "status", "<unknown>")
            if isinstance(result_b64, str) and result_b64:
                path = output_dir / f"{image_id}-final.png"
                decode_to_file(result_b64, path)
                print(f"Saved final image ({status}): {path}")
                saved_any = True
        if not saved_any:
            print("No final image payload found on final response.")

    print("\nMilestones (first occurrence):")
    for event_type, elapsed in sorted(first_seen.items(), key=lambda item: item[1]):
        print(f"  {event_type}: +{elapsed:.2f}s")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
