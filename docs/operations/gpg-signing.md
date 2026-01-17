---
title: "GPG Signing"
description: "Configure GPG commit and tag signing per identity. Covers key generation, provider registration, and troubleshooting."
category: "operations"
llm_priority: 3
keywords:
  - gpg
  - signing
  - commits
  - tags
  - keys
---

# GPG Signing

Configure GPG commit and tag signing per identity.

## Overview

GPG signing provides cryptographic verification of commits and tags. RemoteJuggler manages per-identity GPG keys.

## Key Generation

### Create GPG Key

```bash
gpg --full-generate-key
```

Choose:
- Key type: RSA and RSA (default)
- Key size: 4096
- Expiration: 1 year recommended
- Real name: Your name for this identity
- Email: Must match identity email

### Example for Work Identity

```bash
gpg --full-generate-key
# Select RSA and RSA
# 4096 bits
# 1y expiration
# Real name: Work User
# Email: work@company.com
```

## Listing Keys

### All Secret Keys

```bash
gpg --list-secret-keys --keyid-format=long
```

Output:
```
/Users/user/.gnupg/pubring.kbx
------------------------------
sec   rsa4096/ABC123DEF456 2024-01-15 [SC] [expires: 2025-01-15]
      ABCDEF1234567890ABCDEF1234567890ABC123DE
uid                 [ultimate] Work User <work@company.com>
ssb   rsa4096/GHI789JKL012 2024-01-15 [E] [expires: 2025-01-15]
```

### RemoteJuggler Key List

```bash
remote-juggler gpg status
```

Shows:
- Available GPG keys
- Per-identity GPG configuration
- Signing preferences

## Configuration

### Configure Identity GPG

Add to identity configuration:

```json
{
  "identities": {
    "work": {
      "gpg": {
        "keyId": "ABC123DEF456",
        "signCommits": true,
        "signTags": true,
        "autoSignoff": false
      }
    }
  }
}
```

### Auto-Detect Key by Email

```bash
remote-juggler gpg configure work
```

Searches for GPG key matching the identity's email address.

## Provider Registration

GPG keys must be registered with the provider for verification.

### GitLab

1. Export public key:
   ```bash
   gpg --armor --export ABC123DEF456
   ```

2. Go to GitLab > Settings > GPG Keys

3. Paste the public key

### GitHub

1. Export public key:
   ```bash
   gpg --armor --export ABC123DEF456
   ```

2. Go to GitHub > Settings > SSH and GPG keys

3. Click "New GPG key" and paste

### Verification URL

```bash
remote-juggler gpg verify
```

Shows registration status and direct links to settings pages.

## Git Configuration

### Manual Setup

```bash
# Set signing key
git config --global user.signingkey ABC123DEF456

# Enable commit signing
git config --global commit.gpgsign true

# Enable tag signing
git config --global tag.gpgsign true
```

### RemoteJuggler Automatic Setup

When switching identities with GPG configured:

```bash
remote-juggler switch work
```

Automatically sets:
- `user.signingkey`
- `commit.gpgsign`
- `tag.gpgsign` (if configured)

## Signing Operations

### Sign Commits

With `commit.gpgsign = true`:

```bash
git commit -m "Signed commit"
```

Manual signing:

```bash
git commit -S -m "Explicitly signed commit"
```

### Sign Tags

With `tag.gpgsign = true`:

```bash
git tag v1.0.0
```

Manual signing:

```bash
git tag -s v1.0.0 -m "Signed release"
```

### Verify Signatures

```bash
# Verify commit
git log --show-signature -1

# Verify tag
git tag -v v1.0.0
```

## GPG Agent

### Configure Agent

`~/.gnupg/gpg-agent.conf`:

```
default-cache-ttl 3600
max-cache-ttl 86400
pinentry-program /usr/local/bin/pinentry-mac
```

### Restart Agent

```bash
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent
```

## Troubleshooting

### "secret key not available"

Key not found in GPG keyring:

```bash
# List available keys
gpg --list-secret-keys

# Import key if needed
gpg --import private-key.asc
```

### "failed to sign the data"

GPG agent issue:

```bash
# Test GPG signing
echo "test" | gpg --clearsign

# Restart agent
gpgconf --kill gpg-agent
```

### Pinentry Issues (macOS)

Install pinentry-mac:

```bash
brew install pinentry-mac
echo "pinentry-program $(which pinentry-mac)" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

### TTY Issues

Set GPG TTY:

```bash
# Add to ~/.bashrc or ~/.zshrc
export GPG_TTY=$(tty)
```

### Git Commit Hangs

GPG waiting for passphrase input:

```bash
# Use GUI pinentry
echo "pinentry-program /usr/local/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

## Key Management

### Export Public Key

```bash
gpg --armor --export ABC123DEF456 > work-gpg-public.asc
```

### Export Private Key (Backup)

```bash
gpg --armor --export-secret-keys ABC123DEF456 > work-gpg-private.asc
```

Store securely (encrypted backup).

### Key Expiration

Extend key expiration:

```bash
gpg --edit-key ABC123DEF456
gpg> expire
# Set new expiration
gpg> save
```

Re-upload public key to providers after extension.

### Revoke Key

If key is compromised:

```bash
gpg --gen-revoke ABC123DEF456 > revoke.asc
gpg --import revoke.asc
```

Remove from provider settings.

## Multiple Keys Per Identity

Some setups require different keys for commits vs tags:

```json
{
  "gpg": {
    "keyId": "ABC123DEF456",
    "signCommits": true,
    "signTags": true,
    "tagKeyId": "XYZ789ABC123"
  }
}
```

Note: This requires custom git configuration beyond RemoteJuggler's standard setup.

## Hardware Token (YubiKey) Support

RemoteJuggler supports GPG signing with hardware tokens like YubiKey. This section covers setup, touch policies, and agent limitations.

### Overview

Hardware tokens provide enhanced security by storing private keys on tamper-resistant hardware. However, they have specific requirements for signing operations:

- **Physical touch**: YubiKey can require physical touch for each signature
- **Card presence**: The token must be connected when signing
- **Agent limitations**: MCP agents cannot trigger physical touch

### YubiKey Configuration

#### Check YubiKey Status

```bash
# GPG card status
gpg --card-status

# YubiKey Manager (more detailed)
ykman openpgp info
```

#### Touch Policy

YubiKey touch policies control when physical touch is required:

| Policy | Behavior | Agent Compatible |
|--------|----------|------------------|
| `off` | Never require touch | Yes |
| `on` | Always require touch | No - cannot automate |
| `cached` | Touch once, cached 15s | Partially - user must initiate |

Check current touch policies:

```bash
ykman openpgp info | grep -i touch
```

Set touch policy (requires PIN):

```bash
# Set signing to "cached" for better agent compatibility
ykman openpgp keys set-touch sig cached

# Options: off, on, cached, fixed (permanent)
```

### Identity Configuration for Hardware Keys

Configure an identity to use a hardware-backed GPG key:

```json
{
  "identities": {
    "gitlab-personal": {
      "gpg": {
        "keyId": "8547785CA25F0AA8",
        "format": "gpg",
        "signCommits": true,
        "signTags": true,
        "hardwareKey": true,
        "touchPolicy": "on"
      }
    }
  }
}
```

The `hardwareKey` and `touchPolicy` fields enable RemoteJuggler to warn agents about touch requirements.

### SSH Signing Alternative

Git 2.34+ supports SSH key signing, which can use FIDO2 keys on YubiKey:

```json
{
  "identities": {
    "gitlab-work": {
      "gpg": {
        "format": "ssh",
        "sshKeyPath": "~/.ssh/gitlab-work-sk.pub",
        "signCommits": true,
        "hardwareKey": true,
        "touchPolicy": "cached"
      }
    }
  }
}
```

**Advantages of SSH signing:**

- FIDO2 keys can use `aut=cached` touch policy
- SSH agent handles authentication caching
- Simpler toolchain than GPG

**Setup SSH signing:**

```bash
# Configure git for SSH signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/gitlab-work-sk.pub
git config --global commit.gpgsign true

# Create allowed signers file for verification
echo "your@email.com $(cat ~/.ssh/gitlab-work-sk.pub)" >> ~/.ssh/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
```

### MCP Tool: juggler_gpg_status

The `juggler_gpg_status` MCP tool checks signing readiness including hardware token status:

```bash
# Via MCP
remote-juggler --mode=mcp
# Call: juggler_gpg_status with identity="gitlab-personal"
```

**Response includes:**

```json
{
  "identity": "gitlab-personal",
  "signingFormat": "gpg",
  "keyId": "8547785CA25F0AA8",
  "hardwareKey": true,
  "cardPresent": true,
  "cardSerial": "26503492",
  "touchPolicy": {
    "signing": "on",
    "authentication": "cached"
  },
  "canSign": false,
  "reason": "Physical YubiKey touch required for each commit",
  "recommendation": "Ensure YubiKey is connected. Agent will configure identity; user must touch YubiKey when committing."
}
```

### Agent Workflow with Hardware Keys

When agents use `juggler_switch` with a hardware-key identity:

1. **Agent switches identity** - configures git user and signing key
2. **Agent receives warning** - told that touch is required
3. **Agent cannot sign** - must inform user
4. **User commits** - physically touches YubiKey
5. **Commit succeeds** - signature created

**Example switch response:**

```
Switching to identity: gitlab-personal
================================

[OK] Set user.name = Jesssullivan
[OK] Set user.email = jess@sulliwood.org
[OK] Set signing format: gpg
[OK] Set GPG signing key: 8547785CA25F0AA8
[OK] Enabled GPG commit signing

[HARDWARE KEY WARNING]
  GPG signing key 8547785CA25F0AA8 is on a hardware token (YubiKey)
  Touch policy: on - Physical touch required for EACH signature
  Agent CANNOT automate signing - user must touch YubiKey when committing
  Use 'juggler_gpg_status' to check YubiKey presence before committing
```

### Troubleshooting Hardware Keys

#### "No secret key" Error

```
gpg: skipped "8547785CA25F0AA8": No secret key
gpg: signing failed: No secret key
```

**Causes:**

1. YubiKey not connected
2. Wrong signing key configured (placeholder vs real key)
3. GPG agent doesn't see the card

**Fix:**

```bash
# Check card is visible
gpg --card-status

# If not, restart gpg-agent
gpgconf --kill gpg-agent

# Verify correct key ID
gpg --list-secret-keys --keyid-format=long
git config --global user.signingkey  # Should match
```

#### Signing Timeout

GPG waiting for touch that never happens (batch mode):

```bash
# Test signing interactively
echo "test" | gpg -u 8547785CA25F0AA8 --clearsign

# If this works with touch, hardware is fine
# If this hangs, touch policy may be "on" without user awareness
```

#### YubiKey Not Detected

```bash
# Check USB connection
ykman list

# Check GPG sees the card
gpg --card-status

# If "No card" error, try:
# 1. Unplug and replug YubiKey
# 2. Kill and restart gpg-agent
gpgconf --kill gpg-agent
# 3. Check for pcscd conflicts
```

### Best Practices

1. **Use `cached` touch for CI-adjacent workflows** - allows brief automated operation after user touch
2. **Use `on` touch for maximum security** - every signature requires presence proof
3. **Prefer SSH signing for work accounts** - simpler setup, better agent compatibility
4. **Keep GPG signing for personal accounts** - established trust, keyserver publishing
5. **Always set `hardwareKey: true` in config** - enables proper agent warnings
6. **Run `juggler_gpg_status` before signing** - agents should check readiness

### Reference: Touch Policy Comparison

| Scenario | GPG (touch=on) | GPG (touch=cached) | SSH (aut=cached) |
|----------|---------------|-------------------|------------------|
| Single commit | Touch required | Touch required | Touch required |
| Multiple commits (rapid) | Touch each | Touch once | Touch once |
| Agent automation | Not possible | Limited window | Limited window |
| CI/CD signing | Not supported | Not supported | Not supported |
| Maximum security | Best | Good | Good |
| User friction | High | Medium | Medium |
