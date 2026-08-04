# Seafile outbound mail — option B implementation (transactional provider)

## Goal

Seafile sends mail (password resets, share notifications, registration) via a
transactional SMTP relay. Relay also serves as a shared smart-host for future
mlab services (Authelia, Synapse, Zulip, smartd alerts) — one relay, N senders.

## Provider: **Resend** (recommended over Brevo for this use case)

- Free tier: 100 emails/day, 3000/month — far above personal Seafile volume
- SMTP: `smtp.resend.com:587` (STARTTLS), username literally `resend`,
  password = API key (`re_xxxxxxxx`)
- Simplest domain verification of the two (one DKIM TXT; Brevo needs SPF+DKIM+MX)
- Brevo (`smtp-relay.brevo.com:587`, 300/day, SMTP key as both user+pass) is the
  drop-in alternative if Resend signup is a problem — same code, swap 3 values.

## Prerequisites (user does these, outside Nix)

1. **Sign up** at resend.com, add domain `marcel.cool`, copy the **DKIM TXT
   record** Resend shows (format: `resend._domainkey.marcel.cool → "v=DKIM1; k=rsa; p=..."`)
2. **Add DNS records at Cloudflare** (where `marcel.cool` zone lives — confirmed
   via existing `cloudflare_acme_token` sops secret):
   - `resend._domainkey.marcel.cool` TXT → the DKIM value from Resend
     _(Cloudflare: DNS-only / grey-cloud this record, not proxied)_
   - `marcel.cool` TXT (SPF): `v=spf1 include:resend.com ~all`
     _(if a SPF record already exists, merge the `include:resend.com` into it
     instead of adding a second — multiple SPF TXT records are invalid)_
   - `_dmarc.marcel.cool` TXT: `v=DMARC1; p=none; rua=mailto:admin@marcel.cool`
     (`p=none` = monitor only while validating; tighten to `quarantine` later)
3. Wait for Resend to show domain **Verified** (usually <1 min for DKIM).

## Code changes — all in `hosts/mlab/seafile.nix` + `secrets/mlab.yaml`

### 1. sops secret (`secrets/mlab.yaml`)

Add key (encrypt with `sops secrets/mlab.yaml`):

```yaml
seafile_smtp_password: <paste the Resend API key re_xxxxxxxx>
```

### 2. declare the secret in `hosts/mlab/seafile.nix` (~line 12, beside the others)

```nix
      "seafile_db_pass" = {};
      "seafile_jwt_key" = {};
      "seafile_smtp_password" = {};   # add
```

### 3. expose to the app container via the existing env template (~line 22)

Inside `"seafile-app.env".content = '' ... ''`, add one line:

```
        SEAFILE_SMTP_PASSWORD=${config.sops.placeholder.seafile_smtp_password}
```

### 4. append EMAIL\_\* to `seahub_settings.py` in `preStart` (~line 117, after the CSRF block)

```bash
          # Outbound mail (13.0 reads email ONLY from seahub_settings.py, not env;
          # password comes in via SEAFILE_SMTP_PASSWORD env from sops).
          if ! grep -q "EMAIL_HOST" "$SETTINGS"; then
            cat >> "$SETTINGS" <<'EOF'

import os
EMAIL_USE_TLS = True
EMAIL_HOST = "smtp.resend.com"
EMAIL_PORT = 587
EMAIL_HOST_USER = "resend"
EMAIL_HOST_PASSWORD = os.environ["SEAFILE_SMTP_PASSWORD"]
EMAIL_FROM = "seafile@marcel.cool"
SERVER_EMAIL = EMAIL_FROM
EOF
          fi
```

`import os` is required — the existing `seahub_settings.py` does not import it
(verified: file is 845 bytes, no `import`). Guarded by the `EMAIL_HOST` grep so
it's idempotent across restarts and never duplicates.

## Deploy + test

```bash
nixos-rebuild switch --flake .#mlab --target-host root@mlab
```

1. **Web UI**: log in as admin → System Administration → Settings →
   "Send test email" → enter `admin@marcel.cool` → expect "Success"
2. **CLI confirm** the block landed (no restart needed for this check):
   ```bash
   ssh mlab 'grep -A8 EMAIL_HOST /var/lib/seafile/data/seafile/conf/seahub_settings.py'
   ```
3. **Mailbox**: check `admin@marcel.cool` inbox for the test mail
4. **Failure path**: if "Success" but no mail arrives → DNS verification incomplete
   (Re-check Resend shows Verified; `dig TXT resend._domainkey.marcel.cool`).
   If "Connection refused/timeout" → container can't reach `smtp.resend.com:587`
   (`ssh mlab 'nc -zv smtp.resend.com 587'`).

## Future generalization (NOT done now — listed so the relay pays off)

When another mlab service needs mail, repeat the same pattern: per-service
`From:` address (`auth@marcel.cool`, `matrix@marcel.cool`), same SMTP host, same
sops secret (or a second Resend API key if you want per-service isolation).
All addresses share `marcel.cool`, which is already verified — no new DNS work.
Optional later upgrade: 10-line postfix null-client on `localhost:25` in front
of Resend, so services point at `localhost:25` and never see Resend directly.

## Rollback

Revert the 4 code changes + `nixos-rebuild switch`. The appended EMAIL\_\* block
stays harmlessly in `seahub_settings.py` (Django ignores it if it can't connect,
same silent-fail as today) — or `ssh mlab` and delete the block manually.
