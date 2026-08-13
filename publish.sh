#!/usr/bin/env bash
# Regenerate the public page from the private working copy, then push.
# Refuses to publish if any credential survives the scrub.
set -euo pipefail

SRC="/Users/rochakjain/Desktop/Semex/00-CONTROL/semester-os.html"
REPO="$(cd "$(dirname "$0")" && pwd)"

python3 - "$SRC" "$REPO/index.html" <<'PY'
import sys, pathlib, re

src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
html = src.read_text()

# Redact anything that functions as a credential.
REDACTIONS = [
    (r"Emirates DFXCSF",                         "the Emirates ticket"),
    (r"Emirates ticket DFXCSF",                  "the Emirates ticket"),
    (r"\s*\(ref 5405\.864\.643\)",               ""),
    (r"Booking\.com 5405\.864\.643",             "the accommodation confirmation"),
    (r"The L'Escale booking",                    "The apartment booking"),
    (r"L'Escale",                                "the visa apartment"),
]
for pat, repl in REDACTIONS:
    html = re.sub(pat, repl, html)

# Hard gate: never ship these strings, however they got there.
FORBIDDEN = ["DFXCSF", "5405.864.643", "5563", "IN26-05231", "Henri Dunant", "12-9910"]
leaks = [f for f in FORBIDDEN if f.lower() in html.lower()]
if leaks:
    sys.exit(f"ABORT — credentials still present: {leaks}")

dst.write_text(html)
print(f"scrubbed ok · {len(html):,} bytes")
PY

# Second page: the cost model (contains no credentials by construction, but gated anyway).
python3 - "/Users/rochakjain/Desktop/Semex/02-TRAVEL/budget-model.html" "$REPO/budget.html" <<'PY2'
import sys, pathlib
html = pathlib.Path(sys.argv[1]).read_text()
FORBIDDEN = ["DFXCSF", "5405.864.643", "5563", "IN26-05231", "Henri Dunant", "12-9910"]
leaks = [f for f in FORBIDDEN if f.lower() in html.lower()]
if leaks: sys.exit(f"ABORT — credentials in budget page: {leaks}")
pathlib.Path(sys.argv[2]).write_text(html)
print(f"budget page ok · {len(html):,} bytes")
PY2

cd "$REPO"
if git diff --quiet -- index.html budget.html && [ -z "$(git status --porcelain budget.html)" ]; then
  echo "no changes to publish"; exit 0
fi
git add index.html budget.html
git commit -q -m "${1:-Update planning page}

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push -q origin main
echo "pushed → https://rochakjain361.github.io/grenoble-exchange-os/"
