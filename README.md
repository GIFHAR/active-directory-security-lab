# Active Directory Security Lab

Notes and tooling from the AD attack lab in DTU's Ethical Hacking course (02275).
The goal of the exercise was to go from "nothing but network access" to Domain
Admin on a small `test.local` domain, and then write it up the way you'd hand it
to a client: what the path was, how each step worked, and how to shut it down.

Everything in here is my own write-up against a lab domain. No real credentials,
hashes, or client data — the examples use obviously-fake placeholders and the
actual loot stays out of git (see `.gitignore`).

## The path to DA

The whole domain fell over through a chain of small misconfigurations, none of
which is a CVE:

```
default creds on the print server
        └─► plaintext password left on a share  (srv01-documents)
                └─► RDP onto SRV01
                        └─► BloodHound ingest from inside
                                └─► SRV01 can read LAPS on another host
                                        └─► local admin → svc-databackup
                                                └─► svc-databackup = Domain Admin
```

This is the realistic version of AD compromise. It's rarely one exploit; it's a
chain of "that'll do for now" decisions that connect up.

## Layout

- [`methodology.md`](methodology.md) — the full walkthrough, step by step
- [`enumeration/`](enumeration/) — recon scripts + what each one actually told me
- [`roasting/`](roasting/) — AS-REP roasting and Kerberoasting, with the hashcat side
- [`bloodhound/`](bloodhound/) — the attack-path analysis and my custom Cypher queries
- [`remediation.md`](remediation.md) — the defender write-up (what I'd tell the blue team)

## Tools I leaned on

`nmap` · `netexec` (ex-CrackMapExec) · `impacket` (GetNPUsers, GetUserSPNs,
secretsdump, psexec) · `SharpHound` + `BloodHound CE` · `hashcat` · `Certipy`

## A note on the lab vs the real world

The domain is tiny and deliberately broken, so the path is shorter and cleaner
than a real engagement. What carries over is the method: enumerate, find the
cheapest foothold, pull BloodHound from inside, and let the graph show you the
shortest route to DA rather than guessing.
