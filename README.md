<div align="center">

![logo](./assets/icon.svg)

# SovereignTitan (سوفيرين تيتان)

### The Sovereign Cyberpunk Modding Engine & Remote Telemetry HUD for Wand / WeMod
**Authored & Engineered by Eng. Abdelrahman Rashad ([@abdelrahmanayman722-ops](https://github.com/abdelrahmanayman722-ops))**

[![License](https://img.shields.io/badge/License-Apache--2.0-00f0ff?style=flat-square)](LICENSE.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%20x64-0d1527?style=flat-square&logo=windows)](https://microsoft.com)
[![Engine](https://img.shields.io/badge/.NET-Framework%204.8%20%7C%20WPF-163252?style=flat-square)](https://dotnet.microsoft.com)
[![Web Panel](https://img.shields.io/badge/Remote%20HUD-Preact%20%7C%20Tailwind-00f0ff?style=flat-square)](./web-panel)

</div>

---

> [!CAUTION]
> ### 🚨 CRITICAL COMMUNITY DEFENSE ADVISORY: MALICIOUS TYPOSQUATTING & INFOSTEALER THREAT
> 
> **A malicious threat actor (`@ki11tbyte`) and fraudulent repositories (`ki1bytee`, `smokeysfc`) are actively targeting the WeMod / Wand modding community by distributing Trojanized binaries.**
> 
> #### ⚠️ Threat Summary & Attack Vector
> - **Attacker Profile**: Typosquatting / visual homoglyph account `@ki11tbyte` (duplicating `1`s to mimic the original developer `k1tbyte`) and associated rogue repos `ki1bytee` and `smokeysfc`.
> - **Malware Payload**: Precompiled `.exe` binaries from these unauthorized sources contain **password-stealing infostealer malware (RedLine / Lumma / Vidar variants)** designed to silently harvest:
>   - Web browser saved passwords, autofill data, credit cards, and active session cookies
>   - Discord authorization tokens and Telegram session tokens
>   - Steam credentials, EA/Epic login tokens, and game accounts
>   - Cryptocurrency desktop wallet data (MetaMask, Phantom, Exodus, etc.)
> - **Distribution Vectors**: Fake YouTube installation tutorials, deceptive Discord links, unofficial third-party download portals, and typosquatted GitHub forks promoting "1-click pre-cracked VIP" downloads.
> 
> #### 🛡️ Zero-Trust Security Directive
> 1. **Never download or execute precompiled binaries** from unverified forks, YouTube descriptions, Telegram channels, or unofficial mirrors.
> 2. **Official Source**: The only authentic codebase is maintained by **Eng. Abdelrahman Rashad** at [`github.com/abdelrahmanayman722-ops/Wand-Enhancer`](https://github.com/abdelrahmanayman722-ops/Wand-Enhancer).
> 3. **Build From Source**: Whenever possible, compile the binary locally using `build.cmd` with clean, inspected source code.
> 4. **Cryptographic Hash Verification**: If downloading official releases, **always verify the SHA256 checksum** against `SHA256SUMS.txt` before execution:
> 
> **PowerShell:**
> ```powershell
> (Get-FileHash -Path .\SovereignTitan.exe -Algorithm SHA256).Hash
> ```
> 
> **Command Prompt (CMD):**
> ```cmd
> certutil -hashfile SovereignTitan.exe SHA256
> ```
> 
> *For responsible disclosure protocols and full threat intelligence, consult [SECURITY.md](SECURITY.md).*

---

## ⚡ What is SovereignTitan?

**SovereignTitan** is an elite, client-side reverse-engineering and UX interoperability suite built for Wand and WeMod. It transforms the desktop client into a sovereign cyberpunk command center and integrates an ultra-low-latency mobile remote HUD, real-time diagnostic self-healing, and zero-fail compatibility with Wand releases **12.61 through 12.68.0 and beyond**.

---

## 💫 Core Features & Architectural Capabilities

### 1. 🛡️ Wand 12.61 / 12.62+ Zero-Fail ASAR Integrity Engine
- **In-Place PE Hash Rewriting (`AsarIntegrityResourcePatch`):** Dynamically calculates the SHA-256 hash of the modified `app.asar` and updates `Wand.exe`'s internal `ElectronAsar\Integrity` PE resource on disk without breaking executable signatures.
- **Auxiliary Integrity Neutralization (`AuxFuseIntegrityNeutralizer`):** Neutralizes the 3-fold runtime security fuses in `WandAuxiliaryService.exe` to allow seamless trainer library injection.
- **Resilient Method Sentinel Discovery (`DotNetImage`):** Employs robust string sentinel searching for method alignment offsets, resilient to code obfuscation across updates.
- **Fail-Safe I/O (`FileRetry` & `ClipboardRetry`):** Retries locked file operations with exponential backoff and protects against native Windows clipboard errors (`CLIPBRD_E_CANT_OPEN`).

### 2. 🩺 Integrated Auto-Doctor & Self-Healing Fixer
- **One-Click Diagnostic Suite:** Located directly on the desktop log console and Settings popup.
- **Automated Process Lock Release:** Detects and cleanly terminates hung background `WeMod` / `Wand` process trees locking critical files.
- **Permissions Restorer:** Automatically strips restrictive `ReadOnly` attributes from installation folders, ASAR binaries, and backup archives.
- **Firewall Rule Provisioning:** Configures Windows Firewall inbound rules on port `3223` for seamless LAN remote control.
- **Backup Verification:** Confirms the health of pristine `app.asar.backup` and `app.asar.unpacked.backup` before any patching occurs.

### 3. 📊 Live Mobile Hardware & Telemetry HUD
- **Real-Time Latency Ping:** Live round-trip write acknowledgment monitoring (sub-10ms loopback).
- **CPU & RAM Monitor:** Streams live host CPU load percentage with dynamic color-coded gradient indicators and active memory utilization directly to the mobile drawer.
- **Cyberpunk Obsidian & Neon Cyan Visual Aesthetic:** High-end dark glass interface styled with deep obsidian (`#070A13`), luminous neon cyan accents (`#00F0FF`), glowing borders, and smooth responsiveness.

### 4. 🌐 Mobile Remote Web Panel & Offline PWA
- **Progressive Web App (PWA):** Installable on Android & iOS home screens with offline Service Worker (`sw.js`).
- **Tactile Touch Haptics (`navigator.vibrate`):** Multi-tier haptic vibration responses across toggles, step buttons, and quick actions.
- **JSON Cheat Presets Engine:** Schema-validated export and import of game cheats with automatic ID deduplication.
- **Ephemeral Pairing Tokens:** Cryptographically random session tokens (`?token=...`) embedded in QR codes to prevent unauthorized LAN connections.

### 5. 🇸🇦 Native Bilingual Localization (العربية / English)
- Full native Arabic (العربية) translation with bi-directional RTL layout switching across both the WPF desktop interface and the mobile remote panel.
- 6-tier Arabic plural rules supported in Lingui catalogs.

---

## 🏆 Upstream Impact & Community Continuation

Key architectural components originally authored in [PR #328](https://github.com/k1tbyte/Wand-Enhancer/pull/328) were adopted into the community fork [**Glitxhhh/WandMagica** v2.2.0.0](https://github.com/Glitxhhh/WandMagica/releases/tag/2.2.0.0), including:
- Native Arabic localization dictionaries (`lang.ar-SA.xaml`)
- Mobile touch haptics engine (`haptics.ts`)
- PWA manifest and mobile viewport metadata
- Ephemeral pairing token bridge security
- Schema-validated JSON presets engine

---

## 🛠️ Building SovereignTitan from Source

Building requires a local Windows development environment:

### Prerequisites:
- Windows 10/11 x64
- [.NET Framework 4.8 Developer Pack](https://dotnet.microsoft.com/download/dotnet-framework/net48)
- [Node.js](https://nodejs.org/) (v18+) & [pnpm](https://pnpm.io/)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with MSBuild (or Microsoft Build Tools)

### Build Command:
```cmd
build.cmd
```
The build pipeline executes:
1. Web panel typecheck, Vite asset compilation, and bridge bundling (`build:bridge`).
2. Vitest test suite verification across 17 test suites (61 unit & integration tests).
3. MSBuild compilation in `Release` configuration.
4. `ILRepack` single-file assembly merging, packing all DLLs into a standalone `SovereignTitan.exe`.
5. Desktop regression test (`scripts/test-desktop.ps1`) and structural JavaScript patch locator verification (`scripts/test-patch-locators.ps1`).

---

## 📱 Using the Mobile Remote Web Panel

1. Connect your PC and phone to the same local Wi-Fi network.
2. In **SovereignTitan**, hover over the **Connect** button in the header.
3. Scan the generated QR code with your phone camera.
4. Tap **Add to Home Screen** to install the full-screen PWA with tactile haptics.
5. If the connection is blocked, click **Auto-Doctor** or open **Settings → Configure Windows Firewall (Port 3223)**.

---

## 📜 License & Credits

- Licensed under the [Apache-2.0 License](LICENSE.md).
- Original open-source upstream enhancements by `k1tbyte`.
- Modernized flagship architecture, Auto-Doctor, Telemetry HUD, and Wand 12.68.0+ fuses by **Eng. Abdelrahman Rashad ([@abdelrahmanayman722-ops](https://github.com/abdelrahmanayman722-ops))**.

---

> **Legal Disclaimer:**  
> This software is an independent interoperability tool designed solely for local UI customization, research, and accessibility. It does not distribute proprietary binaries, modify remote servers, or bypass server-side account authentication.
