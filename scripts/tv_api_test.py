#!/usr/bin/env python3
"""Contract test for the SIV TV library HTTP API.

Runs against any server that hosts a published library (SIV's built-in server,
nginx, a NAS, a cloud bucket) and checks what the Tizen app relies on:

  GET  /index.json            JSON index, CORS-enabled, no-cache
  GET  /<photo.thumb|full>    image bytes, matching declared dimensions
  HEAD on the same paths

With --profile siv (default) it also probes the read-only / path-safety rules of
SIV's built-in server. Use --profile generic for third-party servers; security
probes then report warnings instead of failures.

Exit code 0 = all required checks passed.

Examples:
  scripts/tv_api_test.py --url http://192.168.1.50:8080
  scripts/tv_api_test.py --url http://192.168.1.50:8080 --token 3f9a... --all
  scripts/tv_api_test.py --url https://photos.example.com/lib --profile generic
"""

import argparse
import datetime
import http.client
import json
import socket
import struct
import sys
import urllib.parse

SCHEMA_VERSION = 1
THUMB_MAX_EDGE = 480
FULL_MAX_EDGE = 3840


class Result:
    def __init__(self, verbose):
        self.verbose = verbose
        self.passed = 0
        self.failures = []
        self.warnings = []

    def check(self, ok, name, detail=""):
        if ok:
            self.passed += 1
            if self.verbose:
                print("  ok    " + name)
        else:
            self.failures.append(name + (": " + detail if detail else ""))
            print("  FAIL  " + name + (": " + detail if detail else ""))
        return ok

    def warn(self, name, detail=""):
        self.warnings.append(name + (": " + detail if detail else ""))
        print("  warn  " + name + (": " + detail if detail else ""))


class Client:
    def __init__(self, base_url, token, timeout):
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme not in ("http", "https") or not parsed.hostname:
            raise SystemExit("--url must look like http://host:port[/prefix]")
        self.scheme = parsed.scheme
        self.host = parsed.hostname
        self.port = parsed.port or (443 if parsed.scheme == "https" else 80)
        self.prefix = parsed.path.rstrip("/")
        self.token = token
        self.timeout = timeout

    def target(self, path, with_token=True):
        target = self.prefix + "/" + path.lstrip("/")
        if self.token and with_token:
            target += ("&" if "?" in target else "?") + "token=" + urllib.parse.quote(self.token)
        return target

    def request(self, method, path, with_token=True, headers=None):
        cls = http.client.HTTPSConnection if self.scheme == "https" else http.client.HTTPConnection
        conn = cls(self.host, self.port, timeout=self.timeout)
        try:
            conn.request(method, self.target(path, with_token), headers=headers or {})
            resp = conn.getresponse()
            body = resp.read()
            return resp.status, {k.lower(): v for k, v in resp.getheaders()}, body
        finally:
            conn.close()

    def raw(self, request_line):
        """Send an unnormalized request (http.client would not send '..' as-is)."""
        if self.scheme != "http":
            return None
        with socket.create_connection((self.host, self.port), timeout=self.timeout) as sock:
            sock.sendall(request_line.encode("latin-1") + b"\r\nHost: " + self.host.encode() + b"\r\n\r\n")
            data = b""
            while True:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                data += chunk
        try:
            return int(data.split(b" ", 2)[1])
        except (IndexError, ValueError):
            return None


def parse_iso8601(value):
    if not isinstance(value, str):
        return None
    try:
        return datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def image_size(data):
    """Return (kind, width, height) for JPEG/PNG/WebP bytes, or (kind, None, None)."""
    if data[:3] == b"\xff\xd8\xff":
        i = 2
        while i + 9 < len(data):
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            length = struct.unpack(">H", data[i + 2:i + 4])[0]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                height, width = struct.unpack(">HH", data[i + 5:i + 9])
                return "jpeg", width, height
            i += 2 + length
        return "jpeg", None, None
    if data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) >= 24:
        width, height = struct.unpack(">II", data[16:24])
        return "png", width, height
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp", None, None
    return None, None, None


def is_safe_relative(path):
    if not isinstance(path, str) or not path:
        return False
    parsed = urllib.parse.urlsplit(path)
    if parsed.scheme or parsed.netloc or path.startswith("/") or "\\" in path:
        return False
    return all(seg not in ("", ".", "..") and not seg.startswith(".") for seg in parsed.path.split("/"))


def validate_index(index, r):
    r.check(isinstance(index, dict), "index is a JSON object")
    if not isinstance(index, dict):
        return []
    r.check(index.get("version") == SCHEMA_VERSION, "index.version == %d" % SCHEMA_VERSION, repr(index.get("version")))
    r.check(parse_iso8601(index.get("generatedAt")) is not None, "index.generatedAt is ISO-8601", repr(index.get("generatedAt")))
    if "albumName" in index:
        r.check(isinstance(index["albumName"], str), "index.albumName is a string")
    photos = index.get("photos")
    if not r.check(isinstance(photos, list), "index.photos is a list"):
        return []

    ids = set()
    valid = []
    for n, p in enumerate(photos):
        label = "photos[%d]" % n
        if not r.check(isinstance(p, dict), label + " is an object"):
            continue
        ok = True
        ok &= r.check(isinstance(p.get("id"), str) and p["id"] != "", label + ".id is a non-empty string")
        ok &= r.check(p.get("id") not in ids, label + ".id is unique", repr(p.get("id")))
        ids.add(p.get("id"))
        ok &= r.check(isinstance(p.get("title"), str), label + ".title is a string")
        for key in ("thumb", "full"):
            ok &= r.check(is_safe_relative(p.get(key)), label + "." + key + " is a safe relative path", repr(p.get(key)))
        for key in ("width", "height"):
            v = p.get(key)
            ok &= r.check(isinstance(v, int) and not isinstance(v, bool) and v > 0, label + "." + key + " is a positive int", repr(v))
        if p.get("takenAt") is not None:
            ok &= r.check(parse_iso8601(p["takenAt"]) is not None, label + ".takenAt is ISO-8601 or null", repr(p["takenAt"]))
        if ok:
            valid.append(p)
    return valid


def check_image(client, photo, key, r, profile):
    label = "%s %s" % (key, photo[key])
    status, headers, body = client.request("GET", photo[key])
    if not r.check(status == 200, label + " -> 200", str(status)):
        return
    r.check(headers.get("content-type", "").startswith("image/"), label + " content-type image/*", headers.get("content-type", ""))
    cors = headers.get("access-control-allow-origin")
    if profile == "siv":
        r.check(cors == "*", label + " has CORS header", repr(cors))
    elif cors is None:
        r.warn(label + " has no CORS header", "fine for <img>, but keep it consistent")
    kind, width, height = image_size(body)
    if not r.check(kind is not None, label + " is JPEG/PNG/WebP", body[:8].hex()):
        return
    if kind != "jpeg":
        r.warn(label + " is " + kind, "SIV publishes JPEG; older TVs decode JPEG most reliably")
    if width is None:
        return
    edge = max(width, height)
    if key == "full":
        r.check((width, height) == (photo["width"], photo["height"]), label + " dimensions match index",
                "%dx%d vs %dx%d" % (width, height, photo["width"], photo["height"]))
        if edge > FULL_MAX_EDGE:
            r.warn(label + " long edge %d > %d" % (edge, FULL_MAX_EDGE), "large images slow the TV")
    else:
        r.check(abs(width / height - photo["width"] / photo["height"]) < 0.05, label + " aspect ratio matches full")
        if edge > THUMB_MAX_EDGE:
            r.warn(label + " long edge %d > %d" % (edge, THUMB_MAX_EDGE), "grid will load slowly")


def security_probes(client, sample, r, profile):
    def expect(cond, name, detail=""):
        if profile == "siv":
            r.check(cond, name, detail)
        elif not cond:
            r.warn(name, detail)

    for method in ("POST", "PUT", "DELETE", "PATCH"):
        status, _, _ = client.request(method, "index.json", headers={"Content-Length": "0"})
        expect(status == 405 if profile == "siv" else status >= 400, "%s /index.json rejected" % method, str(status))

    status, _, body = client.request("GET", "thumbs/")
    expect(status != 200 or b"<a href" not in body.lower(), "no directory listing at /thumbs/", str(status))
    status, _, _ = client.request("GET", ".DS_Store")
    expect(status == 404, "dotfiles not served", str(status))
    status, _, _ = client.request("GET", "index.json.bak")
    expect(status == 404, "unknown files not served", str(status))

    query = "?token=" + urllib.parse.quote(client.token) if client.token else ""
    for attack in ("/../etc/passwd", "/thumbs/../../etc/passwd", "/%2e%2e/%2e%2e/etc/passwd", "/thumbs%2f..%2f..%2fetc%2fpasswd"):
        code = client.raw("GET " + client.prefix + attack + query + " HTTP/1.1")
        if code is not None:
            expect(code in (400, 403, 404), "traversal %s blocked" % attack, str(code))

    status, headers, _ = client.request("OPTIONS", "index.json")
    if profile == "siv":
        r.check(status == 204, "OPTIONS preflight -> 204", str(status))
        r.check("GET" in headers.get("access-control-allow-methods", ""), "preflight allows GET")

    if client.token:
        status, _, _ = client.request("GET", "index.json", with_token=False)
        r.check(status == 401, "index.json without token -> 401", str(status))
        if sample:
            status, _, _ = client.request("GET", sample[0]["thumb"], with_token=False)
            r.check(status == 401, "image without token -> 401", str(status))
        status, _, _ = client.request("GET", "index.json", with_token=False, headers={"Authorization": "Bearer " + client.token})
        r.check(status == 200, "Bearer token accepted", str(status))
        original = client.token
        client.token = original[:-1] + ("0" if original[-1] != "0" else "1")
        status, _, _ = client.request("GET", "index.json")
        client.token = original
        r.check(status == 401, "wrong token -> 401", str(status))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", required=True, help="library base URL, e.g. http://192.168.1.50:8080")
    ap.add_argument("--token", default=None, help="access token configured in SIV (optional)")
    ap.add_argument("--profile", choices=("siv", "generic"), default="siv")
    ap.add_argument("--all", action="store_true", help="check every photo (default: first 10)")
    ap.add_argument("--sample", type=int, default=10)
    ap.add_argument("--min-photos", type=int, default=0, help="fail if index has fewer photos")
    ap.add_argument("--timeout", type=float, default=10)
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args(argv)

    client = Client(args.url, args.token, args.timeout)
    r = Result(args.verbose)
    print("SIV TV API test: %s (profile=%s%s)" % (args.url, args.profile, ", token" if args.token else ""))

    try:
        print("[index]")
        status, headers, body = client.request("GET", "index.json")
        if not r.check(status == 200, "GET /index.json -> 200", str(status)):
            return finish(r)
        ctype = headers.get("content-type", "")
        r.check(ctype.startswith("application/json"), "index content-type is JSON", ctype)
        cors = headers.get("access-control-allow-origin")
        r.check(cors == "*", "index has Access-Control-Allow-Origin: *", repr(cors) + " (Tizen app fetch needs CORS)")
        cache = headers.get("cache-control", "")
        fresh = any(v in cache for v in ("no-cache", "no-store", "max-age=0"))
        if args.profile == "siv":
            r.check(fresh, "index Cache-Control no-cache", repr(cache))
        elif not fresh:
            r.warn("index may be cached by the TV", repr(cache))
        try:
            index = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, ValueError) as e:
            r.check(False, "index is valid UTF-8 JSON", str(e))
            return finish(r)
        photos = validate_index(index, r)
        count = len(index.get("photos", [])) if isinstance(index, dict) else 0
        r.check(count >= args.min_photos, "index has >= %d photos" % args.min_photos, str(count))

        status, headers, body = client.request("HEAD", "index.json")
        r.check(status == 200 and body == b"", "HEAD /index.json -> 200, empty body", str(status))
        if args.profile == "siv":
            r.check(headers.get("content-length", "").isdigit(), "HEAD has Content-Length")

        sample = photos if args.all else photos[: args.sample]
        print("[images] checking %d of %d photo(s)" % (len(sample), len(photos)))
        for photo in sample:
            check_image(client, photo, "thumb", r, args.profile)
            check_image(client, photo, "full", r, args.profile)
        if sample:
            status, headers, body = client.request("HEAD", sample[0]["full"])
            r.check(status == 200 and body == b"", "HEAD image -> 200, empty body", str(status))

        print("[security]")
        security_probes(client, sample, r, args.profile)
    except (OSError, http.client.HTTPException) as e:
        r.check(False, "server reachable", "%s: %s" % (type(e).__name__, e))

    return finish(r)


def finish(r):
    print("\n%d passed, %d failed, %d warning(s)" % (r.passed, len(r.failures), len(r.warnings)))
    return 1 if r.failures else 0


if __name__ == "__main__":
    sys.exit(main())
