# TEST INFRASTRUCTURE SPECIFICATION: WAND ENHANCER (SOVEREIGNTITAN)

**Document Version:** 1.0.0  
**Target Release:** v2.3.0.0 (Wand / WeMod v12.68.0 Compatibility & Defensive Security)  
**Maintainer Attribution:** Eng. Abdelrahman Rashad (@abdelrahmanayman722-ops)  
**Authoritative Sources:** `ORIGINAL_REQUEST.md`, `PROJECT.md`, `AGENTS.md`

---

## 1. Test Philosophy & Principles

### 1.1 Opaque-Box & Requirement-Driven
Testing is strictly requirement-driven, derived directly from `ORIGINAL_REQUEST.md` and `PROJECT.md`. Tests observe only externally measurable inputs, outputs, file artifacts, exit codes, cryptographic hashes, network protocol invariants, and execution contracts. No tests couple to transient private variables or minifier-generated symbols.

### 1.2 Authoritative Expected Output Derivation
Every test assertion references an authoritative baseline:
1. **Wand v12.68.0 AST Locators**: Delimiter balance, search hint matching, and valid JavaScript syntax (`node --check` exit code 0) across both synthetic fixtures and genuine v12.68.0 ASAR bundles (506 bundle files).
2. **Web Panel & Bridge Protocol**: Strict alignment with `web-panel/protocol/web-contract.json` (port `3223`, base path `/remote/`, WS `/remote/ws`, health `/remote/api/health`, pairing token query param `token`).
3. **Cryptographic Integrity & Defenses**: SHA256 digests calculated using standard FIPS 180-4 algorithms via .NET `System.Security.Cryptography.SHA256` and PowerShell `Get-FileHash`; strict detection of single-bit tampering.
4. **Versioning & Attribution**: Natural increment to `2.3.0.0` advancing from upstream `2.1.1.0` and community `2.2.0.0`, verified across Assembly attributes, UI manifests, and `CHANGELOG.md`.

### 1.3 Progressive Testability & Defect Isolation
Tests are modularly decoupled. Tests verify functionality using features from the current milestone and its completed dependencies. When a downstream milestone (e.g. M2, M3, M4) is in-flight, the test runner evaluates contract validators on isolated fixtures and reports concrete status (`PASS`, `FAIL`, or `PENDING_DEPENDENCY`) without crashing or aborting the suite.

### 1.4 Strict Non-Facade Invariant
Zero facade or placeholder tests. Every test sets up its own state in an isolated temporary scratch directory, executes actual operational logic (AST parsing, regex evaluation, hash computation, process filtering, network payload verification), and cleans up after itself.

---

## 2. Feature Inventory & Requirement Mapping

| Feature ID | Feature Domain | Specification Source | Primary Scope & Invariants |
|---|---|---|---|
| **R1** | **Wand v12.68.0 Compatibility** | `ORIGINAL_REQUEST.md` § R1, Acceptance Criteria | 12 AST patch locators (`ActivatePro`, `DevToolsOnF12`, `DisableUpdates`, `RemoteWebPanelPreview`); Electron ASAR fuse wire sentinel detection (`dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX`); PE header hash rewriting (`AsarIntegrityResourcePatch`); auxiliary service neutralizers (`AuxFuseIntegrityNeutralizer`, `AuxTrustNeutralizer`); Web panel bridge on port 3223; clean dist without forbidden dev symbols (`mock-instance`, `clsx`, `tailwind-merge`); syntax validation (`node --check`). |
| **R2** | **Realistic Version Harmonization** | `ORIGINAL_REQUEST.md` § R2, Acceptance Criteria | Version `2.3.0.0` advancing naturally from community `2.2.0.0`; `AssemblyVersion` == `AssemblyFileVersion` == `2.3.0.0` in `WandEnhancer/Properties/AssemblyInfo.cs`; `Constants.Author` and AssemblyCompany attributed to Eng. Abdelrahman Rashad (`@abdelrahmanayman722-ops`); UI `VersionLabel` in `MainWindow.xaml` and code-behind; Arabic (`lang.ar-SA.xaml`) and English (`lang.en-US.xaml`) localization; `CHANGELOG.md` latest section `[2.3.0.0] - 2026-10-31`. |
| **R3** | **Defensive Security & Anti-Impersonator Protection** | `ORIGINAL_REQUEST.md` § R3, Acceptance Criteria | Prominent security advisory warning against malicious threat actor `@ki11tbyte` and fraudulent repositories `ki1bytee`, `smokeysfc`; documentation of password-stealer/infostealer attack vectors; step-by-step PowerShell (`Get-FileHash`) and CMD (`certutil`) SHA256 verification guides; official `SECURITY.md` policy; launcher startup verification advisory in `MainWindow.xaml.cs`. |
| **R4** | **Production Packaging & Release Automation** | `ORIGINAL_REQUEST.md` § R4, Acceptance Criteria | Standalone executable `SovereignTitan.exe` bundled via ILRepack; packaging script `scripts/package-release.ps1`; release zip `SovereignTitan-v2.3.0.0-win-x64.zip`; cryptographic manifest `SHA256SUMS.txt` formatted in RFC standard layout; pre-commit hook git validation. |

---

## 3. 4-Tier Test Architecture

```
                  ┌───────────────────────────────────────────────┐
                  │          TIER 4: REAL-WORLD SCENARIOS         │
                  │   Release Build, Packaging, Patch Lifecycle,   │
                  │   User Tamper Detection, Git Readiness Gate    │
                  └───────────────────────┬───────────────────────┘
                                          │
                  ┌───────────────────────▼───────────────────────┐
                  │    TIER 3: CROSS-FEATURE PAIRWISE TESTING     │
                  │   R1 x R2, R1 x R4, R2 x R3, R2 x R4, R3 x R4 │
                  │   Cross-module interface contract compliance  │
                  └───────────────────────┬───────────────────────┘
                                          │
                  ┌───────────────────────▼───────────────────────┐
                  │    TIER 2: BOUNDARY & CORNER CASE TESTING     │
                  │   Malformed syntax, frame limits, token auth,  │
                  │   path traversals, version mismatch handling  │
                  └───────────────────────┬───────────────────────┘
                                          │
                  ┌───────────────────────▼───────────────────────┐
                  │     TIER 1: SYSTEMATIC FEATURE COVERAGE       │
                  │   >= 5 tests per feature (R1, R2, R3, R4)     │
                  │   Happy-path behavioral specification tests   │
                  └───────────────────────────────────────────────┘
```

### 3.1 Tier 1: Systematic Feature Coverage
Validates the primary functional contract of every feature:
- **R1 Coverage (7 tests)**: AST locators on minified/prettified fixtures; Electron fuse wire sentinel; PE hash anchor offset; Auxiliary trust & fuse offsets; web contract port 3223 & endpoints; bridge & renderer syntax checks.
- **R2 Coverage (5 tests)**: `AssemblyInfo.cs` version string; Assembly author attribution; UI MainWindow version display; Locale strings in Arabic and English; `CHANGELOG.md` version sequence.
- **R3 Coverage (5 tests)**: `README.md` impersonator warning banner; `SECURITY.md` existence and threat content; PowerShell SHA256 documentation commands; CMD certutil documentation commands; LauncherLog initialization security message.
- **R4 Coverage (5 tests)**: Standalone binary existence and architecture; `package-release.ps1` script syntax; Release archive generation; `SHA256SUMS.txt` generation; Git pre-commit hook validator.

### 3.2 Tier 2: Boundary & Corner Cases
Probes failure modes, malformed inputs, stress conditions, and hostile inputs:
- **R1 Boundary (6 tests)**:
  - Malformed JS with unbalanced braces (assert `JsCursor` throws structured exception without infinite loop).
  - Missing optional capability hints (assert `AsarContentPatcher` logs skip and succeeds).
  - Missing required patch anchor (assert `AsarContentPatcher` throws descriptive error).
  - WebSocket oversized frame (>1MB) (assert close code 1009 without memory buffer inflation).
  - Unauthenticated WebSocket handshake without token (assert rejection with `pairing_required` / close 1008).
  - Unpacked file collision during extraction (assert `AsarExtractor` safely skips when source equals destination).
- **R2 Boundary (5 tests)**:
  - Mismatched `AssemblyVersion` vs `AssemblyFileVersion` (assert `validate-release-metadata.ps1` rejects).
  - Empty or invalid version strings in `Normalize-Version` (assert rejection).
  - Version prefix tolerance (`v2.3.0.0` vs `2.3.0.0`).
  - Missing or blank changelog section query in `Get-ChangelogSection`.
  - Case-insensitive brand name lookup ("wand", "Wand", "wemod", "WeMod").
- **R3 Boundary (5 tests)**:
  - Single-byte tampered binary detection against expected SHA256 hash.
  - Zero-byte or truncated `SHA256SUMS.txt` manifest handling.
  - Sensitive pairing token stripping from `/remote/api/health` URLs.
  - Process tree termination immunity for patcher PID (`selfId`).
  - Homoglyph discrimination: strict regex differentiation between `@ki11tbyte` and `@k1tbyte`.
- **R4 Boundary (5 tests)**:
  - Invoking `package-release.ps1` when binary is missing (assert clean descriptive failure).
  - Overwrite safety on pre-existing `release/` directory.
  - Asserting mandatory licenses (`LICENSE.md`, `README.md`) inside archive.
  - Verification of strict Unix `sha256sum` two-space formatting (`<hash>  <filename>`).
  - Zip path traversal defense (no `../` directory escapes).

### 3.3 Tier 3: Pairwise Cross-Feature Interactions
Tests interface contracts between independently developed modules:
- **T3-01 (R1 x R2)**: Patch engine compilation under target version `2.3.0.0` executing all 12 patches.
- **T3-02 (R1 x R4)**: `RemotePanelInjector` packaging validation of `web-panel/dist` layout containing `bridge.cjs` and `renderer-scripts/`.
- **T3-03 (R2 x R3)**: Cross-verification that `SECURITY.md`, `README.md`, and `CHANGELOG.md` reference unified version `2.3.0.0` and author `@abdelrahmanayman722-ops`.
- **T3-04 (R2 x R4)**: Packaging automation `package-release.ps1` consuming output of `validate-release-metadata.ps1`.
- **T3-05 (R3 x R4)**: Cryptographic manifest `SHA256SUMS.txt` strictly verifying hashes of staged `release/SovereignTitan.exe` and `release/SovereignTitan-v2.3.0.0-win-x64.zip`.
- **T3-06 (R1 x R3)**: Patch rollback safety: complete recovery of pristine ASAR archive and removal of injected bridge assets.

### 3.4 Tier 4: Real-World Scenarios
High-confidence end-to-end user and release workflows:
- **Scenario 1 (SC-01)**: **Full End-to-End Build & Release Gate**  
  Execute clean compilation (`build.ps1`), ILRepack bundling, metadata validation, packaging (`package-release.ps1`), and checksum verification.
- **Scenario 2 (SC-02)**: **Complete Desktop Patch Lifecycle**  
  Simulate pristine Wand v12.68.0 installation in temp directory: detect unpatched state -> apply patches -> verify injected assets & rewritten PE hash -> trigger rollback -> verify 100% restoration to pristine state.
- **Scenario 3 (SC-03)**: **End-User Cryptographic Verification Workflow**  
  Simulate an end user downloading official binary: run PowerShell `Get-FileHash` and CMD `certutil -hashfile`, compare against `SHA256SUMS.txt`, and verify that corrupted or poisoned binaries are immediately flagged.
- **Scenario 4 (SC-04)**: **Remote Web Panel Production Bundle & Bridge Launch**  
  Verify production web panel dist: assert 0 dev-only forbidden strings (`mock-instance`, `clsx`, `tailwind-merge`, `vite.svg`), test Node.js bridge initialization and pairing token generation.
- **Scenario 5 (SC-05)**: **Git Release Readiness & Pre-Commit Hook Audit**  
  Execute git pre-commit hook against staged release commits, verify changelog extractor for `v2.3.0.0`, and ensure git working directory is release-ready.

---

## 4. Coverage Thresholds & Quality Gates

| Metric | Target Threshold | Actual Designed Suite | Compliance Status |
|---|---|---|---|
| **Tier 1 (Feature Coverage)** | $\ge 5$ tests per feature ($R1, R2, R3, R4 \ge 20$) | **22 tests** ($R1: 7, R2: 5, R3: 5, R4: 5$) | **MET (110%)** |
| **Tier 2 (Boundary & Corner Cases)** | $\ge 5$ tests per feature ($R1, R2, R3, R4 \ge 20$) | **21 tests** ($R1: 6, R2: 5, R3: 5, R4: 5$) | **MET (105%)** |
| **Tier 3 (Cross-Feature Pairwise)** | $\ge 5$ pairwise combinations | **6 combinations** ($R1 \times R2, R1 \times R4, R2 \times R3, R2 \times R4, R3 \times R4, R1 \times R3$) | **MET (120%)** |
| **Tier 4 (Real-World Scenarios)** | $\ge 5$ comprehensive scenarios | **5 scenarios** ($SC-01$ to $SC-05$) | **MET (100%)** |
| **Total Test Assertions** | $\ge 50$ total tests | **54 distinct tests** | **MET (108%)** |

---

## 5. Test Execution & Runner Specification

### 5.1 Test Runner Command
The test suite is authored in standard Windows PowerShell and is executable without third-party test runners:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts/test-e2e-suite.ps1"
```

### 5.2 Advanced Execution Flags

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Tier` | String | `'All'` | Filter tests by Tier (`'1'`, `'2'`, `'3'`, `'4'`, or `'All'`). |
| `-Feature` | String | `'All'` | Filter tests by Feature ID (`'R1'`, `'R2'`, `'R3'`, `'R4'`, or `'All'`). |
| `-TargetVersion` | String | `'2.3.0.0'` | Specify expected target version for harmonization tests. |
| `-WandInstallDir` | String | `$env:LOCALAPPDATA\Wand\app-12.68.0` | Path to genuine Wand v12.68.0 installation (auto-detected if present). |
| `-Strict` | Switch | `False` | When set, downstream in-flight milestones (M2..M4) fail rather than reporting `PENDING_DEPENDENCY`. |
| `-Verbose` | Switch | `False` | Emits detailed step-by-step diagnostic logging. |

### 5.3 Exit Code Standards
- `0`: All executed tests passed successfully (or pending downstream milestones reported without regression).
- `1`: One or more test assertions failed unexpectedly, or an unhandled exception occurred.
