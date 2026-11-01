# Security Policy & Defensive Countermeasures

## 🛡️ Supported Versions

Only official releases maintained by **Eng. Abdelrahman Rashad ([@abdelrahmanayman722-ops](https://github.com/abdelrahmanayman722-ops))** receive active security updates, vulnerability remediations, and verified checksum manifests.

| Version | Supported | Status / Advisory Notes |
|:---:|:---:|:---|
| **2.3.0.0** | :white_check_mark: | **Current Official Production Release** (Wand v12.68.0 certified; active defensive countermeasures) |
| 2.2.0.0 | :white_check_mark: | Community baseline release (Glitxhhh/WandMagica adoption) |
| < 2.2.0.0 | :x: | Unsupported / Deprecated upstream versions |
| Unofficial Forks | :x: | **Untrusted / High Risk** (subject to typosquatting and infostealer malware attacks) |

---

## 🚨 Threat Intelligence Advisory: Malicious Typosquatting Campaign

### Threat Actor Profile
- **Primary Malicious Identity**: `@ki11tbyte` (visual homoglyph / typosquatting mimicking original author `@k1tbyte` by duplicating the digit `1`).
- **Fraudulent Repositories**: `ki1bytee`, `smokeysfc`, and related burner accounts.
- **Threat Category**: Infostealer Trojan Distribution / Social Engineering / Identity Impersonation.

### Attack Vector & Malware Payload Analysis
The threat actor `@ki11tbyte` creates deceptive repository forks and distributes precompiled Windows `.exe` executables disguised as "pre-cracked 1-click mod launchers" or "VIP bypasses". 

Security auditing and binary analysis have revealed that these rogue binaries bundle malicious **Infostealer Trojans** (variants of RedLine, Vidar, and Lumma Stealer). Upon execution, these payloads execute the following hostile actions in the background:
1. **Browser Credential Extraction**: Silently dumps SQLite credential stores, autofill databases, credit card tokens, and session cookies from Google Chrome, Microsoft Edge, Brave, Opera, and Mozilla Firefox.
2. **Session & Token Hijacking**: Scrapes local storage for Discord authorization tokens (`Local State` DPAPI master key decryption) and Telegram desktop session folders (`tdata`).
3. **Gaming & Platform Credentials**: Harvests Steam configuration and authorization tokens (`ssfn*`), Epic Games launcher tokens, and EA credentials.
4. **Cryptocurrency Wallet Exfiltration**: Extracts browser wallet extensions (MetaMask, Phantom, Coinbase Wallet) and desktop wallet files (Exodus, Electrum).
5. **C2 Beaconing**: Compresses the harvested credentials into password-protected archives and exfiltrates them via encrypted HTTP POST or Telegram Bot APIs to command-and-control servers.

### Distribution Tactics (TTPs)
- Publishing fake YouTube tutorials with direct download links in video descriptions or pinned comments.
- Utilizing automated bot networks to falsely inflate GitHub star and fork counts on malicious repositories.
- Infiltrating public modding and cheat Discord servers, posting download links framed as "fixed updates".

### Immediate Remediation If Compromised
If you or anyone in your team has executed an untrusted binary from `@ki11tbyte`, `ki1bytee`, `smokeysfc`, or unverified YouTube links:
1. **Immediately Disconnect**: Disconnect the compromised system from the local network and internet.
2. **Terminate Malicious Processes**: Inspect Task Manager for suspicious background processes spawned from `%APPDATA%`, `%LOCALAPPDATA%`, or `%TEMP%`.
3. **Revoke Active Sessions & Rotate Credentials**: From a separate, clean device:
   - Reset passwords for all sensitive accounts (Email, GitHub, Steam, Discord, Banking).
   - Invalidate all active browser sessions ("Log out of all devices").
   - Enable hardware security keys (FIDO2/WebAuthn) or time-based one-time password (TOTP) 2FA.
4. **Clean Installation**: Perform an offline malware scan with Windows Defender / Malwarebytes, or ideally perform a clean operating system reinstallation.

---

## 🔒 Cryptographic Release Verification

To guarantee that downloaded release binaries are genuine, unadulterated, and free from tampering, **always verify the SHA256 checksum** against the official `SHA256SUMS.txt` manifest before executing any binary.

### Method 1: Windows PowerShell (Recommended)

1. Open PowerShell in the folder containing `SovereignTitan.exe`.
2. Compute the SHA256 hash:
   ```powershell
   Get-FileHash -Path .\SovereignTitan.exe -Algorithm SHA256 | Format-List
   ```
3. Compare the output hash with the published value in `SHA256SUMS.txt` on the official GitHub Release page.

#### Automated Check in PowerShell:
```powershell
$expectedHash = "c49e30de5662fcf07e0a4a2d422037271e5fa4b70ad1c39f3ab5400d15090153" # Official v2.3.0.0 SHA256
$calculatedHash = (Get-FileHash -Path .\SovereignTitan.exe -Algorithm SHA256).Hash
if ($calculatedHash -eq $expectedHash) {
    Write-Host "[+] Checksum VERIFIED: Authentic binary from Eng. Abdelrahman Rashad." -ForegroundColor Green
} else {
    Write-Host "[!] SECURITY ALERT: Checksum MISMATCH! DO NOT EXECUTE THIS FILE!" -ForegroundColor Red
}
```

### Method 2: Windows Command Prompt (CMD)

```cmd
certutil -hashfile SovereignTitan.exe SHA256
```
Compare the hexadecimal string against the published release hash.

---

## 🛡️ Zero-Trust Architecture: Build from Source

SovereignTitan follows a strict **zero-trust model**. The safest way to consume this software is to build directly from audited source code using the reproducible build pipeline:

```cmd
git clone https://github.com/abdelrahmanayman722-ops/Wand-Enhancer.git
cd Wand-Enhancer
build.cmd
```

The `build.cmd` script:
- Compiles the web panel UI and Electron bridge with strict type-checking and zero telemetry dependencies.
- Runs the test suites (Biome linter, Vitest unit tests, desktop regression tests, and AST locator integrity suites).
- Assembles the standalone executable with ILRepack directly on your machine.

---

## 📢 Responsible Disclosure Guidelines

We welcome responsible security research and vulnerability disclosures. If you discover a security flaw, AST injection loophole, bridge token exposure, or new impersonation campaign:

1. **Do Not File Public Issues**: Please avoid filing public GitHub issues for unpatched security vulnerabilities.
2. **Private Reporting**:
   - Submit a private vulnerability report via **GitHub Security Advisories** on the official repository:  
     `https://github.com/abdelrahmanayman722-ops/Wand-Enhancer/security/advisories/new`
   - Or contact lead maintainer **Eng. Abdelrahman Rashad** directly via profile contact details: [`@abdelrahmanayman722-ops`](https://github.com/abdelrahmanayman722-ops).
3. **Report Details**: Include a clear description of the vulnerability, step-by-step reproduction steps, proof-of-concept (PoC) code if applicable, and potential impact assessment.
4. **Response SLA**:
   - Initial triage and acknowledgment: within **24–48 hours**.
   - Remediation patch and coordinated disclosure: typically within **7–14 business days**.
