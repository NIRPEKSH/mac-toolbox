# Security Policy

## Our commitment

Every script in Mac Toolbox follows these security principles:

1. **Runs locally only** — no script sends data over the network. Everything runs on your machine, processes your files locally, and stays on your machine.
2. **No telemetry** — we don't collect usage data, analytics, or any form of tracking.
3. **No credentials** — no script asks for passwords, API keys, or personal information.
4. **Transparent** — every script is fully readable shell code. No binaries, no obfuscated code, no minification. You can read exactly what it does before running it.
5. **Reversible** — scripts that modify files always preserve the originals in a backup folder.

## Reporting a vulnerability

If you find a security issue in any script (e.g., unsafe file handling, potential injection, unintended data exposure):

1. **Do not** open a public issue
2. Open a GitHub Security Advisory via the "Security" tab on the repo
3. Describe the issue and which script is affected
4. We'll respond within 48 hours

## Verifying scripts before running

We encourage you to read any script before running it:

```bash
# Read the script
cat script_name.sh

# Or open in your editor
open -e script_name.sh
```

Every script is commented to help you understand what each section does.
