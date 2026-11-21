# rpm-mp3-playlist-generator

Generate random music playlists for RPM indoor cycling workouts — from the command line, or from a small web UI that writes playlists straight into [Lyrion Music Server](https://lyrion.org/) (LMS).

## Context

When the COVID pandemic started I had to quit the RPM indoor cycling workouts in the gym and bought my own spinning bike. I needed a way to generate my own music playlists for the workout.

The Les Mills RPM program always has the same setup (e.g. track 1 is warming up, track 5 interval, track 6 sprinting), and the music style always matches the exercise. I wanted to increase the total workout time, put more focus on certain exercises, and always get a unique set of tracks.

## How it works

1. All audio files start with their **track number**, e.g. `1 - Song.mp3` (warm-up), `5 - Song.mp3` (interval). Track `1` never matches `10`.
2. A **class structure** lists the track numbers in playing order and how many tracks to pick for each:

   ```csv
   track,amount
   1,1
   2,1
   3,1
   4,1
   5,2
   6,2
   7,1
   8,1
   9,1
   ```

   Here every workout gets two interval (5) and two sprint (6) tracks. See [rpmtracks.csv](rpmtracks.csv).
3. The generator builds N playlists (`RPM 01`, `RPM 02`, …), picking random tracks per slot. **No track is used twice within one run.** If a slot runs out of unused tracks you get a warning and that playlist gets fewer tracks.

## Option 1: Web UI in Docker (Lyrion)

A Flask app ([web/](web/)) that writes `.m3u` playlists into Lyrion's playlist folder and asks LMS to rescan, so they show up immediately in clients like Squeezer.

The image is built by GitHub Actions for amd64 and arm64:

```
ghcr.io/tabnul/rpm-mp3-playlist-generator:latest
```

### Setup

Use [web/docker-compose.yml](web/docker-compose.yml) — a standalone compose project next to Lyrion:

```yaml
services:
  rpm-playlists:
    image: 'ghcr.io/tabnul/rpm-mp3-playlist-generator:latest'
    restart: unless-stopped
    user: '1003:1003'                     # same as Lyrion's PUID/PGID
    ports:
      - '8080:8080'
    extra_hosts:
      - 'host.docker.internal:host-gateway'
    environment:
      TZ: 'Europe/Amsterdam'
      TRACK_SUBDIR: ''                    # e.g. 'RPM' to only scan /music/RPM
      LMS_URL: 'http://host.docker.internal:9000'
    volumes:
      - /path/to/music:/music:ro
      - /path/to/lyrion/playlist:/playlist
      - ./data:/data
```

- **`/music`** must be the same path Lyrion uses for your music, so the playlist entries resolve in LMS.
- **`/playlist`** is Lyrion's playlist folder.
- **`user`** must be able to write the playlist folder and should match Lyrion's user (check with `stat -c '%u:%g' /path/to/lyrion/playlist`).

```sh
mkdir -p data && sudo chown 1003:1003 data
docker compose pull && docker compose up -d
```

Open `http://<server>:8080`.

### Using the web UI

- **Generate**: number of playlists, name prefix, and:
  - *Replace existing* — deletes old playlists with that prefix and starts at `01`; unticked, numbering continues after the last one.
  - *Rescan* — asks Lyrion to rescan playlists afterwards.
- **Class structure**: edit track numbers and amounts, saved in `/data/structure.csv`.
- Use different prefixes (e.g. `RPM Long`) to keep separate sets of playlists.

### Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `MUSIC_DIR` | `/music` | Root music folder (as Lyrion sees it) |
| `TRACK_SUBDIR` | empty | Only scan this subfolder of `MUSIC_DIR` |
| `PLAYLIST_DIR` | `/playlist` | Where `.m3u` files are written |
| `DATA_DIR` | `/data` | Where the class structure is stored |
| `LMS_URL` | `http://lyrion-app:9000` | Lyrion URL for the rescan |

### Run without Docker

```sh
cd web
pip install -r requirements.txt
MUSIC_DIR=/path/to/music PLAYLIST_DIR=/tmp/playlist DATA_DIR=/tmp/data python app.py
```

## Option 2: PowerShell script

[create-playlist.ps1](create-playlist.ps1) does the same from the command line, writing `.m3u` playlists or copying the tracks into a folder per playlist.

```powershell
# .m3u playlists for Lyrion
.\create-playlist.ps1 -TrackFolder "D:\Music\RPM" -PlaylistFolder "D:\Playlists" `
  -TrackCsv .\rpmtracks.csv -ServerTrackFolder "/music/RPM"

# copy tracks into folders "RPM 01", "RPM 02", ...
.\create-playlist.ps1 -Mode copy -TrackFolder D:\Music\RPM -PlaylistFolder D:\Out -TrackCsv .\rpmtracks.csv -Count 5
```

| Parameter | Default | Meaning |
|---|---|---|
| `-TrackFolder` | required | Folder to scan (including subfolders) |
| `-PlaylistFolder` | required | Output folder |
| `-TrackCsv` | required | Class structure CSV |
| `-Mode` | `playlist` | `playlist` = `.m3u` files, `copy` = copy tracks |
| `-Count` | `15` | Number of playlists |
| `-Prefix` | `RPM` | Playlist name prefix |
| `-ServerTrackFolder` | empty | Path of `-TrackFolder` as Lyrion sees it (playlist mode) |

See `Get-Help .\create-playlist.ps1 -Full`. If scripts are blocked: `powershell -ExecutionPolicy Bypass -File .\create-playlist.ps1 ...`
