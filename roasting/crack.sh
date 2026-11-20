#!/usr/bin/env bash
# Thin wrapper around hashcat so I don't have to remember the mode number for
# each kerberos hash type. Detects the format from the hash prefix.
#
#   ./crack.sh asrep.hash
#   ./crack.sh kerb.hash  wordlist.txt
#
# Defaults to rockyou + best64 rules, which cracks most lab-grade passwords.

set -euo pipefail
HASHFILE="${1:?usage: crack.sh <hashfile> [wordlist]}"
WORDLIST="${2:-/usr/share/wordlists/rockyou.txt}"
RULES="/usr/share/hashcat/rules/best64.rule"

first=$(head -n1 "$HASHFILE")
case "$first" in
    \$krb5asrep\$*) mode=18200; label="AS-REP" ;;
    \$krb5tgs\$*)   mode=13100; label="Kerberoast (TGS-REP)" ;;
    *)
        echo "[-] couldn't recognise the hash type from: ${first:0:20}..."
        echo "    pass the hashcat -m mode by hand for this one."
        exit 1 ;;
esac

echo "[*] detected $label -> hashcat -m $mode"
hashcat -m "$mode" "$HASHFILE" "$WORDLIST" -r "$RULES" --quiet
echo
echo "[*] cracked so far:"
hashcat -m "$mode" "$HASHFILE" --show
