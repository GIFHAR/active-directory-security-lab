# Enumeration notes

Stuff worth remembering about what each tool actually gives you, written down so
I don't re-learn it next time.

### nmap
- `88 + 389 + 445` together = domain controller. That's the fastest way to pick
  the DC out of a sweep.
- `-sC` grabs the LDAP `rootDSE` and often the domain functional level for free.
- Skip `-A` on a full AD subnet, it's loud and slow. Targeted port lists beat it.

### netexec (nxc)
Formerly CrackMapExec. Same muscle memory, actively maintained. The protocol goes
first: `nxc smb ...`, `nxc ldap ...`, `nxc winrm ...`.

- `nxc ldap <dc>` with no creds often still leaks the domain name and DC FQDN via
  anonymous bind.
- `nxc smb <dc> --pass-pol` before any spraying — lockout threshold decides
  whether a spray is safe or going to lock out the whole domain.
- `--shares` on a null session sometimes finds a readable share with exactly the
  file you don't want left lying around (see the main walkthrough).
- The `(Pwn3d!)` tag means local admin on that host, not just valid creds. Easy
  to misread when you're moving fast.

### user enumeration
Two cheap ways to build a user list without creds:
- Kerberos pre-auth bruteforcing usernames (`kerbrute userenum`) — no failed
  logons logged the same way, since it's AS-REQ, not a real auth attempt.
- RID cycling over SMB null session if the DC allows it.

Once you have a user list you can AS-REP roast the no-preauth ones straight away
(see ../roasting).

### a gotcha
Clock skew. Kerberos is time-sensitive; if your attacker box drifts more than ~5
min from the DC, every Impacket Kerberos call fails with a confusing error.
`ntpdate <dc>` (or `faketime`) fixes it. Lost 20 minutes to this once.
