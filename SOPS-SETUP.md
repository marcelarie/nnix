# SOPS Setup Notes

## Adding a New Host

### 1. Ensure the Host Has the PGP Key
```bash
gpg --list-secret-keys
```

If the fingerprint is missing, import it:
```bash
gpg --import ~/path/to/backup.pub
```

### 2. Add the Fingerprint to `.sops.yaml`
```yaml
keys:
  - &nixos 7A5F1B23C4D978EF
  - &newhost 1F2E3D4C5B6A7980

creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - pgp:
          - *nixos
          - *newhost
```

### 3. Re-encrypt Secrets
```bash
nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
```

### 4. Commit Changes
```bash
git add .sops.yaml secrets/secrets.yaml
git commit -m "Add new host to sops configuration"
git push
```

### 5. Pull on New Host
```bash
git pull
sudo nixos-rebuild switch
```

## Syncing pass → SOPS

`scripts/pass-to-sops.sh` mirrors the entire pass store into `secrets/secrets.yaml`.

```bash
DEBUG_PASS_TO_SOPS=1 ./scripts/pass-to-sops.sh
```

- `SOPS_FILE` overrides the target SOPS file (default: `secrets/secrets.yaml`).
- `PASSWORD_STORE_DIR` overrides the pass tree (default: `$HOME/.password-store`).
- Each run overwrites encrypted values, so expect new ciphertext even when plaintext stays the same.

## Moving to a New Machine

### On the current machine
```bash
# 1. Export the GPG private key used by SOPS/pass
gpg --export-secret-keys --armor 7A5F1B23C4D978EF > ~/secure-backup/sops-pass-private.asc

# 2. (Optional) Export public key for convenience
gpg --export --armor 7A5F1B23C4D978EF > ~/secure-backup/sops-pass-public.asc

# 3. Commit and push both the git-managed pass store and this repo
git -C ~/clones/own/password-store push
git -C ~/.config/nix push
```

### On the new machine
```bash
# 1. Import the private key
gpg --import ~/secure-backup/sops-pass-private.asc

# 2. Verify it is available
gpg --list-secret-keys

# 3. Clone repositories
git clone git@github.com:you/password-store.git ~/clones/own/password-store
git clone git@github.com:you/nix-config.git ~/.config/nix

# 4. Initialize pass (reusing the fingerprint)
PASSWORD_STORE_DIR=~/clones/own/password-store pass init 7A5F1B23C4D978EF

# 5. Sync SOPS file with pass contents
cd ~/.config/nix
PASSWORD_STORE_DIR=~/clones/own/password-store ./scripts/pass-to-sops.sh

# 6. Activate configuration
sudo nixos-rebuild switch --flake ~/.config/nix#nixos
```

## Troubleshooting

If secrets fail to decrypt:
- Check GPG key exists: `gpg --list-secret-keys`
- Verify fingerprint in `.sops.yaml`
- Re-run `sops updatekeys secrets/secrets.yaml`
