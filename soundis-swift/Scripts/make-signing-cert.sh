#!/usr/bin/env bash
# Create a stable self-signed code-signing identity so macOS remembers the app's
# permissions (Screen Recording, Microphone) across launches AND rebuilds.
#
# Ad-hoc signing (`codesign -s -`) gives every build a different code identity,
# so TCC re-asks every time. A self-signed cert gives one stable identity, so a
# single grant sticks forever.
#
# Run this ONCE:
#   ./Scripts/make-signing-cert.sh
# then rebuild with ./Scripts/make-app.sh (it auto-uses this identity).
set -euo pipefail

IDENTITY="Soundis Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
P12PASS="soundis-local"

if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "✔ signing identity '$IDENTITY' already exists — nothing to do"
  exit 0
fi

# Prefer OpenSSL 3 (its -legacy PKCS#12 is importable by macOS `security`);
# LibreSSL's modern defaults trip "MAC verification failed" on import.
OPENSSL=/usr/bin/openssl
for o in /opt/homebrew/bin/openssl /usr/local/bin/openssl; do [ -x "$o" ] && OPENSSL="$o" && break; done
LEGACY=""; "$OPENSSL" pkcs12 -help 2>&1 | grep -q -- '-legacy' && LEGACY="-legacy"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

echo "==> generating self-signed code-signing certificate ($OPENSSL)"
"$OPENSSL" req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 \
  -config "$TMP/cert.conf" -extensions ext >/dev/null 2>&1

"$OPENSSL" pkcs12 -export $LEGACY -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout "pass:$P12PASS" -name "$IDENTITY" >/dev/null 2>&1

echo "==> importing into login keychain (-A: codesign may use it without prompting)"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$P12PASS" -A

echo "✔ created signing identity '$IDENTITY'"
echo "  next: ./Scripts/make-app.sh   (now signs with this stable identity)"
