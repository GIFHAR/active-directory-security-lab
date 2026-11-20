# BloodHound: reading the path to DA

Once I had a foothold on SRV01, SharpHound from the inside gave a full graph.
BloodHound is only as good as the questions you ask it, so I keep a set of custom
Cypher queries ([`customqueries.json`](customqueries.json)) and run those first
instead of clicking around.

## Collection

```powershell
# authenticated, from SRV01
.\SharpHound.exe -c All --zipfilename sh.zip
```

`-c All` pulls sessions, local admin, ACLs, trusts, GPOs — the ACL and session
data is what actually draws the escalation path, so don't collect less than that
if you can help it.

Load `customqueries.json` into BloodHound CE (import custom queries), then mark
the nodes you control as **Owned** — the whole point is the "from Owned" queries,
and they're empty until you do that.

## What the graph showed

Running "Shortest path to Domain Admins from Owned" drew a three-hop line:

```
SRV01  ──ReadLAPSPassword──►  HOST-02  ──(local admin)──►  svc-databackup  ──MemberOf──►  Domain Admins
```

Two edges did all the damage:

**`ReadLAPSPassword`** — SRV01's computer account (which I controlled) had the
right to read the LAPS-managed local admin password on HOST-02. LAPS is good
hygiene *until* the read permission is scoped too widely; then it just hands you
local admin on another box in one hop. People forget the LAPS attribute is
readable AD data, not a vault.

**svc-databackup in Domain Admins** — HOST-02 had cached creds for a backup
service account, and that account was sitting in Domain Admins. Backup/service
accounts landing in DA "because it needed access to everything" is the single
most common way these graphs end at the crown jewels.

## The manual steps behind the edges

The graph tells you the path exists; you still execute it:

```bash
# read LAPS on HOST-02 using SRV01's context
nxc ldap 100.64.5.10 -u 'SRV01$' -H '<machine-hash>' --module laps

# local admin on HOST-02 -> dump cached creds -> svc-databackup hash
secretsdump.py test.local/administrator@100.64.5.60 -hashes :'<laps-nt>'

# svc-databackup is DA; pass-the-hash to the DC
nxc smb 100.64.5.10 -u svc-databackup -H '<nthash>'   # (Pwn3d!)
```

## Why I lead with BloodHound instead of guessing

On a bigger domain you can't eyeball this. The value is that the graph collapses
"which of 400 accounts and ACLs eventually reaches DA" into one shortest-path
query. Spotting `ReadLAPSPassword` → DA by hand in a real forest would take
hours; the query takes a second. That's the whole argument for graph-based AD
analysis.
