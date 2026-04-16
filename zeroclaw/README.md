# ZeroClaw Add-on

ZeroClaw is an AI Assistant for Home Assistant that provides LLM-powered autonomy and integration.

## 🛠️ Initial Setup & Onboarding

ZeroClaw requires some initial configuration (like setting up your LLM providers and autonomy settings). We've included a native, interactive terminal wizard to walk you through this!

1. Install the **Advanced SSH & Web Terminal** add-on in Home Assistant if you haven't already.
2. Open your terminal and run the following command to launch the ZeroClaw onboarding wizard:
   ```bash
   docker exec -it $(docker ps --format '{{.Names}}' | grep zeroclaw | head -n 1) zc-onboard
   ```
   *(This command automatically finds the correct container name for you!)*
3. Follow the interactive prompts to configure your agent.
4. **Crucial:** Once you finish the wizard, go to **Settings > Add-ons > ZeroClaw** and click **Restart** so the web UI can load your fresh configuration!

**Advanced Users:** Your configuration is safely stored at `/config/zeroclaw/config.toml` (by default). You can edit this manually at any time using the Home Assistant File Editor or VS Code add-ons!

---

## ☕ Support the project

If you find ZeroClaw useful and would like to support its development, you can buy me a coffee!

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/paul.crafts)
