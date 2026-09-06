# Contributing to Mac Toolbox

Thanks for your interest in contributing! This project is community-driven, and every contribution helps Mac users everywhere.

---

## How to contribute

### 1. Fork and branch

```bash
# Fork the repo on GitHub, then:
git clone https://github.com/YOUR-USERNAME/mac-toolbox.git
cd mac-toolbox
git checkout -b feature/your-script-name
```

> **Important**: Direct pushes to `main` are not allowed. All changes go through pull requests.

### 2. Follow the folder structure

```
category-name/
└── script-name/
    ├── README.md              # Full usage guide
    └── script_name.sh         # The script
```

### 3. Script standards

Every script in this repo must:

- **Run locally only** — no data should leave the user's machine. No network calls, no telemetry, no analytics. If your script needs network access (e.g., downloading a tool), document it clearly.
- **Preserve user data** — never delete originals without explicit confirmation. Move to a backup folder instead.
- **Be self-contained** — drop it in a folder and run. Minimal dependencies.
- **Be well-commented** — explain what each section does, document config options inline.
- **Show progress** — for long-running scripts, print status updates so the user knows what's happening.
- **Check prerequisites** — verify required tools are installed before starting, with clear install instructions.
- **Handle errors gracefully** — don't leave partial outputs or corrupted files on failure.

### 4. README standards

Each script's README should include:

- **What it does** — one-line summary at the top
- **How it works** — brief, non-technical explanation
- **Requirements** — what needs to be installed
- **Usage** — copy-pasteable commands
- **Configuration** — what can be changed and what each option does
- **Example output** — so users know what to expect
- **FAQ** — common questions

### 5. Commit messages

Use clear, descriptive commit messages:

```
feat: add new script for clearing Xcode caches
docs: update video compression FAQ with Linux instructions
fix: handle filenames with spaces in compress_videos.sh
```

Prefixes: `feat` (new script/feature), `fix` (bug fix), `docs` (documentation), `refactor` (code improvement)

### 6. Submit a pull request

- Fill in the PR template
- Mention which macOS version and chip you tested on
- Keep PRs focused — one script or fix per PR

---

## Code of conduct

Be respectful. Be helpful. We're all here to make Mac life easier.

---

## Questions?

Open an issue with the "question" label and we'll get back to you.
