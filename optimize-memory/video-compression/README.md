# Video Compression (H.265/HEVC)

Compress video files to **~50-60% smaller** with virtually no visible quality loss.

> Tested: a folder of 7 videos (7.6 GB) compressed to ~3.3 GB — same 1080p resolution, same visual quality.

---

## How it works

The script re-encodes your videos from H.264 to **H.265 (HEVC)** — a newer, more efficient codec that produces the same visual quality in roughly half the file size. It's the same technology Apple uses for iPhone recordings.

**Key points:**
- Resolution stays the same (1080p stays 1080p)
- Quality is controlled by CRF (Constant Rate Factor) — the script targets CRF 28 which is visually indistinguishable from the original on normal screens
- The encoder preset (`veryslow`) maximizes compression by trying every optimization technique available — same quality, smallest possible file

---

## Requirements

- **macOS** (also works on Linux)
- **ffmpeg** — install with:
  ```bash
  brew install ffmpeg
  ```

---

## Usage

### Option 1: Run in place
```bash
# Copy the script into your video folder
cp compress_videos.sh /path/to/your/videos/

# Make it executable (one-time)
chmod +x /path/to/your/videos/compress_videos.sh

# Run it
cd /path/to/your/videos/
./compress_videos.sh
```

### Option 2: Clone and copy
```bash
git clone https://github.com/NIRPEKSH/mac-toolbox.git
cp mac-toolbox/optimize-memory/video-compression/compress_videos.sh /path/to/your/videos/
cd /path/to/your/videos/
chmod +x compress_videos.sh
./compress_videos.sh
```

---

## What happens when you run it

1. **Scans** the folder for all video files (mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg)
2. **Detects your CPU** and calculates how many files to encode in parallel
3. **Checks disk space** and warns you if it's tight
4. **Shows a summary** of all files it will process
5. **Encodes in batches** — multiple files in parallel for speed
6. **Reports progress** every 5 minutes (which file, how long, ETA)
7. **Moves originals** to an `originals/` subfolder (never deletes them)
8. **Prints a final summary** with per-file and total space savings

### Example output
```
╔══════════════════════════════════════════════════════════════════╗
║  VIDEO COMPRESSOR — H.265 HEVC                                 ║
╠══════════════════════════════════════════════════════════════════╣
║  Folder:  /Users/you/Videos                                     ║
║  Files:   7 videos (7.45 GB)                                    ║
║  Preset:  veryslow (CRF 28)                                     ║
║  CPU:     Apple M1 Pro                                           ║
║  Cores:   8 cores, 16 GB RAM                                    ║
║  Plan:    2 parallel jobs, 4 batches                             ║
╚══════════════════════════════════════════════════════════════════╝

...

╔══════════════════════════════════════════════════════════════════╗
║                    COMPRESSION COMPLETE                         ║
╠══════════════════════════════════════════════════════════════════╣
║  Total before:      7.45 GB                                     ║
║  Total after:       3.28 GB                                     ║
║  Space saved:       4.17 GB (56.0%)                              ║
║  Total time:        1h 42m 15s                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Configuration

Open `compress_videos.sh` in any text editor. The config section is at the top:

### CRF (Quality)

| Value | Quality | Use case |
|---|---|---|
| 18 | Visually lossless | Archival, professional work |
| 23 | High quality | Good balance of quality and size |
| **28** | **Great quality (default)** | **Best for most people — hard to see any loss** |
| 32 | Good quality | Noticeable softness on close inspection |

### Preset (Speed vs Size)

All presets produce the **same visual quality**. Slower presets just pack that quality into fewer bytes.

| Preset | Speed | File size (vs medium) | Best for |
|---|---|---|---|
| `ultrafast` | ~10x faster | ~40-50% larger | Quick test run, previewing |
| `veryfast` | ~3-4x faster | ~15-20% larger | Large batches, impatient |
| `fast` | ~2x faster | ~5-8% larger | Good speed/size balance |
| `medium` | Baseline | Baseline | General purpose |
| `slow` | ~2x slower | ~5-8% smaller | When you want smaller files |
| `slower` | ~4-5x slower | ~10-12% smaller | Patient optimizer |
| **`veryslow`** | **~10-15x slower** | **~12-15% smaller** | **Maximum compression (default)** |

### Progress interval

`PROGRESS_INTERVAL=300` — prints a status update every 300 seconds (5 minutes). Change to 60 for more frequent updates.

---

## Supported formats

mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, mpg, mpeg

Output is always the same format as the input (an mp4 stays an mp4).

---

## FAQ

**Q: Will the compressed files play on my iPhone/iPad/Apple TV?**
A: Yes. The script uses the `hvc1` tag which ensures Apple device compatibility.

**Q: Can I stop the script mid-way and resume later?**
A: Yes. The script skips files that have already been compressed (files ending in `_h265`). Already-processed files whose originals are in the `originals/` folder won't be touched.

**Q: What if something goes wrong during encoding?**
A: The original file is only moved to `originals/` after the new file is fully written and verified. If encoding fails, the original stays untouched.

**Q: How do I get my originals back?**
A: They're in the `originals/` subfolder. Just move them back:
```bash
mv originals/* .
```

**Q: Can I change the output format (e.g., mp4 to mkv)?**
A: Not currently — the script preserves the original format. You can modify the script if needed.

**Q: Does this work on Linux?**
A: Yes, as long as `ffmpeg` is installed. The script auto-detects the OS for CPU detection.

---

## Technical details

- **Codec**: libx265 (H.265/HEVC)
- **Audio**: AAC at 128 kbps (CD quality stereo)
- **Container flags**: `hvc1` (Apple compatibility), `faststart` (instant streaming/seeking)
- **Thread management**: Each encode is limited to a calculated number of CPU cores to allow parallel processing without thrashing
