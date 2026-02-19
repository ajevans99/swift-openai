# Python SDK Streaming Benchmark

This example uses the official OpenAI Python SDK to stream Responses API events for image generation and print timing milestones.

## Setup

```bash
cd /Users/ajevans/Documents/swift-openai/Example/python-sdk-benchmark
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Set your API key:

```bash
export OPENAI_API_KEY=your_key_here
```

## Run

```bash
python stream_image_benchmark.py "Create an image of a butterfly in a cool setting."
```

Optional flags:

```bash
python stream_image_benchmark.py "Prompt" \
  --model gpt-5.2 \
  --image-model gpt-image-1.5 \
  --partial-images 1 \
  --output-dir generated-images/python-sdk
```

The script logs:

- Event arrival time (`+seconds from start`)
- Event type
- Serialized event payload size in bytes
- Paths of saved partial/final images

This is intended for side-by-side timing comparison with:

```bash
cd /Users/ajevans/Documents/swift-openai/Example
swift run OpenAIExample image-streaming "Create an image of a butterfly in a cool setting."
```
