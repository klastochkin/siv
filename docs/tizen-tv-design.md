# Design Document — SIV TV (Samsung Tizen Photo Viewer)

**Version:** 1.0  
**Date:** August 11, 2026  
**Status:** Proposal  
**Related:** macOS SIV in this repo (`Sources/SIV`), album format `.sivalb`

---

## 1. Verdict

**Yes, this is possible.** Samsung Tizen Smart TVs run packaged **HTML5/CSS/JS** apps (`.wgt`). A small app can show a **thumbnail grid** and a **fullscreen slideshow**, fetching photos over HTTP(S) from a home server or a cheap cloud store that SIV manages and syncs.

Native Swift on TV is not an option; the TV client is a separate web app. SIV (macOS) remains the curator: import, album management, sync, and optional thumbnail/manifest generation.

---

## 2. Goals / Non-Goals

### Goals (MVP)
- Browse a photo collection on the TV remote (D-pad)
- Thumbnail grid with lazy loading
- Fullscreen slideshow (auto-advance + manual next/prev)
- One configurable photo source URL (LAN or cloud)
- Collection curated and synced by macOS SIV

### Non-Goals (MVP)
- On-TV editing, uploads, or album management
- Multi-user accounts / Samsung account login
- Samsung Apps Store publishing (can come later)
- Video playback
- Offline-first large local cache on the TV (optional later)

---

## 3. System Overview

```
┌──────────────────────┐         sync / publish          ┌─────────────────────┐
│  macOS SIV (this     │ ──────────────────────────────► │  Photo backend      │
│  repo)               │   originals + thumbs + index    │  (chosen variant)   │
│  - albums            │                                 └──────────┬──────────┘
│  - import / EXIF     │                                            │
│  - sync job          │                                            │ HTTPS / HTTP
└──────────────────────┘                                            │
                                                                    ▼
                                                         ┌─────────────────────┐
                                                         │  SIV TV (Tizen      │
                                                         │  HTML5 .wgt)        │
                                                         │  - thumbnail grid   │
                                                         │  - slideshow        │
                                                         └─────────────────────┘
```

**Contract between SIV and TV:** a stable, dumb HTTP API (or static files) so the TV never talks to Apple APIs or local disks directly.

---

## 4. TV App UX

### 4.1 Screens

| Screen | Behavior |
|--------|----------|
| **Grid** | Focusable thumbnail tiles, rows/columns sized for 1080p/4K. Remote arrows move focus; OK opens slideshow at that photo. |
| **Slideshow** | Fullscreen image, fit-contain. Left/Right = prev/next; OK or Play = pause/resume; Back = return to grid. Optional interval 3–10s (setting). |
| **Settings** (minimal) | Base URL of photo source; slideshow interval; “Reload index”. Stored in `localStorage` / Tizen preference. |

### 4.2 Remote mapping

| Key | Grid | Slideshow |
|-----|------|-----------|
| ←↑↓→ | Move focus | Prev / next (←→); unused ↑↓ or jump ±N |
| OK / Enter | Open slideshow | Pause / resume |
| Back / Return | Exit app (or confirm) | Back to grid |
| Play / Pause (if present) | — | Toggle auto-advance |

### 4.3 Formats
- **Display on TV:** JPEG, PNG, WebP (widely supported in Tizen WebKit).
- **Source from Mac:** HEIF/RAW stay Mac-side; SIV converts/exports **JPEG (or WebP)** for TV sync. Do not rely on HEIC on Tizen.

### 4.4 Performance notes
- Serve **small thumbs** (e.g. 320–480 px long edge) for the grid; full images only in slideshow.
- Prefetch next 1–2 full images during slideshow.
- Keep index payload small (JSON list of ids/paths/dates); paginate if > ~2–5k items.

---

## 5. Photo source variants (feasible)

Ranked for a **home + SIV-managed** setup.

### Variant A — Local HTTP file server (recommended MVP)

**Idea:** A machine on the home LAN (Mac always-on, Raspberry Pi, NAS with Docker, or mini PC) exposes:

```
GET /index.json          → list of photos (id, path, date, thumbUrl, fullUrl)
GET /thumbs/{id}.jpg
GET /full/{id}.jpg
```

SIV syncs a folder (or runs a tiny static server). TV points at `http://192.168.x.x:8080`.

| Pros | Cons |
|------|------|
| Free, private, fast on LAN | TV must be on same network; no remote viewing unless VPN |
| Trivial for Tizen (`fetch` + `<img>`) | Need an always-reachable host when watching |
| Full control of layout/format | HTTP on LAN is fine; avoid exposing to internet without auth/TLS |

**Stack options:** Caddy/nginx static root; Synology/QNAP “Web Station”; tiny Go/Node server next to SIV sync output.

**SIV role:** Export selected album → write `index.json` + thumbs + full JPEGs into the served directory (rsync/local copy).

**Mac setup:** see **Appendix B** (DHCP reservation, no DNS, SIV’s built-in server bound to the LAN IP).

---

### Variant B — Self-hosted photo library (Immich / Nextcloud)

**Idea:** Run [Immich](https://immich.app/) or Nextcloud on a NAS/Pi; SIV uploads/syncs into it; TV talks to Immich’s REST API (or Nextcloud WebDAV/share links).

| Pros | Cons |
|------|------|
| Mature thumbs, albums, mobile apps for free | Heavier ops (Docker, DB, updates) |
| Good remote access if you already expose it | Immich API/auth more work than static files |
| Nextcloud is familiar for files | WebDAV from Tizen is awkward; prefer HTTP API or public share URLs |

**When to pick:** You want phones + TV + Mac against one library, not just TV.

**SIV role:** Sync album into Immich (CLI/API) or into a Nextcloud folder that Immich/Nextcloud indexes.

---

### Variant C — Cheap object storage + public/private CDN (cloud)

**Idea:** SIV uploads to **Backblaze B2** or **Cloudflare R2** (or Wasabi). TV loads `index.json` + images via HTTPS URLs. Optionally put Cloudflare in front for caching and a custom domain.

| Pros | Cons |
|------|------|
| Works away from home; no always-on NAS | Bandwidth/egress costs if you stream a lot remotely |
| Very cheap storage (often cents/GB-month) | Need careful **auth**: signed URLs or private bucket + token |
| No home port-forwarding | TV CORS: host must allow the app origin (or same-origin via proxy) |

**Cost ballpark (order of magnitude):** storage ~$0.006–0.015/GB-month; egress free on R2, paid on B2 unless using their CDN partnership. For a few thousand JPEGs and home-only use, monthly cost is usually **under a few dollars**.

**SIV role:** Sync exporter → object keys mirroring Variant A layout; generate short-lived signed URLs or a small edge worker that serves with a shared secret.

**Avoid as primary for MVP:** Google Photos API (quotas, OAuth on TV, ToS), iCloud (no sane third-party TV API), Dropbox free-tier friction.

---

### Variant D — USB / TV local storage (not recommended as primary)

Tizen can see USB media via content APIs, but:

- No SIV sync story
- Manual copy workflow
- Poor fit for “manage from this repo”

Keep as a **fallback** only, not the design target.

---

## 6. Recommendation

| Priority | Choice | Why |
|----------|--------|-----|
| **MVP** | **Variant A** (LAN static HTTP + `index.json`) | Smallest surface; perfect match for SIV export; easy on Tizen |
| **Next** | **Variant C** (R2/B2) if you want couch access from another house / travel | Same index format, different sync target |
| **Later** | Immich if you want a full family photo OS | Bigger project; TV becomes a thin Immich client |

**Unified index format** (use for A and C):

```json
{
  "version": 1,
  "generatedAt": "2026-08-11T20:00:00Z",
  "photos": [
    {
      "id": "a1b2c3",
      "title": "IMG_1234.jpg",
      "takenAt": "2024-06-01T15:22:00Z",
      "thumb": "thumbs/a1b2c3.jpg",
      "full": "full/a1b2c3.jpg",
      "width": 4032,
      "height": 3024
    }
  ]
}
```

Relative URLs resolve against the configured base URL.

---

## 7. SIV (this repo) — storage management & sync

### 7.1 New macOS capabilities (design)

Add a **“TV Library”** (or “Publish”) feature, not a rewrite of albums:

1. **Source:** current default album (or later: selected album).
2. **Export pipeline:**
   - Resolve missing files (reuse existing missing-file UX).
   - Convert HEIF → JPEG when needed.
   - Generate thumbs (reuse thumbnail sizing ideas from `AlbumViewModel`).
   - Write `index.json` + `thumbs/` + `full/`.
3. **Sync target** (settings):
   - Local folder (Variant A root)
   - Optional: B2/R2 credentials (Variant C)
4. **Incremental sync:** by file mtime/hash; only rewrite changed ids.
5. **Optional:** “Serve local folder” menu item wrapping a tiny embedded HTTP server for demos (not required if nginx/Caddy is used).

### 7.2 Suggested module boundaries

```
Sources/SIV/
  Services/
    TVExportService.swift      // build tree + index.json
    TVSyncService.swift        // copy/upload to target
  Models/
    TVLibraryIndex.swift       // Codable index
```

Keep TV-specific code out of pure viewing paths; album remains the source of truth (`.sivalb`).

### 7.3 Repo layout (future)

```
siv/
  Sources/SIV/                 # existing macOS app
  tv/                          # NEW: Tizen web app
    config.xml
    index.html
    css/
    js/
    icon.png
  docs/tizen-tv-design.md      # this doc
```

---

## 8. Tizen technical approach

| Topic | Choice |
|-------|--------|
| App type | **Tizen Web Application** (HTML5) |
| UI | CSS grid + spatial navigation (focus); or lightweight TV UI lib |
| Network | `fetch` / XHR to LAN or HTTPS; privilege `internet` in `config.xml` |
| Packaging | `.wgt` via Tizen Studio / CLI |
| Target | Recent Samsung Tizen TV (2017+ recommended for tooling like Wits) |
| Orientation | Landscape 16:9; design for 1920×1080 safe area |

**Privileges (typical):**

```xml
<tizen:privilege name="http://tizen.org/privilege/internet"/>
<!-- access_network may be required depending on profile -->
```

**CORS:** For Variant A on LAN, prefer serving from the same host the app loads assets from, or set `Access-Control-Allow-Origin` on the photo server. Packaged apps loading remote images usually need server CORS headers.

---

## 9. Milestones

1. **Static prototype:** Hand-built `index.json` + folder; TV app grid + slideshow against LAN URL.
2. **SIV export:** One-button publish of default album to that folder.
3. **Polish:** Prefetch, empty/error states, settings screen, interval.
4. **Optional cloud sync:** Same export → R2/B2.
5. **Optional store / permanent cert:** If you want install without developer mode forever.

---

## 10. Security

### 10.1 Short answers

| Question | Answer |
|----------|--------|
| Can the TV app get “hacked”? | **Yes, in principle** — but for a **sideloaded, LAN-only, read-only photo viewer you wrote yourself**, practical risk is **low**, not zero. |
| Can it be used for lateral movement on your LAN? | **Possible if something is compromised**, but this app’s intended design has a **small attack surface**. Risk is **not zero** just because traffic stays on the local network. |
| Is “local network only” risk = 0? | **No.** LAN-only removes most *internet* attackers; it does **not** remove threats from other devices on the same Wi‑Fi, a compromised phone/laptop, guest devices, or a compromised TV/firmware. |

### 10.2 Threat model (what we actually care about)

Assume a typical home setup: TV + photo HTTP server + Mac with SIV on one LAN/VLAN; no intentional port-forward of the photo server to the internet.

**Assets**
- Photo originals / family images (confidentiality, integrity)
- Other hosts on the LAN (Macs, NAS, IoT) — lateral movement target
- Credentials if any (cloud keys, sync tokens) stored on Mac or in the TV app

**Actors (realistic)**
1. Someone already on your Wi‑Fi (guest, neighbor on open/weak Wi‑Fi, infected laptop)
2. Malware on another home device scanning the LAN
3. Compromised Samsung TV firmware / other TV apps (supply chain / TV OS bugs)
4. You accidentally expose the photo server or cloud bucket to the public internet
5. (Lower for sideload) Malicious replacement of *your* `.wgt` — only if someone can install apps on your TV

**Out of scope for MVP worry (unless you publish to the store):** random internet users attacking your unlisted personal `.wgt` binary; nation-state TV implants.

### 10.3 Risk of the TV app itself being compromised

The Tizen client is a **packaged web app** (HTML/JS) with network access.

| Vector | Likelihood (sideload, your code) | Impact | Notes |
|--------|----------------------------------|--------|-------|
| Remote code exec via photo server responses | Low if server is static files you control | High if achieved | Treat `index.json` and image URLs as **untrusted input**; don’t `eval` JSON via anything but `JSON.parse`; don’t load arbitrary script URLs from the index |
| XSS / script injection via metadata in index | Low–med if you later render titles as HTML | Medium | Render text with text nodes / escaped UI only |
| Malicious image decoder bugs in TV WebKit | Low | Medium–high | Same class of risk as browsing the web on the TV; keep images as JPEG/WebP from your exporter |
| Stolen / replaced `.wgt` install | Low at home | Medium | Requires physical/remote install access + developer mode or store path |
| TV OS / other apps pivoting into your app | Low–unknown | Medium | You don’t control the platform; keep secrets out of the TV app |

**Practical stance for MVP:** the TV app should be a **dumb viewer** — no write APIs, no shell, no stored cloud master keys. Compromise of the viewer mainly means **someone can see whatever the photo URL allows** and **abuse the TV’s network identity** to call other LAN services the TV can reach.

### 10.4 Lateral movement — is LAN-only “safe enough”?

**Local network ≠ isolated security domain.**

Anything that can run code on the TV (your app, another app, a WebView bug) can typically:

- Open TCP connections to other LAN IPs the TV can route to
- Probe common ports (NAS, SMB, SSH, routers, printers)
- Use credentials **if** you embed them in the app or if the photo server is overly privileged

So:

```
Internet ──✖──► Photo server     (good: no inbound from WAN)
Guest phone ──► LAN ──► Photo server / TV / Mac   (still in scope)
Compromised TV app ──► scan/attack other LAN hosts (lateral movement path)
```

**Risk is reduced vs cloud exposure, not eliminated.**

What “staying on the local network” *does* buy you:
- No random scanners on the public internet hitting your photo index
- No need for a public hostname if you never port-forward
- Smaller, known set of devices that can talk to the server

What it does *not* buy you:
- Protection from infected devices already on Wi‑Fi
- Protection if the TV itself is untrusted
- Protection if guest Wi‑Fi is not isolated (many home routers put guests on the same LAN)

### 10.5 Trust boundaries (design rules)

```
┌─────────────────────────────────────────────────────────────┐
│  Untrusted relative to photos: TV app, TV OS, whole Wi‑Fi   │
└─────────────────────────────────────────────────────────────┘
                              │ read-only HTTPS/HTTP
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Photo publish tree (thumbs/full/index) — least privilege   │
│  Separate from Mac home dir / SIV source album when possible│
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ write (SIV sync only)
┌─────────────────────────────────────────────────────────────┐
│  Trusted: Mac SIV + sync credentials (never on the TV)      │
└─────────────────────────────────────────────────────────────┘
```

1. **TV = untrusted client.** It only needs read access to the published tree.
2. **Photo server = read-only** for clients (no upload, no delete, no admin UI on that port).
3. **SIV credentials for B2/R2 stay on the Mac.** If the TV needs auth, use a **narrow read token** or short-lived signed URLs — not the sync key.
4. **Do not bind the photo server to `0.0.0.0` on a WAN-facing interface**; bind to LAN interface or firewall WAN→LAN:8080 DENY.
5. Prefer a **dedicated publish directory** (or container volume), not “serve entire NAS share”.

### 10.6 Variant-specific security notes

| Variant | Main risk | Mitigations |
|---------|-----------|-------------|
| **A — LAN HTTP** | Any LAN host can fetch photos if URL known / scanned; cleartext on Wi‑Fi | Bind LAN-only; optional shared secret header/token; guest Wi‑Fi isolation; later TLS on LAN if you care about Wi‑Fi sniffing |
| **B — Immich/Nextcloud** | Account takeover → whole library; server RCE is high impact | Strong passwords / SSO; keep updated; TV uses limited API token; don’t reuse admin credentials on TV |
| **C — R2/B2** | Public bucket = internet-readable photos; leaked write keys = wipe/ransom | Private bucket; signed URLs or Worker auth; **write keys only on Mac**; bucket CORS locked down |

**Wi‑Fi sniffing (Variant A HTTP):** on WPA2/3 personal networks, outsiders without the PSK generally can’t decrypt; **other associated clients** and a compromised AP are the realistic sniffers. For family photos on a locked home Wi‑Fi this is often acceptable for MVP; use HTTPS if you want defense-in-depth.

### 10.7 Developer Mode caveat

While Developer Mode is on and pointed at your Mac:

- Install surface is larger (your PC can push packages)
- Treat the Mac as part of the trusted install path; don’t leave Developer Mode aimed at a shared/untrusted machine
- Turn Developer Mode **off** when not actively developing if you want a smaller install attack surface (re-enable when updating the app)

### 10.8 MVP security checklist (enough for home use)

- [ ] Photo server not port-forwarded; WAN access closed
- [ ] Server serves **only** the publish tree, **GET-only**
- [ ] No write/cloud secrets in the Tizen app
- [ ] Index fields never executed as code; titles escaped
- [ ] Guest network isolated from LAN (router setting) if guests use Wi‑Fi
- [ ] Optional: simple bearer token or random URL path prefix so LAN scanners don’t casually enumerate `/index.json`
- [ ] Cloud variant: private bucket + Mac-only write keys

### 10.9 Residual risk statement

For the recommended MVP (**sideloaded viewer + LAN read-only static server + SIV publish**):

- **Internet mass-compromise of “the app”:** negligible if you never publish a malicious store binary and don’t load third-party scripts.
- **Photo confidentiality on LAN:** moderate if the server is open-read on the subnet; low if tokenized + guest isolation.
- **Lateral movement originating from this app:** low if the app stays a dumb `fetch`+`<img>` client with no embedded high-privilege credentials — **but not zero**, because a compromised TV/WebView could still use the TV as a LAN client against other hosts.
- **Overall:** appropriate for personal/family use with the checklist above; not a hardened multi-tenant product.

---

## 11. Risks

| Risk | Mitigation |
|------|------------|
| HEIC unsupported on TV | Convert on export |
| TV asleep / different VLAN can’t reach NAS | Document network; optional cloud variant |
| Developer Mode expires / reinstall needed | Expected for sideload; see install section |
| Large libraries slow grid | Paginate index; virtualize rows |
| Unauthenticated open LAN server / lateral movement | See **§10 Security** — LAN-only ≠ risk zero |

---

# Appendix A — How to put the app on the TV

This is separate from the product design. Two paths: **sideload for yourself** (normal for a private photo app) and **Samsung Seller Office** (public store).

## A.1 What you need

- Samsung Tizen Smart TV and the **same Wi‑Fi/LAN** as your Mac for install
- Mac or PC with **[Tizen Studio](https://developer.tizen.org/development/tizen-studio/download)** (TV extensions / Samsung TV SDK)
- A **Samsung certificate** for signing (Certificate Manager in Tizen Studio) — required to install on a real TV
- Optional: **[Wits](https://github.com/Samsung/Wits)** for live-reload during development

## A.2 Enable Developer Mode on the TV

Works with the slim arrow-only Smart Remote (no digit keys, no `123` button) on recent models. The code has to be typed **inside App Settings**; typing it on the Apps page itself does nothing.

1. On your phone, open **SmartThings**, select the TV, open its **remote**, and switch to the **`123`** number pad.
2. On the TV, press **Home**, move to the **Apps** tab (`For You | Live | Apps`), scroll to the **bottom** of that page, and open **App Settings** (gear).
3. With App Settings open, tap **`1` `2` `3` `4` `5`** quickly on the phone's number pad. The Developer Mode popup appears.
4. Set **Developer mode = On**, enter the **Mac's IP address** with the phone pad, press **OK**.
5. Power-cycle the TV. Unplugging for ~60 s is the most reliable; a long press on power also worked.
6. Confirm: the App Settings header now reads **Settings (DEVELOP MODE)**.

Developer Mode is only needed to install, update, or debug the app. Turning it off afterwards keeps the installed app. Major firmware updates can remove sideloaded apps or switch Developer Mode off; re-enable and reinstall if that happens.

### A.2.1 If the popup doesn't appear

- Make sure you are **inside App Settings**, not on the Apps page.
- Type the digits faster, or try `00000`.
- Sign the TV into the Samsung account you will use for the certificate; remove other accounts.
- **Settings → Support → Device Care → Self Diagnosis → Reset Smart Hub**, re-accept terms, switch the menu language to English, retry.
- Plug a USB keyboard into the TV and type `12345` in App Settings.

### A.2.2 Confirm the Mac can connect

```bash
sdb connect <TV_IP>
sdb devices
```

If the TV is in Developer Mode with the right host IP but `sdb connect` still fails, check macOS **System Settings → Privacy & Security → Local Network** and enable the app you run `sdb` from (Cursor, Terminal, iTerm). macOS silently blocks non-Apple binaries from reaching LAN devices otherwise; `ping` and Apple's `nc` keep working, which makes this easy to misdiagnose.

## A.3 Create / sign / install the package

High-level flow:

1. The app sources are in `tv/` (`config.xml`, `index.html`, `css/`, `js/`, `icon.png`).
2. In Tizen Studio **Certificate Manager**, create a **Samsung** certificate profile (you’ll need a Samsung account; pick the TV’s DUID when asked).
3. Package and sign — with an arrow-only remote, bake the server address in so you don’t have to type it on the TV:

```bash
make tv-package SERVER=http://192.168.1.50:8080            # optional: TOKEN=...
# or: tv/build.sh --server http://192.168.1.50:8080 --profile <cert-profile-name>
# → .build/tv/SIVTV.wgt (signed when the Tizen CLI is found; unsigned otherwise)
```

4. Connect and install:

```bash
sdb connect <TV_IP>
tizen install -n .build/tv/SIVTV.wgt -t "$(sdb devices | awk 'NR==2{print $3}')"
```

Or use Tizen Studio **Run As → Tizen Web Application** with the TV selected.

6. Launch from the TV **Apps** list (may appear under downloaded/test apps).

**Wits (optional):** after Developer Mode + cert setup, `wits -s` installs and live-reloads JS/CSS — much faster iteration than full reinstall each edit.

## A.4 Day-to-day use after install

1. In SIV: **Album → Publish to TV…** → Publish → Start Server.
2. Open **SIV TV** on the TV. First launch opens Settings unless you baked `SERVER=` in.
3. Settings: OK on the address field opens the TV keyboard; `192.168.1.50` alone is enough (`:8080` is assumed).
4. Grid: arrows move, OK opens a photo, ▶ (or toolbar **Slideshow**) starts auto-advance, ▲ on the top row reaches **Slideshow / Reload / Settings**, Back exits.
5. Photo view: ◀▶ previous/next, OK pause/resume, ▲▼ show info, Back returns to the grid on the same photo.

## A.5 Distribution without Developer Mode (optional later)

For a private household app, sideload is enough.

To install without Developer Mode long-term you must:

1. Register as a seller in **[Samsung Seller Office](https://seller.samsungapps.com/)**
2. Submit the app (even if “private”/unlisted options are limited by region/policy)
3. Pass Samsung certification / review
4. Users install from the Samsung Apps store

That is heavier than the MVP warrants for a personal photo viewer.

## A.6 Practical constraints to expect

- App is **web technology**, not the Swift code in this repo.
- TV **cannot** mount your Mac disk or iCloud Drive directly.
- Same **LAN** (or cloud) is mandatory for photos.
- Remotes have **no mouse**; focus navigation must work.
- Some corporate/guest Wi‑Fi **AP isolation** blocks TV→NAS; use main home LAN.

---

# Appendix B — Mac LAN photo server setup (Variant A)

How to publish a folder from your Mac so the TV can read it over HTTP on the **local network only**. No home DNS required.

## B.1 Static IP vs DHCP

The TV will store a **base URL** with a host IP (e.g. `http://192.168.1.50:8080`). If DHCP gives the Mac a new address, the TV breaks until you update Settings.

| Approach | Recommendation |
|----------|----------------|
| **DHCP reservation** on the router (bind Mac Wi‑Fi MAC → fixed IP) | **Preferred** — stable IP, Mac stays on DHCP |
| Manual static IP on the Mac | Fine; pick an address **outside** the router’s DHCP pool, same subnet/gateway/DNS |
| Plain DHCP, no reservation | OK for a quick test; expect occasional URL updates |

Find the Mac’s current LAN IP (example Wi‑Fi `en0`):

```bash
ipconfig getifaddr en0
# example result: 192.168.1.50
```

## B.2 DNS — skip it

**Not worth setting up** for this MVP.

- Use the **numeric IP** in the TV app settings.
- Avoid relying on `something.local` (mDNS); Tizen support is uneven.
- A local DNS server / Pi-hole hostname is optional polish later, not a dependency.

## B.3 Publish directory layout

SIV writes a **dedicated folder** (default `~/SIV-TV-Library`; never point it at your originals):

```
~/SIV-TV-Library/
  index.json
  thumbs/<id>.jpg     # 480 px long edge
  full/<id>.jpg       # 2560 px long edge, sRGB, orientation applied, no EXIF/GPS
```

## B.4 Publish and serve with SIV (recommended)

**In the app:** **Album → Publish to TV…**

1. **Publish N Photo(s)** — exports the album; re-publishing only processes new/changed photos and prunes removed ones.
2. **Listen on** — pick your LAN address (default: first private IPv4, e.g. `192.168.1.50 (en0)`).
3. Optional **access token** → **Generate**.
4. **Start Server** — the sheet shows the exact URL (and token) to type on the TV.

The server keeps running after you close the sheet, until you stop it or quit SIV.

**Headless (Terminal / launchd), same code:**

```bash
SIV=.build/release/SIV.app/Contents/MacOS/SIV        # after `make app`
$SIV tv-publish --out ~/SIV-TV-Library                 # default album; or --album PATH.sivalb
$SIV tv-serve --root ~/SIV-TV-Library --port 8080      # binds the LAN address; --host all to override
$SIV tv-serve --root ~/SIV-TV-Library --token "$(openssl rand -hex 12)"
```

**Verify** from another device on the same Wi‑Fi (phone browser is fine): `http://<mac-ip>:8080/` answers `SIV TV library server`.
Or run the contract test: `make api-test URL=http://<mac-ip>:8080 [TOKEN=…]`.

If the TV or phone cannot connect, allow incoming connections for SIV when macOS asks (or in **System Settings → Network → Firewall**).

**Why not `python3 -m http.server`?** The contract test flags two problems with it: no `Access-Control-Allow-Origin` header (the TV app fetches `index.json` cross-origin) and directory listings. It is fine for a quick look in a browser, not for the TV.

DHCP drift is real: during testing the Mac's address changed between sessions. Set up the router reservation (B.1), or re-check the URL in the SIV sheet when the TV says it cannot reach the server.

## B.5 Keep it local-only

| Control | Action |
|---------|--------|
| Router | **Do not** port-forward TCP 8080 (or any photo port) to the WAN |
| Bind address | LAN IP (SIV’s default), not “All interfaces”; SIV warns if the address isn’t private |
| Content root | Only `~/SIV-TV-Library` (read-only publish tree) |
| Guests | Enable **guest Wi‑Fi isolation** if guests shouldn’t see LAN services |
| Protocol | **HTTP is fine on LAN for MVP**; SMB/AFP File Sharing is a poor fit for the Tizen web app |

macOS **System Settings → General → Sharing → File Sharing** (SMB) is **not** the recommended path for the TV client — stick to HTTP as above.

## B.6 `index.json` format

SIV generates this; shown for reference or for hand-built libraries on other servers:

```json
{
  "version": 1,
  "generatedAt": "2026-08-11T20:00:00Z",
  "albumName": "Default",
  "photos": [
    {
      "id": "demo1",
      "title": "demo1.jpg",
      "takenAt": "2024-06-01T15:22:00Z",
      "thumb": "thumbs/demo1.jpg",
      "full": "full/demo1.jpg",
      "width": 1920,
      "height": 1080
    }
  ]
}
```

## B.7 Optional next steps (not required for MVP)

- Router DHCP reservation so the IP never drifts
- `launchd` agent running `SIV tv-serve` at login (always-on without opening the app)
- Caddy/nginx in front if you want logging or LAN TLS (keep CORS + no listings; verify with `make api-test`)

---

## 12. Implementation (as built)

Variant A is implemented end to end. Variants B/C reuse the same `index.json` contract and are not built.

| Piece | Where |
|-------|-------|
| Index model | `Sources/SIV/Models/TVLibraryIndex.swift` |
| Export / incremental sync | `Sources/SIV/Services/TVExportService.swift` — ids = hash(path, size, mtime, output profile); unchanged photos are skipped, removed/changed ones pruned after the new index is written; outputs are sRGB JPEG with orientation applied and **all metadata stripped** |
| LAN server | `Sources/SIV/Services/TVServer.swift` + `TVHTTPHandler.swift` — GET/HEAD/OPTIONS only, CORS `*`, no listings, no dotfiles, only `.json/.jpg/.jpeg/.png/.webp`, symlink/traversal-safe, optional token (`?token=` or `Authorization: Bearer`), 16 KB header cap, 10 s request timeout |
| Mac UI | **Album → Publish to TV…** (`Views/TVPublishView.swift`, `ViewModels/TVPublishViewModel.swift`) |
| Headless CLI | `SIV tv-publish`, `SIV tv-serve` (`Services/TVCommandLine.swift`) |
| TV app | `tv/` — ES5 HTML/CSS/JS for older Tizen; `js/lib.js` pure logic, `js/app.js` UI; `tv/build.sh` packages `.wgt` |

**Output sizes:** thumbs 480 px, full 2560 px long edge (≈1 MB per 24 MP photo; 40-photo sample = 43 MB). First publish ≈0.1 s/photo on Apple silicon; re-publish with no changes is instant.

### Tests

| Command | What it covers |
|---------|----------------|
| `make test` | 113 Swift tests, including 78 for TV: export (layout, order, downscale/no upscale, EXIF orientation, GPS/EXIF stripped, sRGB, HEIC→JPEG, missing/corrupt files, incremental reuse, modified/removed pruning, foreign files kept, option changes, progress), HTTP handler (parsing, content types, HEAD, OPTIONS, 405s, 15 traversal/escape cases, token rules, CORS on every response), live TCP server (binary integrity, split packets, idle connections, 40 concurrent requests, 400/431, stop, port-in-use, LAN-vs-loopback binding), view model, CLI parsing, and the API contract script run against a real export |
| `make tv-test` | TV logic: URL normalization, safe paths, index validation, grid navigation, lazy-load window, scrolling, key mapping |
| `make api-test URL=… [TOKEN=…]` | `scripts/tv_api_test.py` — contract test for any server (`--profile generic` for nginx/NAS/cloud): index schema, every image decodes with declared size, CORS, caching, HEAD, security probes |
| `node tv/test/e2e.mjs --app http://127.0.0.1:8000 --server URL [--token T] [--shots DIR]` | TV app in headless Chrome at 1920×1080 driven by remote keys: settings entry, wrong token, grid nav/scroll/lazy thumbs, toolbar, photo view, slideshow auto-advance/pause, Back, persistence, unreachable server, no JS exceptions (needs `make tv-preview` running) |

**Not verified without hardware:** install/sign on a real TV (needs Tizen Studio + Samsung certificate) and Tizen-only APIs (`tvinputdevice` media keys, screensaver suppression, `exit()`), which are wrapped so the app also runs in a browser.

---

## 13. Open decisions (for you)

1. Always-on host at home? → prefer **Variant A**.
2. Need photos when away from home? → add **Variant C** with same index.
3. Want phones in the loop soon? → consider **Immich** instead of static files.
4. Scope of first slice: TV-only prototype with hand-made folder, or SIV export in the same milestone?
