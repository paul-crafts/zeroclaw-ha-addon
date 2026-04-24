# ZeroClaw Add-on Documentation

ZeroClaw is an LLM-powered AI assistant for Home Assistant. This document provides detailed information on configuration and usage.

## Installation

1. Add the ZeroClaw repository to your Home Assistant instance.
2. Install the ZeroClaw Add-on from the Add-on Store.
3. Start the Add-on.

## Configuration

ZeroClaw uses a `config.toml` file for its main settings. This file is automatically created during the onboarding process.

### Options

| Name | Type | Description |
| :--- | :--- | :--- |
| `config_dir` | `string` | The directory where ZeroClaw stores its configuration and data. Default: `/config` |

## Onboarding Wizard

The built-in terminal allows you to run the onboarding wizard directly.
1. Click **Open Web UI** on the Add-on page.
2. Choose **Terminal**.
3. Type `zc-onboard` and press Enter.

The wizard will guide you through:
- Setting up LLM providers (OpenAI, Anthropic, etc.).
- Configuring Home Assistant integration.
- Setting autonomy levels for your AI agent.

## Ingress Interface

The Ingress interface provides three main areas:
- **Landing Page**: The entry point with links to the Dashboard and Terminal.
- **Dashboard**: The main interaction interface for ZeroClaw.
- **Terminal**: A full-featured web terminal for system management.

## Troubleshooting

### Add-on won't start
Check the **Logs** tab in the Home Assistant Add-on page. Look for errors related to configuration or network ports.

### Terminal shows "Connection Refused"
Ensure the addon is fully started. It may take a few seconds for `ttyd` and `nginx` to initialize.

### Onboarding changes not applying
The ZeroClaw daemon needs to be restarted to pick up changes from the onboarding wizard. The addon initialization script handles this, but you can also manually restart the addon.

## Advanced: Manual Configuration

If you prefer to edit the configuration manually, you can find it at `/addon_configs/zeroclaw/config.toml`. Use the **VS Code** or **File Editor** add-ons to make changes.

Example `config.toml` snippet:
```toml
[llm]
provider = "openai"
model = "gpt-4-turbo"

[autonomy]
level = "medium"
```

---
For more information, visit the [official ZeroClaw repository](https://github.com/zeroclaw-labs/zeroclaw).
