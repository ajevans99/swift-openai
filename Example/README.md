# Example `swift-openai` CLI

[![Example CLI - Swift](https://github.com/ajevans99/swift-openai/actions/workflows/example-swift.yml/badge.svg)](https://github.com/ajevans99/swift-openai/actions/workflows/example-swift.yml)

This is a simple command-line interface example that demonstrates how to use the `swift-openai` package. It provides a basic implementation showing how to interact with OpenAI's API using Swift, including making API calls and handling responses.

## Setup

1. Copy the environment sample file:
```bash
cp .env.sample .env
```

2. Get your API keys:
   - [OpenAI API Key](https://platform.openai.com/api-keys)
   - [OpenWeather API Key (optional for `weather` command)](https://home.openweathermap.org/api_keys)

3. Add your API keys to the `.env` file:
```env
OPENAI_API_KEY=your_openai_key_here
OPENWEATHER_API_KEY=your_openweather_key_here
```

## Usage

```bash
swift run OpenAIExample
```

The CLI will use your API keys from the `.env` file to demonstrate basic functionality with the OpenAI and OpenWeather APIs.
