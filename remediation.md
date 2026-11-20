# Remediation — the blue-team write-up

What I'd actually hand the defenders, in the order I'd fix it. Priorities are by
how much each one shortens the attacker's path, not by how hard they are.

### 1. Get service accounts out of Domain Admins
`svc-databackup` being in DA is what turned a local-admin foothold into full
domain compromise. Backup and service accounts almost never need DA — give them
exactly the rights the job needs, and use gMSA so the password is machine-managed
and un-roastable. This single change breaks the last and worst hop.

### 2. Scope LAPS read rights
LAPS itself is fine; the problem was *who* could read it. The right to read
`ms-Mcs-AdmPwd` should be limited to tier-0 admins, never to another member
server's computer account. Audit the ACL on the LAPS attribute and strip
anything that isn't a dedicated admin group.

### 3. Kill the stored secrets
- Default credentials on the print server — rotate them and put peripherals on a
  segmented VLAN. They're domain-adjacent devices holding service creds; treat
  them that way.
- Plaintext password in a readme on `srv01-documents` — that one's a process
  problem. Credentials in files on shares get found. Push a secrets manager and
  review share permissions so a scan-to-folder account can't read admin notes.

### 4. Reduce the Kerberos attack surface
Even though roasting wasn't on the critical path here, it usually is somewhere:
- long random/gMSA passwords on anything with an SPN,
- remove the "do not require pre-auth" flag unless genuinely needed,
- enforce AES and retire RC4 so the hashes that do leak are far slower to crack.

### 5. Make the path noisy
The attacker was quiet because nothing watched for it. Cheap detections:
- alert on LDAP queries for the LAPS attribute from non-admin principals,
- alert on TGS requests for many SPNs in a short window (Kerberoasting),
- alert on secretsdump/DRSUAPI-style replication from non-DC hosts.

## The one-line version
Four misconfigurations stacked into a full compromise: a DA-level service
account, over-broad LAPS reads, a plaintext password on a share, and default
device creds. Fix #1 and #2 first — they remove the two edges that made DA
reachable at all.
