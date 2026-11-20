#!/usr/bin/env bash
# Quick AD recon pass. Point it at the subnet, it finds the DC and does the
# low-noise enumeration I always start with. Lab use only.
#
#   ./recon.sh 100.64.5.0/24
#
# Needs: nmap, netexec (nxc). Assumes no creds yet.

set -euo pipefail
SUBNET="${1:?usage: recon.sh <subnet/CIDR>}"
OUT="scans"
mkdir -p "$OUT"

echo "[*] host sweep + common AD ports"
nmap -Pn -n --open -p 53,88,135,139,389,445,464,636,3268,3389,5985 \
     "$SUBNET" -oG "$OUT/sweep.gnmap" | grep -E "Nmap scan|open" || true

# a DC answers on 88 (kerberos) and 389 (ldap) - pull those out
DCS=$(awk '/88\/open/ && /389\/open/ {print $2}' "$OUT/sweep.gnmap")
if [[ -z "$DCS" ]]; then
    echo "[-] no obvious DC (88+389) found; check the sweep manually"
    exit 0
fi

for dc in $DCS; do
    echo "[*] $dc looks like a DC - pulling domain info over LDAP"
    # null/anonymous bind often leaks the domain + naming context
    nxc ldap "$dc" 2>/dev/null | tee -a "$OUT/ldap.txt"

    echo "[*] SMB null session check on $dc"
    nxc smb "$dc" -u '' -p '' --shares 2>/dev/null | tee -a "$OUT/smb-null.txt" || true

    # password policy matters before you spray anything
    echo "[*] password policy"
    nxc smb "$dc" -u '' -p '' --pass-pol 2>/dev/null | tee -a "$OUT/pass-pol.txt" || true
done

echo "[+] done. next: user enumeration, then asrep-roast the no-preauth accounts"
