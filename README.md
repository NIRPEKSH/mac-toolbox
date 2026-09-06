# Mac Toolbox

A curated collection of shell scripts to optimize, clean, and supercharge your Mac. Built for the community.

> Your Mac is powerful. These scripts help you keep it that way.

---

## What is this?

A growing library of **plug-and-play shell scripts** for macOS. Each script is:

- **Self-contained** — drop it in a folder, run it. No dependencies beyond what's noted.
- **Well-documented** — every script has inline comments and a dedicated README with usage instructions.
- **Safe** — originals are preserved, destructive actions require confirmation, and everything is reversible.
- **Community-driven** — contributions, suggestions, and feedback are welcome.

---

## Categories

| Category | What it solves | Scripts |
|---|---|---|
| [Optimize Memory](optimize-memory/) | Free up disk space without losing what matters | [Video Compression](optimize-memory/video-compression/) |
| Optimize CPU *(coming soon)* | Tame runaway processes, manage startup items | — |
| Cleanup *(coming soon)* | Clear caches, old logs, duplicate files | — |
| System Info *(coming soon)* | Health checks, disk reports, battery stats | — |

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/NIRPEKSH/mac-toolbox.git

# Go to any script folder
cd mac-toolbox/optimize-memory/video-compression/

# Make it executable (one-time)
chmod +x compress_videos.sh

# Copy to whatever folder has your files and run
cp compress_videos.sh /path/to/your/videos/
cd /path/to/your/videos/
./compress_videos.sh
```

---

## Requirements

- **macOS** (tested on Ventura, Sonoma, Sequoia, Tahoe — Apple Silicon and Intel)
- **Homebrew** — some scripts need tools installed via `brew`. Each script's README lists its specific requirements.

---

## Contributing

Found a bug? Have a script idea? Want to improve an existing one?

1. Fork this repo
2. Create a branch (`git checkout -b feature/my-awesome-script`)
3. Follow the existing folder structure:
   ```
   category-name/
   └── script-name/
       ├── README.md          # What it does, how to use it, options
       └── script_name.sh     # The script itself (well-commented)
   ```
4. Submit a PR with a clear description

### Guidelines for contributions
- Scripts must work on macOS (mention if they work cross-platform)
- Include a README with requirements, usage, and example output
- Add inline comments explaining *why*, not just *what*
- Preserve user data — never delete originals without confirmation
- Test on at least one macOS version before submitting

---

## License

MIT License — use these scripts freely, modify them, share them. See [LICENSE](LICENSE) for details.

---

## Support

If these scripts saved you time, disk space, or headaches — drop a star! It helps others find the repo.

Got questions? [Open an issue](https://github.com/NIRPEKSH/mac-toolbox/issues) and we'll help out.
