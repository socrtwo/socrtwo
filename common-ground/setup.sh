#!/data/data/com.termux/files/usr/bin/bash
# Common Ground - one-shot Termux setup.
# Creates ~/projects/common-ground, writes all files, tests them,
# and publishes a PUBLIC GitHub repo named "common-ground".
# Usage:  curl -sLO <raw-url-of-this-file> && bash setup.sh
set -euo pipefail
REPO_NAME="${REPO_NAME:-common-ground}"

echo "==> Installing packages"
pkg update -y && pkg upgrade -y
pkg install -y git gh openssh python python-cryptography || {
  pkg install -y git gh openssh python rust; pip install cryptography; }
pip install flask

echo "==> Git identity"
if [ -z "$(git config --global user.name || true)" ]; then
  read -rp "Your name for git commits: " GN; git config --global user.name "$GN"; fi
if [ -z "$(git config --global user.email || true)" ]; then
  read -rp "Your email for git commits: " GE; git config --global user.email "$GE"; fi
git config --global init.defaultBranch main

echo "==> GitHub login"
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git

if [ -e ~/projects/common-ground ]; then
  echo "~/projects/common-ground already exists; move or delete it first."; exit 1; fi

echo "==> Writing files"
mkdir -p ~/projects/common-ground/src ~/projects/common-ground/docs
cd ~/projects/common-ground

cat > README.md <<'EOF'
# Common Ground

An anonymous dialogue forum between verified ICE employees and the public.

- Join with one click: random handle + secret key; no email, phone, or IP stored.
- Agents earn a "Verified ICE employee" badge with an agency-issued
  blind-signed token (docs/VERIFICATION.md). The site cannot tell which
  employee a badge belongs to.
- Narrow moderation (docs/MODERATION.md): five fixed rules, removals must
  cite a rule, time-limited mutes, every action in a public mod log.

## Run locally
    cd src
    ADMIN_KEY=$(python3 -c "import secrets;print(secrets.token_urlsafe(16))") python3 app.py
Open http://127.0.0.1:5000

## Try the agent badge
    python3 make_demo_token.py    # prints a token; paste it at /verify
EOF

cat > .gitignore <<'EOF'
__pycache__/
venv/
.venv/
.env
*.db
*.pem
*.key
keyring.json
demo_issuer/
EOF

cat > docs/MODERATION.md <<'EOF'
# Moderation Policy

## Rules (the only grounds for removal)
1. No doxxing: never post names, photos, addresses, or identifying details of anyone.
2. No operational information: no planned actions, locations, or case specifics.
3. No threats, harassment, or slurs.
4. Argue with ideas, not people. Good-faith disagreement is welcome.
5. Do not claim to be an agent without the verified badge.

## Principles
- Remove for rule violations only; viewpoint is never grounds for removal.
- Every removal cites a rule; removed posts leave a visible placeholder.
- Mutes are time-limited, not permanent bans.
- Every action appears in the public mod log (/modlog).
- Staff the moderator team from both sides (at least one verified agent
  and one community member).
EOF

cat > docs/VERIFICATION.md <<'EOF'
# Agent Verification — ICE-Sanctioned Anonymous Credentials

## Goal
ICE authorizes which employees may carry a "Verified ICE employee" badge,
while neither ICE nor the platform can link a badge to a person.

## Protocol (blind signatures, Privacy Pass architecture)
1. ICE publishes one RSA public key per epoch (quarterly) at a fixed
   agency URL; the platform pins it.
2. Agent authenticates to ICE's Issuer via PIV/SSO.
3. Agent's device creates token {epoch, random nonce}, blinds it, sends it.
4. Issuer checks quota (N tokens/employee/epoch), signs the blinded value,
   stores only a count.
5. Agent unblinds -> valid ICE signature on a token ICE never saw.
6. Agent redeems at platform after a random delay; platform verifies
   against the epoch key and records nullifier = SHA-256(nonce).

## Properties
- Agency control: no tokens without ICE authentication; ICE can end the
  program by not publishing keys.
- Unlinkability: holds even if ICE and the platform pool records
  (only timing metadata remains; mitigated by batch issuance + delay).
- Revocation: epoch expiry; separated employees cannot renew.
- Sybil limit: N tokens/epoch, single-use.

## Required operational rules
- Platform keeps no IP logs; supports Tor/onion access.
- Badge states only "ICE employee" — no component, rank, or office.
- Platform publicly discloses that it trusts the issuer's attestation.
- Production crypto: audited RFC 9474 (RSABSSA) library; Privacy Pass
  issuance per RFC 9578.

## Governance (MOU with ICE)
- Signed by ICE Office of Public Affairs + legal counsel.
- Defines eligible employee categories.
- Participation voluntary; ICE receives no data beyond issuance counts.
- Defines prohibited content (non-public operational info, PII, case details).

## Fallback issuers
If ICE declines: a neutral employment verifier (e.g., university ombuds) or
an employee union. Code is identical; only the published key changes.
EOF

cat > src/blindtoken.py <<'EOF'
"""
Blind-RSA anonymous credential tokens for Common Ground (PROTOTYPE).

Roles:
  Issuer   - run by ICE (or an ICE-designated office). Checks employment
             via PIV/SSO, then signs BLINDED tokens. Never sees the token.
  Holder   - the agent. Creates a random token, blinds it, gets it signed,
             unblinds it, redeems it at the platform.
  Verifier - the platform. Checks the signature against the issuer's
             published public key for that epoch; records a nullifier so a
             token can only be redeemed once.

Scheme: RSA full-domain-hash blind signature. Production must use an audited
RFC 9474 (RSABSSA) implementation inside a Privacy Pass (RFC 9576/9578) flow.
"""
import hashlib, json, os, secrets, sqlite3, time
from math import gcd
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

def _fdh(msg: bytes, n: int) -> int:
    """Full-domain hash: expand SHA-256 to modulus length, reduce mod n."""
    k = (n.bit_length() + 7) // 8
    out, ctr = b"", 0
    while len(out) < k:
        out += hashlib.sha256(b"CG-FDH" + ctr.to_bytes(4, "big") + msg).digest()
        ctr += 1
    return int.from_bytes(out[:k], "big") % n

def _b64i(i: int) -> str: return hex(i)
def _i(s: str) -> int: return int(s, 16)

# ---------------------------------------------------------------- Issuer
class Issuer:
    """One RSA key per epoch. Old epochs expire, so separated employees
    simply cannot renew -- no per-person revocation list needed."""
    def __init__(self, keydir: str, tokens_per_epoch: int = 3):
        self.keydir, self.quota = keydir, tokens_per_epoch
        os.makedirs(keydir, exist_ok=True)
        self.db = sqlite3.connect(os.path.join(keydir, "issuance.db"))
        # Stores ONLY a count per employee per epoch, never what was signed.
        self.db.execute("CREATE TABLE IF NOT EXISTS quota"
                        "(emp_hash TEXT, epoch TEXT, n INT, PRIMARY KEY(emp_hash, epoch))")

    def _keypath(self, epoch): return os.path.join(self.keydir, f"{epoch}.pem")

    def new_epoch_key(self, epoch: str):
        key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        with open(self._keypath(epoch), "wb") as f:
            f.write(key.private_bytes(serialization.Encoding.PEM,
                    serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        return self.public_key(epoch)

    def _priv(self, epoch):
        with open(self._keypath(epoch), "rb") as f:
            return serialization.load_pem_private_key(f.read(), None)

    def public_key(self, epoch: str) -> dict:
        pub = self._priv(epoch).public_key().public_numbers()
        return {"epoch": epoch, "n": _b64i(pub.n), "e": pub.e}

    def sign_blinded(self, employee_id: str, epoch: str, blinded_hex: str) -> str:
        """Call ONLY after agency SSO/PIV authentication of employee_id."""
        emp_hash = hashlib.sha256(f"{epoch}:{employee_id}".encode()).hexdigest()
        row = self.db.execute("SELECT n FROM quota WHERE emp_hash=? AND epoch=?",
                              (emp_hash, epoch)).fetchone()
        used = row[0] if row else 0
        if used >= self.quota:
            raise PermissionError("token quota for this epoch exhausted")
        self.db.execute("INSERT OR REPLACE INTO quota VALUES (?,?,?)",
                        (emp_hash, epoch, used + 1)); self.db.commit()
        priv = self._priv(epoch).private_numbers()
        n = priv.public_numbers.n
        return _b64i(pow(_i(blinded_hex), priv.d, n))

# ---------------------------------------------------------------- Holder
class Holder:
    def __init__(self, pubkey: dict):
        self.pk = pubkey; self.n = _i(pubkey["n"]); self.e = pubkey["e"]

    def prepare(self):
        """Returns (state_to_keep_secret, blinded_value_to_send_issuer)."""
        token = {"epoch": self.pk["epoch"], "nonce": secrets.token_hex(32)}
        msg = json.dumps(token, sort_keys=True).encode()
        while True:
            r = secrets.randbelow(self.n - 2) + 2
            if gcd(r, self.n) == 1: break
        blinded = (_fdh(msg, self.n) * pow(r, self.e, self.n)) % self.n
        return {"token": token, "r": _b64i(r)}, _b64i(blinded)

    def finalize(self, state: dict, blind_sig_hex: str) -> dict:
        r_inv = pow(_i(state["r"]), -1, self.n)
        sig = (_i(blind_sig_hex) * r_inv) % self.n
        return {**state["token"], "sig": _b64i(sig)}

# ---------------------------------------------------------------- Verifier
class Verifier:
    def __init__(self, keyring: dict, db):
        self.keyring = keyring          # epoch -> pubkey dict (pinned)
        # db: a path, or an existing sqlite3 connection to share (avoids locks)
        self.db = db if isinstance(db, sqlite3.Connection) else sqlite3.connect(db)
        self.db.execute("CREATE TABLE IF NOT EXISTS spent(nullifier TEXT PRIMARY KEY, epoch TEXT)")

    def redeem(self, tok: dict) -> bool:
        pk = self.keyring.get(tok.get("epoch"))
        if not pk: return False                         # unknown/expired epoch
        n, e = _i(pk["n"]), pk["e"]
        msg = json.dumps({"epoch": tok["epoch"], "nonce": tok["nonce"]}, sort_keys=True).encode()
        if pow(_i(tok["sig"]), e, n) != _fdh(msg, n): return False
        nullifier = hashlib.sha256(bytes.fromhex(tok["nonce"])).hexdigest()
        try:
            self.db.execute("INSERT INTO spent VALUES (?,?)", (nullifier, tok["epoch"]))
            self.db.commit()
        except sqlite3.IntegrityError:
            self.db.rollback()
            return False                                # double-spend
        return True
EOF

cat > src/demo_verification.py <<'EOF'
"""End-to-end demo: python3 src/demo_verification.py"""
import json, os, tempfile
from blindtoken import Issuer, Holder, Verifier

tmp = tempfile.mkdtemp()
epoch = "2026-Q4"

issuer = Issuer(os.path.join(tmp, "issuer"), tokens_per_epoch=3)
pub = issuer.new_epoch_key(epoch)               # ICE publishes this
print("Published key for", epoch, f"({int(pub['n'], 16).bit_length()}-bit modulus)")

agent = Holder(pub)
state, blinded = agent.prepare()                # on agent's own device
blind_sig = issuer.sign_blinded("EMP-12345", epoch, blinded)   # after PIV login
token = agent.finalize(state, blind_sig)        # issuer never saw this token

platform = Verifier({epoch: pub}, os.path.join(tmp, "platform.db"))
print("First redemption: ", platform.redeem(token))
print("Replay attempt:   ", platform.redeem(token))

forged = dict(token, nonce="00" * 32)
print("Forged token:     ", platform.redeem(forged))

for i in range(3):
    try:
        _, b = agent.prepare(); issuer.sign_blinded("EMP-12345", epoch, b)
        print(f"Extra issuance {i+1}: ok")
    except PermissionError as ex:
        print(f"Extra issuance {i+1}: refused ({ex})")
EOF

cat > src/app.py <<'EOF'
"""
Common Ground - anonymous dialogue between verified ICE employees and the public.

Run:   ADMIN_KEY=change-me python3 app.py      ->  http://127.0.0.1:5000
- No email, phone, or IP is stored. Accounts are a random handle + secret key.
- Agents get a "Verified ICE employee" badge by redeeming a blind-signed token
  (see blindtoken.py); the server cannot tell which employee it came from.
- Admins hide posts and mute accounts; every action goes to a public log.
"""
import hashlib, json, logging, os, secrets, sqlite3, time
from flask import Flask, request, redirect, g, abort, make_response, render_template_string
from blindtoken import Verifier

DB = os.environ.get("CG_DB", "commonground.db")
KEYRING = os.environ.get("CG_KEYRING", "keyring.json")
ADMIN_KEY = os.environ.get("ADMIN_KEY")
POST_INTERVAL = 30            # seconds between posts per account
MAX_LEN = 4000

app = Flask(__name__)
logging.getLogger("werkzeug").setLevel(logging.ERROR)   # werkzeug logs IPs; silence it

SCHEMA = """
CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, handle TEXT UNIQUE,
  secret_hash TEXT UNIQUE, agent INT DEFAULT 0, muted_until INT DEFAULT 0,
  last_post INT DEFAULT 0, created INT);
CREATE TABLE IF NOT EXISTS threads(id INTEGER PRIMARY KEY, title TEXT,
  user_id INT, created INT, hidden INT DEFAULT 0);
CREATE TABLE IF NOT EXISTS posts(id INTEGER PRIMARY KEY, thread_id INT,
  user_id INT, body TEXT, created INT, hidden INT DEFAULT 0);
CREATE TABLE IF NOT EXISTS reports(id INTEGER PRIMARY KEY, post_id INT,
  reason TEXT, created INT, resolved INT DEFAULT 0);
CREATE TABLE IF NOT EXISTS modlog(id INTEGER PRIMARY KEY, action TEXT,
  target TEXT, reason TEXT, created INT);
"""

RULES = [
    "No doxxing: never post names, photos, addresses, or identifying details of anyone.",
    "No operational information: no planned actions, locations, or case specifics.",
    "No threats, harassment, or slurs.",
    "Argue with ideas, not people. Good-faith disagreement is welcome.",
    "Do not claim to be an agent without the verified badge.",
]

ADJ = "quiet steady candid patient frank open plain level civil honest".split()
NOUN = "river cedar harbor bridge lantern meadow compass anchor ridge prairie".split()

# ------------------------------------------------------------------ helpers
def db():
    if "db" not in g:
        g.db = sqlite3.connect(DB); g.db.row_factory = sqlite3.Row
        g.db.executescript(SCHEMA)
    return g.db

@app.teardown_appcontext
def _close(_):
    d = g.pop("db", None)
    if d: d.close()

def h(s): return hashlib.sha256(s.encode()).hexdigest()
def now(): return int(time.time())

def current_user():
    s = request.cookies.get("cg_secret")
    return db().execute("SELECT * FROM users WHERE secret_hash=?", (h(s),)).fetchone() if s else None

def is_admin():
    return bool(ADMIN_KEY) and secrets.compare_digest(request.cookies.get("cg_admin", ""), ADMIN_KEY)

def set_cookie(resp, k, v):
    resp.set_cookie(k, v, max_age=3600*24*365, httponly=True, samesite="Strict")
    return resp

def verifier():
    ring = json.load(open(KEYRING)) if os.path.exists(KEYRING) else {}
    return Verifier(ring, db())

def log_mod(action, target, reason):
    db().execute("INSERT INTO modlog(action,target,reason,created) VALUES(?,?,?,?)",
                 (action, target, reason, now())); db().commit()

def can_post(u):
    if not u: return "Join first."
    if u["muted_until"] > now(): return "This account is muted until " + time.strftime("%Y-%m-%d %H:%M", time.gmtime(u["muted_until"])) + " UTC."
    if now() - u["last_post"] < POST_INTERVAL: return f"Please wait {POST_INTERVAL}s between posts."
    return None

def add_post(u, thread_id, body):
    db().execute("INSERT INTO posts(thread_id,user_id,body,created) VALUES(?,?,?,?)",
                 (thread_id, u["id"], body[:MAX_LEN], now()))
    db().execute("UPDATE users SET last_post=? WHERE id=?", (now(), u["id"])); db().commit()

# ------------------------------------------------------------------ template
BASE = """<!doctype html><html><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>Common Ground</title>
<style>
body{font:16px/1.5 system-ui,sans-serif;max-width:760px;margin:auto;padding:0 16px;color:#222;background:#fafafa}
a{color:#1a5fb4} header{display:flex;gap:14px;align-items:center;flex-wrap:wrap;border-bottom:1px solid #ddd;padding:10px 0}
header b{font-size:1.2em;margin-right:auto} .post{background:#fff;border:1px solid #e3e3e3;border-radius:6px;padding:10px 12px;margin:10px 0}
.meta{font-size:.85em;color:#666} .agent{background:#1a5fb4;color:#fff;border-radius:4px;padding:1px 6px;font-size:.8em}
.hidden{color:#999;font-style:italic} textarea,input[type=text]{width:100%;box-sizing:border-box;font:inherit;padding:6px}
button{font:inherit;padding:4px 12px} .msg{background:#fff3cd;padding:8px;border-radius:4px} form.inline{display:inline}
@media(prefers-color-scheme:dark){body{background:#151515;color:#ddd}.post{background:#1f1f1f;border-color:#333}a{color:#8ab4f8}.msg{background:#4a3f12}}
</style></head><body><header><b><a href="/" style="text-decoration:none;color:inherit">Common Ground</a></b>
<a href="/rules">Rules</a><a href="/modlog">Mod log</a>
{% if user %}<span>{{user.handle}}{% if user.agent %} <span class=agent>Verified ICE employee</span>{% endif %}</span>
{% if not user.agent %}<a href="/verify">Agent verification</a>{% endif %}
{% else %}<form class=inline method=post action="/join"><button>Join anonymously</button></form><a href="/login">Log in</a>{% endif %}
{% if admin %}<a href="/admin">Admin</a>{% endif %}</header>
{% if msg %}<p class=msg>{{msg}}</p>{% endif %}{{ body|safe }}</body></html>"""

def page(body_tpl, msg=None, **ctx):
    u = current_user()
    inner = render_template_string(body_tpl, user=u, admin=is_admin(), **ctx)
    return render_template_string(BASE, body=inner, user=u, admin=is_admin(), msg=msg)

POST_TPL = """<div class=post id=p{{p.id}}><div class=meta>{{p.handle}}
{% if p.agent %}<span class=agent>Verified ICE employee</span>{% endif %}
· {{ fmt(p.created) }}{% if user and not p.hidden %} · <form class=inline method=post action="/report/{{p.id}}">
<input type=hidden name=reason value="rule violation"><button style="font-size:.8em">Report</button></form>{% endif %}
{% if admin and not p.hidden %} · <a href="/admin/post/{{p.id}}">moderate</a>{% endif %}</div>
{% if p.hidden %}<p class=hidden>[removed by moderator — see mod log]</p>{% else %}<p style="white-space:pre-wrap">{{p.body}}</p>{% endif %}</div>"""

def fmt(t): return time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(t))

# ------------------------------------------------------------------ routes
@app.get("/")
def index():
    rows = db().execute("""SELECT t.*, u.handle, u.agent,
        (SELECT COUNT(*) FROM posts p WHERE p.thread_id=t.id AND p.hidden=0) n,
        (SELECT MAX(u2.agent) FROM posts p2 JOIN users u2 ON u2.id=p2.user_id
           WHERE p2.thread_id=t.id AND p2.hidden=0) has_agent
        FROM threads t JOIN users u ON u.id=t.user_id WHERE t.hidden=0
        ORDER BY (SELECT MAX(created) FROM posts WHERE thread_id=t.id) DESC LIMIT 100""").fetchall()
    return page("""{% if user %}<h3>Start a conversation</h3><form method=post action="/new">
<input type=text name=title maxlength=150 placeholder="Question or topic" required>
<textarea name=body rows=4 maxlength=4000 placeholder="Say more" required></textarea><button>Post</button></form>{% endif %}
<h3>Conversations</h3>{% for t in rows %}<div class=post><a href="/t/{{t.id}}"><b>{{t.title}}</b></a>
<div class=meta>{{t.handle}}{% if t.agent %} <span class=agent>Verified ICE employee</span>{% endif %}
· {{t.n}} posts{% if t.has_agent %} · agent participating{% endif %}</div></div>
{% else %}<p>No conversations yet.</p>{% endfor %}""", rows=rows)

@app.post("/join")
def join():
    secret = secrets.token_urlsafe(24)
    for _ in range(20):
        handle = f"{secrets.choice(ADJ).title()}{secrets.choice(NOUN).title()}{secrets.randbelow(1000)}"
        try:
            db().execute("INSERT INTO users(handle,secret_hash,created) VALUES(?,?,?)",
                         (handle, h(secret), now())); db().commit(); break
        except sqlite3.IntegrityError: continue
    resp = make_response(render_template_string(BASE, user=None, admin=False, msg=None, body=render_template_string(
        """<h3>You are {{handle}}</h3><p>Your secret key (shown once — save it to log in on another device):</p>
<p><code style="font-size:1.1em">{{secret}}</code></p><p><a href="/">Continue</a></p>""", handle=handle, secret=secret)))
    return set_cookie(resp, "cg_secret", secret)

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        s = request.form.get("secret", "").strip()
        if db().execute("SELECT 1 FROM users WHERE secret_hash=?", (h(s),)).fetchone():
            return set_cookie(redirect("/"), "cg_secret", s)
        return page(LOGIN, msg="Unknown key.")
    return page(LOGIN)
LOGIN = """<h3>Log in</h3><form method=post><input type=text name=secret placeholder="Secret key"><button>Log in</button></form>"""

@app.get("/rules")
def rules():
    return page("""<h3>Rules</h3><ol>{% for r in rules %}<li>{{r}}</li>{% endfor %}</ol>
<p>Moderators remove posts that break these rules and may mute accounts for a set time.
Every action is listed publicly in the <a href="/modlog">mod log</a>. Disagreement alone is never grounds for removal.</p>""", rules=RULES)

@app.route("/verify", methods=["GET", "POST"])
def verify():
    u = current_user()
    if not u: return redirect("/")
    msg = None
    if request.method == "POST":
        try:
            tok = json.loads(request.form.get("token", ""))
            if verifier().redeem(tok):
                db().execute("UPDATE users SET agent=1 WHERE id=?", (u["id"],)); db().commit()
                return redirect("/")
            msg = "Token rejected (invalid, expired, or already used)."
        except (ValueError, KeyError, TypeError):
            msg = "Malformed token."
    return page("""<h3>Agent verification</h3><p>Paste the anonymous token issued to you by the agency's
issuing service. The token proves employment without identifying you; this site stores only a one-way
fingerprint so it cannot be reused.</p><form method=post><textarea name=token rows=6></textarea>
<button>Verify</button></form>""", msg=msg)

@app.post("/new")
def new_thread():
    u = current_user(); err = can_post(u)
    title, body = request.form.get("title", "").strip()[:150], request.form.get("body", "").strip()
    if err or not title or not body: return page("", msg=err or "Title and text required.")
    cur = db().execute("INSERT INTO threads(title,user_id,created) VALUES(?,?,?)", (title, u["id"], now()))
    add_post(u, cur.lastrowid, body)
    return redirect(f"/t/{cur.lastrowid}")

@app.route("/t/<int:tid>", methods=["GET", "POST"])
def thread(tid):
    t = db().execute("SELECT * FROM threads WHERE id=?", (tid,)).fetchone()
    if not t or (t["hidden"] and not is_admin()): abort(404)
    msg = None
    if request.method == "POST":
        u = current_user(); msg = can_post(u); body = request.form.get("body", "").strip()
        if not msg and body:
            add_post(u, tid, body); return redirect(f"/t/{tid}#end")
    posts = db().execute("""SELECT p.*, u.handle, u.agent FROM posts p JOIN users u ON u.id=p.user_id
                            WHERE thread_id=? ORDER BY p.id""", (tid,)).fetchall()
    return page("""<h2>{{t.title}}</h2>{% for p in posts %}""" + POST_TPL + """{% endfor %}<a id=end></a>
{% if user %}<form method=post><textarea name=body rows=4 maxlength=4000 required></textarea><button>Reply</button></form>{% endif %}""",
                msg=msg, t=t, posts=posts, fmt=fmt)

@app.post("/report/<int:pid>")
def report(pid):
    if not current_user(): abort(403)
    db().execute("INSERT INTO reports(post_id,reason,created) VALUES(?,?,?)",
                 (pid, request.form.get("reason", "")[:200], now())); db().commit()
    return page("", msg="Reported. A moderator will review it.")

@app.get("/modlog")
def modlog():
    rows = db().execute("SELECT * FROM modlog ORDER BY id DESC LIMIT 200").fetchall()
    return page("""<h3>Public moderation log</h3>{% for r in rows %}<div class=meta>{{fmt(r.created)}} —
<b>{{r.action}}</b> {{r.target}}: {{r.reason}}</div>{% else %}<p>No actions yet.</p>{% endfor %}""", rows=rows, fmt=fmt)

# ------------------------------------------------------------------ admin
@app.route("/admin", methods=["GET", "POST"])
def admin():
    if request.method == "POST":
        resp = redirect("/admin")
        return set_cookie(resp, "cg_admin", request.form.get("key", ""))
    if not is_admin():
        return page("""<h3>Admin login</h3><form method=post><input type=text name=key><button>Enter</button></form>""")
    reps = db().execute("""SELECT r.id rid, r.reason, p.*, u.handle, u.agent FROM reports r
        JOIN posts p ON p.id=r.post_id JOIN users u ON u.id=p.user_id
        WHERE r.resolved=0 ORDER BY r.id""").fetchall()
    return page("""<h3>Report queue ({{reps|length}})</h3>{% for p in reps %}""" + POST_TPL + """
<form method=post action="/admin/resolve/{{p.rid}}"><button>Dismiss report</button></form>
{% else %}<p>Queue empty.</p>{% endfor %}""", reps=reps, fmt=fmt)

@app.route("/admin/post/<int:pid>", methods=["GET", "POST"])
def admin_post(pid):
    if not is_admin(): abort(403)
    p = db().execute("SELECT p.*, u.handle, u.agent FROM posts p JOIN users u ON u.id=p.user_id WHERE p.id=?", (pid,)).fetchone()
    if not p: abort(404)
    if request.method == "POST":
        rule = request.form.get("rule", "")
        days = int(request.form.get("mute_days", "0") or 0)
        db().execute("UPDATE posts SET hidden=1 WHERE id=?", (pid,))
        db().execute("UPDATE reports SET resolved=1 WHERE post_id=?", (pid,))
        log_mod("removed post", f"#{pid} by {p['handle']}", rule)
        if days > 0:
            db().execute("UPDATE users SET muted_until=? WHERE id=?", (now() + days*86400, p["user_id"]))
            log_mod(f"muted {days}d", p["handle"], rule)
        db().commit()
        return redirect("/admin")
    return page(POST_TPL + """<form method=post><p>Rule broken:</p><select name=rule>
{% for r in rules %}<option>{{r}}</option>{% endfor %}</select>
<p>Mute author for <input type=number name=mute_days value=0 min=0 max=365 style="width:5em"> days (0 = no mute)</p>
<button>Remove post</button></form>""", p=p, rules=RULES, fmt=fmt)

@app.post("/admin/resolve/<int:rid>")
def admin_resolve(rid):
    if not is_admin(): abort(403)
    db().execute("UPDATE reports SET resolved=1 WHERE id=?", (rid,)); db().commit()
    return redirect("/admin")

if __name__ == "__main__":
    if not ADMIN_KEY: print("Warning: ADMIN_KEY not set; admin panel disabled.")
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", 5000)))
EOF

cat > src/make_demo_token.py <<'EOF'
"""
TESTING ONLY: stands in for the agency issuer so you can try the agent badge.
Writes keyring.json (the public key the site trusts) and prints one token.
Real deployment: ICE runs Issuer behind PIV/SSO; the site only gets its public key.
"""
import json, os
from blindtoken import Issuer, Holder

epoch = "demo-epoch"
iss = Issuer("demo_issuer", tokens_per_epoch=100)
pub = iss.public_key(epoch) if os.path.exists(f"demo_issuer/{epoch}.pem") else iss.new_epoch_key(epoch)
json.dump({epoch: pub}, open("keyring.json", "w"))
holder = Holder(pub)
state, blinded = holder.prepare()
token = holder.finalize(state, iss.sign_blinded("TEST-EMPLOYEE", epoch, blinded))
print(json.dumps(token))
EOF

echo "==> Testing"
cd src
python3 demo_verification.py
python3 - <<'PY'
import app
c = app.app.test_client()
assert c.get("/").status_code == 200
print("Forum app loads: OK")
PY
rm -f commonground.db
cd ..

echo "==> Committing and publishing (public)"
git init -q
git add -A
git commit -qm "Initial commit: anonymous agent/public dialogue forum with blind-token verification"
gh repo create "$REPO_NAME" --public --source=. --remote=origin --push \
  --description "Anonymous dialogue forum between verified ICE employees and the public"
echo
echo "Done: $(gh repo view --json url -q .url)"
echo "Run the forum:  cd ~/projects/common-ground/src && ADMIN_KEY=yourkey python3 app.py"
