<h1 align="center">🦾 ZeroClaw Home Assistant Add-on</h1>

<p align="center">
  <strong>The powerful, autonomous AI assistant for your Home Assistant ecosystem.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.5.20-6366f1?style=for-the-badge" alt="Version">
  <a href="https://github.com/paul-crafts/zeroclaw-ha-addon/blob/main/LICENSE"><img src="https://img.shields.io/github/license/paul-crafts/zeroclaw-ha-addon?style=for-the-badge&color=818cf8" alt="License"></a>
  <a href="https://my.home-assistant.io/redirect/supervisor_addon/?addon=zeroclaw&repository_url=https%3A%2F%2Fgithub.com%2Fpaul-crafts%2Fzeroclaw-ha-addon"><img src="https://img.shields.io/badge/Home%20Assistant-Add--on-blue?style=for-the-badge&logo=home-assistant" alt="HA Addon"></a>
</p>

---

## 🌟 Overview

ZeroClaw is a next-generation AI assistant designed to run locally (or via cloud LLMs) within your Home Assistant setup. Unlike traditional voice assistants, ZeroClaw leverages Large Language Models (LLMs) to provide true autonomy, complex reasoning, and seamless integration with your smart home entities.

### Key Features

- **🚀 Ingress Integrated**: Access the ZeroClaw dashboard and terminal directly from the Home Assistant sidebar.
- **🐚 Built-in Web Terminal**: No more `docker exec`! Run onboarding and system commands via the integrated `ttyd` terminal.
- **🤖 LLM Agnostic**: Support for OpenAI, Anthropic, OpenRouter, and local models (via Ollama or LocalAI).
- **⚡ High Performance**: Built on a robust Rust-based core for maximum efficiency.
- **🛡️ Secure**: Runs as a protected Home Assistant addon with proper signal handling and process supervision.

---

## 🚀 Getting Started

### 1. Installation

1. Go to your Home Assistant instance.
2. Navigate to **Settings > Add-ons > Add-on Store**.
3. Click the three dots in the top right and select **Repositories**.
4. Add `https://github.com/paul-crafts/zeroclaw-ha-addon` to your repositories.
5. Search for **ZeroClaw** and click **Install**.

### 2. Onboarding

ZeroClaw features an interactive onboarding wizard to help you set up your API keys and preferences.

1. Start the ZeroClaw addon.
2. Click **Open Web UI**.
3. Select the **Terminal** option from the landing page.
4. Run the following command in the terminal:
   ```bash
   zc-onboard
   ```
5. Follow the prompts to configure your agent.

### 3. Usage

Once configured, you can access the ZeroClaw Dashboard via the Ingress interface to interact with your AI assistant.

---

## 🛠️ Advanced Configuration

Your configuration is stored in `/addon_configs/zeroclaw/config.toml`. You can edit this file manually using the **File Editor** or **VS Code** addons if you need to fine-tune specific settings.

### Custom Environment Variables
You can pass custom environment variables to the ZeroClaw daemon by adding them to the addon configuration.

---

## 🧪 Quality Assurance

We take stability seriously. This addon includes:
- **Process Supervision**: Automatic recovery if the daemon or proxy fails.
- **Nginx Reverse Proxy**: Secure and efficient routing of all traffic.
- **Automated CI**: Every release is validated against multiple architectures (`amd64`, `aarch64`, `armv7`).

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue if you find a bug or have a feature request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ☕ Support the project

If you find ZeroClaw useful and would like to support its development, you can buy me a coffee!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/paul.crafts)

---
<p align="center">Made with ❤️ for the Home Assistant Community</p>
