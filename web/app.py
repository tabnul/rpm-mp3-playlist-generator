"""RPM playlist generator - web UI for creating Lyrion (LMS) playlists."""
import csv
import json
import os
import random
import re
import urllib.request
from pathlib import Path

from flask import Flask, flash, redirect, render_template, request, url_for

MUSIC_DIR = Path(os.environ.get("MUSIC_DIR", "/music"))
TRACK_SUBDIR = os.environ.get("TRACK_SUBDIR", "")  # e.g. "RPM" -> scans /music/RPM
PLAYLIST_DIR = Path(os.environ.get("PLAYLIST_DIR", "/playlist"))
DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
LMS_URL = os.environ.get("LMS_URL", "http://lyrion-app:9000")
AUDIO_EXT = {".mp3", ".flac", ".m4a", ".aac", ".ogg", ".opus", ".wav", ".wma", ".aiff", ".aif"}

STRUCTURE_FILE = DATA_DIR / "structure.csv"
DEFAULT_STRUCTURE = [{"track": str(n), "amount": 1} for n in range(1, 11)]

app = Flask(__name__)
app.logger.setLevel("INFO")
app.secret_key = os.environ.get("SECRET_KEY", "rpm-playlist-generator")


# ---------- structure (track slot -> amount) ----------

def load_structure():
    if not STRUCTURE_FILE.exists():
        return list(DEFAULT_STRUCTURE)
    with STRUCTURE_FILE.open(newline="", encoding="utf-8-sig") as f:
        return [{"track": r["track"].strip(), "amount": int(r["amount"])}
                for r in csv.DictReader(f) if r.get("track", "").strip()]


def save_structure(rows):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with STRUCTURE_FILE.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["track", "amount"])
        w.writeheader()
        w.writerows(rows)


# ---------- generation ----------

def scan_tracks():
    root = MUSIC_DIR / TRACK_SUBDIR if TRACK_SUBDIR else MUSIC_DIR
    return [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in AUDIO_EXT]


def existing_playlists(prefix):
    pattern = re.compile(rf"^{re.escape(prefix)} (\d+)\.m3u$")
    found = []
    for p in PLAYLIST_DIR.glob("*.m3u"):
        m = pattern.match(p.name)
        if m:
            found.append((int(m.group(1)), p))
    return sorted(found)


def generate(count, prefix, replace):
    structure = load_structure()
    files = scan_tracks()
    PLAYLIST_DIR.mkdir(parents=True, exist_ok=True)

    existing = existing_playlists(prefix)
    if replace:
        for _, p in existing:
            p.unlink()
        start = 1
    else:
        start = (existing[-1][0] + 1) if existing else 1

    used = set()
    results, warnings = [], []
    for number in range(start, start + count):
        name = f"{prefix} {number:02d}"
        lines = ["#EXTM3U"]
        picked = []
        for row in structure:
            slot, amount = row["track"], row["amount"]
            rx = re.compile(rf"^{re.escape(slot)}(\D|$)")
            candidates = [p for p in files if rx.match(p.name) and p.name not in used]
            if len(candidates) < amount:
                warnings.append(f"{name}, track {slot}: only {len(candidates)} unused tracks left (need {amount})")
            for p in random.sample(candidates, min(amount, len(candidates))):
                used.add(p.name)
                lines += [f"#EXTINF:-1,{p.stem}", str(p)]
                picked.append({"slot": slot, "name": p.stem})
        (PLAYLIST_DIR / f"{name}.m3u").write_text("\n".join(lines) + "\n", encoding="utf-8")
        results.append({"name": name, "tracks": picked})
    return results, warnings, len(files)


def lms_request(*command):
    payload = json.dumps({"id": 1, "method": "slim.request", "params": ["", list(command)]}).encode()
    req = urllib.request.Request(f"{LMS_URL}/jsonrpc.js", data=payload,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read() or b"{}")


def lms_rescan_playlists():
    # A normal (changes-only) rescan reliably picks up new and modified playlist files;
    # "rescan playlists" can miss replaced files with unchanged names.
    lms_request("rescan")
    app.logger.info("Lyrion rescan requested at %s", LMS_URL)


# ---------- routes ----------

@app.get("/")
def index():
    return render_template("index.html", structure=load_structure(),
                           playlists=[p.stem for _, p in existing_playlists(request.args.get("prefix", "RPM"))],
                           lms_url=LMS_URL)


@app.post("/structure")
def update_structure():
    rows = []
    for track, amount in zip(request.form.getlist("track"), request.form.getlist("amount")):
        track = track.strip()
        if track:
            try:
                rows.append({"track": track, "amount": max(1, int(amount))})
            except ValueError:
                flash(f"Invalid amount for track {track}", "error")
                return redirect(url_for("index"))
    save_structure(rows)
    flash("Class structure saved", "ok")
    return redirect(url_for("index"))


@app.post("/generate")
def do_generate():
    count = max(1, min(999, int(request.form.get("count", 15))))
    prefix = request.form.get("prefix", "RPM").strip() or "RPM"
    replace = request.form.get("replace") == "1"
    results, warnings, scanned = generate(count, prefix, replace)
    rescan_msg = None
    if request.form.get("rescan") == "1":
        try:
            lms_rescan_playlists()
            rescan_msg = "Lyrion playlist rescan started"
        except Exception as e:  # noqa: BLE001
            rescan_msg = f"Lyrion rescan failed ({LMS_URL}): {e}"
            app.logger.error(rescan_msg)
    return render_template("index.html", structure=load_structure(),
                           playlists=[p.stem for _, p in existing_playlists(prefix)],
                           results=results, warnings=warnings, scanned=scanned,
                           rescan_msg=rescan_msg, lms_url=LMS_URL)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
