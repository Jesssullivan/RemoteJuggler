/*
 * GPG.chpl - GPG signing integration for RemoteJuggler
 *
 * Part of RemoteJuggler - Backend-agnostic git identity management
 * Provides GPG key discovery, git configuration, and provider verification.
 *
 * Features:
 *   - List and parse GPG secret keys
 *   - Auto-detect GPG key by email address
 *   - Configure git for GPG signing
 *   - Verify GPG key registration with GitLab/GitHub
 *   - Generate helpful URLs for key registration
 */
prototype module GPG {
  use Subprocess;
  use IO;
  use List;
  use FileSystem;
  public use super.Core;
  public use super.ProviderCLI;
  import super.ProviderCLI;

  // ============================================================
  // GPG Key Types
  // ============================================================

  /*
   * Represents a GPG secret key
   */
  record GPGKey {
    var keyId: string;         // Short or long key ID
    var fingerprint: string;   // Full fingerprint
    var email: string;         // Primary email associated with key
    var name: string;          // User name on the key
    var expires: string;       // Expiration date or empty if no expiry
    var algorithm: string;     // Key algorithm (e.g., "ed25519", "rsa4096")
    var created: string;       // Creation date
  }

  // ============================================================
  // GPG Key Discovery
  // ============================================================

  /*
   * Check if GPG is available in PATH
   */
  proc gpgAvailable(): bool {
    try {
      var p = spawn(["which", "gpg"], stdout=pipeStyle.close, stderr=pipeStyle.close);
      p.wait();
      return p.exitCode == 0;
    } catch {
      return false;
    }
  }

  /*
   * List all available GPG secret keys
   *
   * Parses output of: gpg --list-secret-keys --keyid-format=long
   *
   * Returns:
   *   A list of GPGKey records
   */
  proc listKeys(): list(GPGKey) {
    var keys: list(GPGKey);

    if !gpgAvailable() then return keys;

    try {
      var p = spawn(["gpg", "--list-secret-keys", "--keyid-format=long", "--with-colons"],
                    stdout=pipeStyle.pipe,
                    stderr=pipeStyle.close);
      p.wait();

      if p.exitCode != 0 then return keys;

      var output: string;
      p.stdout.readAll(output);

      // Parse colon-delimited output
      // Format: type:validity:keylen:algo:keyid:created:expires:...:uid:...
      var currentKey: GPGKey;
      var hasKey = false;

      for line in output.split("\n") {
        const fields = line.split(":");

        if fields.size < 2 then continue;

        const recordType = fields[0];

        select recordType {
          // Secret key record
          when "sec" {
            // Save previous key if any
            if hasKey && currentKey.keyId != "" {
              keys.pushBack(currentKey);
            }

            // Start new key
            currentKey = new GPGKey();
            hasKey = true;

            if fields.size > 4 then currentKey.keyId = fields[4];
            if fields.size > 5 then currentKey.created = fields[5];
            if fields.size > 6 then currentKey.expires = fields[6];
            if fields.size > 3 {
              // Algorithm is in field 3
              const algoNum = fields[3];
              currentKey.algorithm = gpgAlgorithmName(algoNum);
            }
          }
          // Fingerprint record
          when "fpr" {
            if hasKey && fields.size > 9 {
              currentKey.fingerprint = fields[9];
            }
          }
          // User ID record
          when "uid" {
            if hasKey && fields.size > 9 && currentKey.email == "" {
              // Parse uid field: "Name <email>"
              const uid = fields[9];
              const (parsedName, parsedEmail) = parseUID(uid);
              currentKey.name = parsedName;
              currentKey.email = parsedEmail;
            }
          }
        }
      }

      // Don't forget the last key
      if hasKey && currentKey.keyId != "" {
        keys.pushBack(currentKey);
      }

    } catch {
      // Return empty list on error
    }

    return keys;
  }

  /*
   * Convert GPG algorithm number to human-readable name
   */
  proc gpgAlgorithmName(algoNum: string): string {
    select algoNum {
      when "1" do return "rsa";
      when "16" do return "elgamal";
      when "17" do return "dsa";
      when "18" do return "ecdh";
      when "19" do return "ecdsa";
      when "22" do return "ed25519";
      otherwise do return "unknown";
    }
  }

  /*
   * Parse a UID string like "Name <email@example.com>"
   *
   * Returns:
   *   Tuple of (name, email)
   */
  proc parseUID(uid: string): (string, string) {
    var name = "";
    var email = "";

    const ltIdx = uid.find("<");
    const gtIdx = uid.find(">");

    if ltIdx != -1 && gtIdx != -1 && gtIdx > ltIdx {
      name = uid[..ltIdx-1].strip();
      email = uid[ltIdx+1..gtIdx-1].strip();
    } else {
      // No angle brackets - might be just email or just name
      if uid.find("@") != -1 {
        email = uid.strip();
      } else {
        name = uid.strip();
      }
    }

    return (name, email);
  }

  /*
   * Get GPG key ID for a specific email address
   *
   * Args:
   *   email: The email address to search for
   *
   * Returns:
   *   Tuple of (found, keyId)
   */
  proc getKeyForEmail(email: string): (bool, string) {
    if !gpgAvailable() then return (false, "");

    try {
      // Use gpg to search for keys with this email
      var p = spawn(["gpg", "--list-secret-keys", "--keyid-format=long", "--with-colons", email],
                    stdout=pipeStyle.pipe,
                    stderr=pipeStyle.close);
      p.wait();

      if p.exitCode == 0 {
        var output: string;
        p.stdout.readAll(output);

        // Parse for sec record to get key ID
        for line in output.split("\n") {
          const fields = line.split(":");
          if fields.size > 4 && fields[0] == "sec" {
            return (true, fields[4]);
          }
        }
      }
    } catch {
      // Fall through
    }

    // Alternative: search all keys for matching email
    const allKeys = listKeys();
    for key in allKeys {
      if key.email.toLower() == email.toLower() {
        return (true, key.keyId);
      }
    }

    return (false, "");
  }

  /*
   * Get the public key armor block for a key ID
   *
   * Args:
   *   keyId: The GPG key ID
   *
   * Returns:
   *   Tuple of (success, armorBlock)
   */
  proc exportPublicKey(keyId: string): (bool, string) {
    if !gpgAvailable() then return (false, "");

    try {
      var p = spawn(["gpg", "--armor", "--export", keyId],
                    stdout=pipeStyle.pipe,
                    stderr=pipeStyle.close);
      p.wait();

      if p.exitCode == 0 {
        var armor: string;
        p.stdout.readAll(armor);
        return (true, armor.strip());
      }
    } catch {
      // Fall through
    }
    return (false, "");
  }

  // ============================================================
  // Git GPG Configuration
  // ============================================================

  /*
   * Run git config command
   *
   * Args:
   *   repoPath: Path to the git repository (use "." for current)
   *   key: The config key
   *   value: The config value
   *
   * Returns:
   *   true if successful, false otherwise
   */
  proc gitConfig(repoPath: string, key: string, value: string): bool {
    try {
      var argList: list(string);
      argList.pushBack("git");
      argList.pushBack("-C");
      argList.pushBack(repoPath);
      argList.pushBack("config");
      argList.pushBack(key);
      argList.pushBack(value);

      var p = spawn(argList.toArray(),
                    stdout=pipeStyle.close,
                    stderr=pipeStyle.close);
      p.wait();
      return p.exitCode == 0;
    } catch {
      return false;
    }
  }

  /*
   * Get a git config value
   *
   * Args:
   *   repoPath: Path to the git repository
   *   key: The config key
   *
   * Returns:
   *   Tuple of (found, value)
   */
  proc getGitConfig(repoPath: string, key: string): (bool, string) {
    try {
      var argList: list(string);
      argList.pushBack("git");
      argList.pushBack("-C");
      argList.pushBack(repoPath);
      argList.pushBack("config");
      argList.pushBack("--get");
      argList.pushBack(key);

      var p = spawn(argList.toArray(),
                    stdout=pipeStyle.pipe,
                    stderr=pipeStyle.close);
      p.wait();

      if p.exitCode == 0 {
        var value: string;
        p.stdout.readAll(value);
        return (true, value.strip());
      }
    } catch {
      // Fall through
    }
    return (false, "");
  }

  /*
   * Configure git for GPG signing
   *
   * Args:
   *   repoPath: Path to the git repository
   *   keyId: The GPG key ID to use for signing
   *   signCommits: Whether to sign commits by default
   *   autoSignoff: Whether to add Signed-off-by line (stored in RemoteJuggler config)
   *
   * Returns:
   *   true if all configurations succeeded, false otherwise
   */
  proc configureGitGPG(repoPath: string, keyId: string,
                       signCommits: bool, autoSignoff: bool): bool {
    var success = true;

    // Set signing key
    success = success && gitConfig(repoPath, "user.signingkey", keyId);

    // Enable/disable commit signing
    const signValue = if signCommits then "true" else "false";
    success = success && gitConfig(repoPath, "commit.gpgsign", signValue);

    // Set GPG program (use gpg by default)
    success = success && gitConfig(repoPath, "gpg.program", "gpg");

    // Note: autoSignoff is not a native git config - it's handled by RemoteJuggler
    // via commit hooks or wrapper scripts. We store it in our own config.
    if verbose && autoSignoff {
      writeln("  Note: Auto-signoff enabled (handled by RemoteJuggler hooks)");
    }

    return success;
  }

  /*
   * Remove GPG signing configuration from a repository
   *
   * Args:
   *   repoPath: Path to the git repository
   *
   * Returns:
   *   true if successful
   */
  proc disableGitGPG(repoPath: string): bool {
    var success = true;

    try {
      // Unset signing key
      var p1 = spawn(["git", "-C", repoPath, "config", "--unset", "user.signingkey"],
                     stdout=pipeStyle.close, stderr=pipeStyle.close);
      p1.wait();
      // Don't check exit code - unset returns non-zero if key doesn't exist

      // Disable commit signing
      success = success && gitConfig(repoPath, "commit.gpgsign", "false");
    } catch {
      return false;
    }

    return success;
  }

  // ============================================================
  // Provider GPG Verification
  // ============================================================

  /*
   * Verify GPG key is registered with the provider
   *
   * Args:
   *   identity: The GitIdentity to verify against
   *
   * Returns:
   *   GPGVerifyResult with verification status
   */
  proc verifyKeyWithProvider(identity: GitIdentity): GPGVerifyResult {
    select identity.provider {
      when Provider.GitLab {
        return verifyGitLabGPG(identity);
      }
      when Provider.GitHub {
        return verifyGitHubGPG(identity);
      }
      otherwise {
        return new GPGVerifyResult(
          verified = false,
          message = "GPG verification not supported for " + providerToString(identity.provider),
          settingsURL = ""
        );
      }
    }
  }

  /*
   * Verify GPG key with GitLab
   *
   * Uses glab API to check if the key is registered
   */
  proc verifyGitLabGPG(identity: GitIdentity): GPGVerifyResult {
    const settingsURLVal = getGPGSettingsURL(identity);

    if !ProviderCLI.glabAvailable() {
      return new GPGVerifyResult(
        verified = false,
        message = "glab CLI required for GPG verification",
        settingsURL = settingsURLVal
      );
    }

    // Get the key ID from identity
    var keyId = identity.gpg.keyId;
    if keyId == "auto" || keyId == "" {
      const (found, autoKeyId) = getKeyForEmail(identity.email);
      if !found {
        return new GPGVerifyResult(
          verified = false,
          message = "No GPG key found for email: " + identity.email,
          settingsURL = settingsURLVal
        );
      }
      keyId = autoKeyId;
    }

    // Query GitLab API for GPG keys
    const (ok, response) = ProviderCLI.glabAPI("user/gpg_keys", identity.hostname);

    if !ok {
      return new GPGVerifyResult(
        verified = false,
        message = "Failed to query GitLab GPG keys API",
        settingsURL = settingsURLVal
      );
    }

    // Check if our key ID is in the response
    // Response is JSON array of key objects with "id", "key", etc.
    // We look for our key ID in the response text (simple check)
    if response.find(keyId) != -1 || response.find(keyId.toLower()) != -1 {
      return new GPGVerifyResult(
        verified = true,
        message = "GPG key " + keyId + " is registered with GitLab",
        settingsURL = ""
      );
    }

    // Also check fingerprint if we have it
    const allKeys = listKeys();
    for key in allKeys {
      if key.keyId == keyId && key.fingerprint != "" {
        if response.find(key.fingerprint) != -1 {
          return new GPGVerifyResult(
            verified = true,
            message = "GPG key " + keyId + " is registered with GitLab",
            settingsURL = ""
          );
        }
      }
    }

    return new GPGVerifyResult(
      verified = false,
      message = "GPG key " + keyId + " not found on GitLab",
      settingsURL = settingsURLVal
    );
  }

  /*
   * Verify GPG key with GitHub
   *
   * Uses gh API to check if the key is registered
   */
  proc verifyGitHubGPG(identity: GitIdentity): GPGVerifyResult {
    const settingsURLVal = getGPGSettingsURL(identity);

    if !ProviderCLI.ghAvailable() {
      return new GPGVerifyResult(
        verified = false,
        message = "gh CLI required for GPG verification",
        settingsURL = settingsURLVal
      );
    }

    // Get the key ID from identity
    var keyId = identity.gpg.keyId;
    if keyId == "auto" || keyId == "" {
      const (found, autoKeyId) = getKeyForEmail(identity.email);
      if !found {
        return new GPGVerifyResult(
          verified = false,
          message = "No GPG key found for email: " + identity.email,
          settingsURL = settingsURLVal
        );
      }
      keyId = autoKeyId;
    }

    // Query GitHub API for GPG keys
    const (ok, response) = ProviderCLI.ghAPI("user/gpg_keys", identity.hostname);

    if !ok {
      return new GPGVerifyResult(
        verified = false,
        message = "Failed to query GitHub GPG keys API",
        settingsURL = settingsURLVal
      );
    }

    // Check if our key ID is in the response
    if response.find(keyId) != -1 || response.find(keyId.toLower()) != -1 {
      return new GPGVerifyResult(
        verified = true,
        message = "GPG key " + keyId + " is registered with GitHub",
        settingsURL = ""
      );
    }

    // Also check fingerprint
    const allKeys = listKeys();
    for key in allKeys {
      if key.keyId == keyId && key.fingerprint != "" {
        if response.find(key.fingerprint) != -1 {
          return new GPGVerifyResult(
            verified = true,
            message = "GPG key " + keyId + " is registered with GitHub",
            settingsURL = ""
          );
        }
      }
    }

    return new GPGVerifyResult(
      verified = false,
      message = "GPG key " + keyId + " not found on GitHub",
      settingsURL = settingsURLVal
    );
  }

  // ============================================================
  // Helper URLs
  // ============================================================

  /*
   * Get the URL for GPG key settings on a provider
   *
   * Args:
   *   identity: The GitIdentity
   *
   * Returns:
   *   URL string for the GPG settings page
   */
  proc getGPGSettingsURL(identity: GitIdentity): string {
    select identity.provider {
      when Provider.GitLab {
        return "https://" + identity.hostname + "/-/profile/gpg_keys";
      }
      when Provider.GitHub {
        // GitHub uses a different URL structure
        if identity.hostname == "github.com" {
          return "https://github.com/settings/keys";
        } else {
          // GitHub Enterprise
          return "https://" + identity.hostname + "/settings/keys";
        }
      }
      when Provider.Bitbucket {
        return "https://bitbucket.org/account/settings/gpg-keys/";
      }
      otherwise {
        return "";
      }
    }
  }

  /*
   * Get the GPG export command for user convenience
   *
   * Args:
   *   keyId: The GPG key ID
   *
   * Returns:
   *   The command string to export the public key
   */
  proc getExportCommand(keyId: string): string {
    return "gpg --armor --export " + keyId;
  }

  // ============================================================
  // GPG Status and Diagnostics
  // ============================================================

  /*
   * Get a summary of GPG status for an identity
   *
   * Args:
   *   identity: The GitIdentity
   *
   * Returns:
   *   Formatted status string
   */
  proc getGPGStatus(identity: GitIdentity): string {
    var status: string = "";

    if !gpgAvailable() {
      return "GPG: Not installed\n";
    }

    status += "GPG: Available\n";

    var keyId = identity.gpg.keyId;
    if keyId == "" {
      status += "  Signing: Disabled\n";
      return status;
    }

    if keyId == "auto" {
      const (found, autoKeyId) = getKeyForEmail(identity.email);
      if found {
        keyId = autoKeyId;
        status += "  Key: " + keyId + " (auto-detected from " + identity.email + ")\n";
      } else {
        status += "  Key: Not found for " + identity.email + "\n";
        return status;
      }
    } else {
      status += "  Key: " + keyId + "\n";
    }

    // Get key details
    const allKeys = listKeys();
    for key in allKeys {
      if key.keyId == keyId {
        status += "  Name: " + key.name + "\n";
        status += "  Email: " + key.email + "\n";
        if key.expires != "" {
          status += "  Expires: " + key.expires + "\n";
        }
        break;
      }
    }

    status += "  Sign Commits: " + (if identity.gpg.signCommits then "Yes" else "No") + "\n";
    status += "  Sign Tags: " + (if identity.gpg.signTags then "Yes" else "No") + "\n";
    status += "  Auto Signoff: " + (if identity.gpg.autoSignoff then "Yes" else "No") + "\n";

    return status;
  }

  /*
   * Verify that a GPG key can sign (test signing operation)
   *
   * Args:
   *   keyId: The GPG key ID to test
   *
   * Returns:
   *   true if signing works, false otherwise
   */
  proc testSigning(keyId: string): bool {
    if !gpgAvailable() then return false;

    try {
      // Create a test signature
      var p = spawn(["gpg", "--batch", "--yes", "-u", keyId, "--clearsign"],
                    stdin=pipeStyle.pipe,
                    stdout=pipeStyle.close,
                    stderr=pipeStyle.close);

      p.stdin.write("test");
      p.stdin.close();
      p.wait();

      return p.exitCode == 0;
    } catch {
      return false;
    }
  }

  // ============================================================
  // Hardware Token (YubiKey/SmartCard) Detection
  // ============================================================

  /*
   * Check if a GPG key is stored on a hardware token (YubiKey/SmartCard)
   *
   * Detects hardware keys by looking for stub indicators in the
   * gpg --list-secret-keys output. Keys on smartcards show ">" in
   * the ssb line indicating the private key is a stub.
   *
   * Args:
   *   keyId: The GPG key ID to check
   *
   * Returns:
   *   true if the key is on a hardware token, false otherwise
   */
  proc isHardwareKey(keyId: string): bool {
    if !gpgAvailable() then return false;

    try {
      // Use --with-keygrip to get detailed key info
      var p = spawn(["gpg", "--list-secret-keys", "--with-colons", "--with-keygrip", keyId],
                    stdout=pipeStyle.pipe,
                    stderr=pipeStyle.close);
      p.wait();

      if p.exitCode != 0 then return false;

      var output: string;
      p.stdout.readAll(output);

      // Look for stub indicators in the output
      // In colon format, a stub key has "#" in the field indicating
      // the secret key is not available (only a stub pointing to card)
      // Also check for ">" which indicates card-stored key
      for line in output.split("\n") {
        const fields = line.split(":");
        if fields.size < 2 then continue;

        const recordType = fields[0];

        // Check secret key (sec) and secret subkey (ssb) lines
        if recordType == "sec" || recordType == "ssb" {
          // Field 1 is validity, field 11+ may contain key capabilities
          // Look for "#" indicating stub or ">" indicating card
          if fields.size > 1 {
            const validity = fields[1];
            // "#" means secret key stub (key on card)
            if validity.find("#") != -1 then return true;
          }

          // Also check the entire line for card indicators
          if line.find(">") != -1 then return true;
        }

        // Check for keygrip lines followed by card serial
        // Format: grp:::::::::KEYGRIP:
        // If next line is cardserial, key is on card
        if recordType == "grp" {
          // The presence of a keygrip with subsequent card info indicates hardware
          continue;
        }
      }

      // Alternative: check if gpg --card-status shows this key
      const cardInfo = getCardStatus();
      if cardInfo.present {
        // Check if any of the card's key grips match this key
        var keyGripP = spawn(["gpg", "--list-secret-keys", "--with-keygrip", "--with-colons", keyId],
                             stdout=pipeStyle.pipe, stderr=pipeStyle.close);
        keyGripP.wait();

        if keyGripP.exitCode == 0 {
          var gripOutput: string;
          keyGripP.stdout.readAll(gripOutput);

          for line in gripOutput.split("\n") {
            if line.startsWith("grp:") {
              const grpFields = line.split(":");
              if grpFields.size > 9 {
                const grip = grpFields[9];
                if grip == cardInfo.sigKeyGrip || grip == cardInfo.autKeyGrip {
                  return true;
                }
              }
            }
          }
        }
      }

    } catch {
      // Fall through
    }

    return false;
  }

  /*
   * Get information about the connected hardware token (YubiKey/SmartCard)
   *
   * Parses the output of `gpg --card-status` to extract:
   * - Serial number
   * - Card type and firmware
   * - Touch policies (if YubiKey)
   * - Key grips for signing, encryption, and authentication
   *
   * Returns:
   *   CardInfo record with token details, or empty record if no card
   */
  proc getCardStatus(): CardInfo {
    var info = new CardInfo();

    if !gpgAvailable() then return info;

    try {
      var p = spawn(["gpg", "--card-status", "--with-colons"],
                    stdout=pipeStyle.pipe,
                    stderr=pipeStyle.close);
      p.wait();

      if p.exitCode != 0 then return info;

      var output: string;
      p.stdout.readAll(output);

      // Card present if we got output
      if output.size > 0 {
        info.present = true;
      }

      // Parse colon-delimited output
      for line in output.split("\n") {
        const fields = line.split(":");

        if fields.size < 2 then continue;

        const recordType = fields[0];

        select recordType {
          // Reader info
          when "Reader" {
            // Reader info not in colon format, skip
          }
          // Serial number: serialno:DXXXXXXXX:...
          when "serialno" {
            if fields.size > 1 {
              info.serialNum = fields[1];
            }
          }
          // Card type: cardtype:...
          when "cardtype" {
            if fields.size > 1 {
              info.cardType = fields[1];
            }
          }
          // Card version (firmware): cardversion:X.Y.Z
          when "cardversion" {
            if fields.size > 1 {
              info.firmware = fields[1];
            }
          }
          // Key grip for signing: KEY-FPR:1:FINGERPRINT or similar
          when "fpr" {
            // Fingerprints are listed, but we need keygrips
          }
          // Key attributes (keygrips)
          when "keyattr" {
            // Key attributes line
          }
        }

        // Also parse non-colon format lines
        if line.find("Application ID") != -1 && line.find(":") != -1 {
          // Extract serial from Application ID
          const parts = line.split(":");
          if parts.size > 1 {
            const appId = parts[1].strip();
            // Serial is usually last 8 chars
            if appId.size >= 8 {
              info.serialNum = appId[appId.size-8..];
            }
          }
        }

        if line.find("Version") != -1 && line.find(":") != -1 && line.find("Application") == -1 {
          const parts = line.split(":");
          if parts.size > 1 {
            info.firmware = parts[1].strip();
          }
        }
      }

      // Get touch policies using ykman if available (for YubiKey)
      if info.present {
        const touchInfo = getYubiKeyTouchPolicies();
        info.touchSig = touchInfo.touchSig;
        info.touchEnc = touchInfo.touchEnc;
        info.touchAut = touchInfo.touchAut;
      }

      // Get key grips from card status
      var nonColonP = spawn(["gpg", "--card-status"],
                            stdout=pipeStyle.pipe, stderr=pipeStyle.close);
      nonColonP.wait();

      if nonColonP.exitCode == 0 {
        var rawOutput: string;
        nonColonP.stdout.readAll(rawOutput);

        // Look for card type in human-readable output
        if rawOutput.find("YubiKey") != -1 {
          // Extract YubiKey model
          for line in rawOutput.split("\n") {
            if line.find("Application type") != -1 || line.find("Manufacturer") != -1 {
              if line.find("Yubico") != -1 {
                info.cardType = "YubiKey";
              }
            }
            if line.find("Name of cardholder") != -1 {
              // Skip cardholder name for privacy
            }
          }
        }
      }

    } catch {
      // Return empty info on error
    }

    return info;
  }

  /*
   * Get YubiKey touch policies using ykman CLI
   *
   * Returns:
   *   CardInfo with only touch policies filled in
   */
  proc getYubiKeyTouchPolicies(): CardInfo {
    var info = new CardInfo();

    try {
      // Check if ykman is available
      var whichP = spawn(["which", "ykman"],
                         stdout=pipeStyle.close, stderr=pipeStyle.close);
      whichP.wait();

      if whichP.exitCode != 0 then return info;

      // Get OpenPGP info
      var p = spawn(["ykman", "openpgp", "info"],
                    stdout=pipeStyle.pipe,
                    stderr=pipeStyle.close);
      p.wait();

      if p.exitCode != 0 then return info;

      var output: string;
      p.stdout.readAll(output);

      // Parse touch policies
      // Format: "Touch policy: sig=on enc=on aut=cached"
      // Or individual lines per slot
      for line in output.split("\n") {
        const lineLower = line.toLower();

        if lineLower.find("sig") != -1 && lineLower.find("touch") != -1 {
          if lineLower.find("on") != -1 {
            info.touchSig = "on";
          } else if lineLower.find("cached") != -1 {
            info.touchSig = "cached";
          } else if lineLower.find("off") != -1 || lineLower.find("disabled") != -1 {
            info.touchSig = "off";
          }
        }

        if lineLower.find("enc") != -1 && lineLower.find("touch") != -1 {
          if lineLower.find("on") != -1 {
            info.touchEnc = "on";
          } else if lineLower.find("cached") != -1 {
            info.touchEnc = "cached";
          } else if lineLower.find("off") != -1 || lineLower.find("disabled") != -1 {
            info.touchEnc = "off";
          }
        }

        if lineLower.find("aut") != -1 && lineLower.find("touch") != -1 {
          if lineLower.find("on") != -1 {
            info.touchAut = "on";
          } else if lineLower.find("cached") != -1 {
            info.touchAut = "cached";
          } else if lineLower.find("off") != -1 || lineLower.find("disabled") != -1 {
            info.touchAut = "off";
          }
        }

        // Alternative format: "SIG touch policy: On"
        if line.find("SIG") != -1 && line.find("touch") != -1 {
          if line.find("On") != -1 || line.find("on") != -1 {
            info.touchSig = "on";
          } else if line.find("Cached") != -1 || line.find("cached") != -1 {
            info.touchSig = "cached";
          } else {
            info.touchSig = "off";
          }
        }

        if line.find("ENC") != -1 && line.find("touch") != -1 {
          if line.find("On") != -1 || line.find("on") != -1 {
            info.touchEnc = "on";
          } else if line.find("Cached") != -1 || line.find("cached") != -1 {
            info.touchEnc = "cached";
          } else {
            info.touchEnc = "off";
          }
        }

        if line.find("AUT") != -1 && line.find("touch") != -1 {
          if line.find("On") != -1 || line.find("on") != -1 {
            info.touchAut = "on";
          } else if line.find("Cached") != -1 || line.find("cached") != -1 {
            info.touchAut = "cached";
          } else {
            info.touchAut = "off";
          }
        }
      }

    } catch {
      // Return empty info on error
    }

    return info;
  }

  /*
   * Get comprehensive GPG signing status for an identity
   *
   * This function combines GPG availability, key detection, hardware
   * token status, and signing format to provide agents with all the
   * information needed to determine signing workflow.
   *
   * Args:
   *   identity: The GitIdentity to check
   *
   * Returns:
   *   GPGStatusResult with full signing status
   */
  proc getGPGSigningStatus(identity: GitIdentity): GPGStatusResult {
    var result = new GPGStatusResult();

    result.available = gpgAvailable();

    if !result.available {
      result.message = "GPG is not installed or not in PATH";
      return result;
    }

    // Determine signing format
    if identity.gpg.isSSHFormat() {
      result.format = SigningFormat.SSH;
      result.keyId = identity.gpg.sshKeyPath;

      // For SSH signing, check if the key file exists
      try {
        use FileSystem;
        const keyPath = expandTilde(identity.gpg.sshKeyPath);
        if exists(keyPath) {
          result.canSign = true;
          result.message = "SSH signing configured with " + keyPath;

          // Check if it's a FIDO2 key (hardware)
          if keyPath.find("-sk") != -1 {
            result.isHardwareKey = true;
            result.card = getCardStatus();
            if result.card.present {
              result.message = "SSH signing with FIDO2 hardware key. Touch may be required.";
              result.canSign = !identity.gpg.requiresTouch();
            }
          }
        } else {
          result.canSign = false;
          result.message = "SSH key not found: " + keyPath;
        }
      } catch {
        result.canSign = false;
        result.message = "Error checking SSH key";
      }

      return result;
    }

    // GPG signing
    result.format = SigningFormat.GPG;

    var keyId = identity.gpg.keyId;
    if keyId == "" {
      result.message = "No GPG key configured for this identity";
      return result;
    }

    // Auto-detect key if needed
    if keyId == "auto" {
      const (found, autoKeyId) = getKeyForEmail(identity.email);
      if !found {
        result.message = "No GPG key found for email: " + identity.email;
        return result;
      }
      keyId = autoKeyId;
    }

    result.keyId = keyId;

    // Check if key is on hardware
    result.isHardwareKey = isHardwareKey(keyId);

    if result.isHardwareKey {
      result.card = getCardStatus();

      if !result.card.present {
        result.canSign = false;
        result.message = "GPG key " + keyId + " is on a hardware token, but no token is connected. Insert YubiKey to sign.";
        return result;
      }

      // Hardware key is present, but signing requires touch
      if result.card.touchSig == "on" {
        result.canSign = false;
        result.message = "GPG key " + keyId + " requires physical YubiKey touch for each signature. " +
                        "Agent cannot automate signing. Touch policy: " + result.card.touchSummary();
      } else if result.card.touchSig == "cached" {
        result.canSign = true;
        result.message = "GPG key " + keyId + " on YubiKey with cached touch policy. " +
                        "Touch required once, then cached briefly.";
      } else {
        result.canSign = true;
        result.message = "GPG key " + keyId + " on YubiKey. Touch policy: " + result.card.touchSummary();
      }
    } else {
      // Software key - should work without interaction
      result.canSign = testSigning(keyId);
      if result.canSign {
        result.message = "GPG key " + keyId + " is a software key and can sign automatically.";
      } else {
        result.message = "GPG key " + keyId + " exists but signing test failed. Check passphrase or key validity.";
      }
    }

    return result;
  }

  // ============================================================
  // SSH Signing Support (git 2.34+)
  // ============================================================

  /*
   * Configure git for SSH signing (instead of GPG)
   *
   * Git 2.34+ supports using SSH keys for commit signing.
   * This function configures git to use SSH signing format.
   *
   * Args:
   *   repoPath: Path to the git repository
   *   sshKeyPath: Path to the SSH public key for signing
   *   signCommits: Whether to sign commits by default
   *
   * Returns:
   *   true if all configurations succeeded, false otherwise
   */
  proc configureGitSSHSigning(repoPath: string, sshKeyPath: string,
                               signCommits: bool): bool {
    var success = true;

    // Set signing format to SSH
    success = success && gitConfig(repoPath, "gpg.format", "ssh");

    // Set the SSH signing key
    success = success && gitConfig(repoPath, "user.signingkey", sshKeyPath);

    // Enable/disable commit signing
    const signValue = if signCommits then "true" else "false";
    success = success && gitConfig(repoPath, "commit.gpgsign", signValue);

    // Configure allowed signers file if it exists
    const home = getEnvOrDefault("HOME", "/tmp");
    const allowedSignersPath = home + "/.ssh/allowed_signers";

    try {
      use FileSystem;
      if exists(allowedSignersPath) {
        success = success && gitConfig(repoPath, "gpg.ssh.allowedSignersFile", allowedSignersPath);
      }
    } catch {
      // Ignore errors checking for allowed_signers file
    }

    return success;
  }

  /*
   * Configure git signing based on identity configuration
   *
   * Automatically selects between GPG and SSH signing based on
   * the identity's gpg.format setting.
   *
   * Args:
   *   repoPath: Path to the git repository
   *   identity: The GitIdentity with signing configuration
   *
   * Returns:
   *   Tuple of (success, message) with configuration result
   */
  proc configureIdentitySigning(repoPath: string, identity: GitIdentity): (bool, string) {
    if !identity.gpg.isConfigured() {
      return (true, "No signing configuration for this identity");
    }

    if identity.gpg.isSSHFormat() {
      // SSH signing
      const keyPath = expandTilde(identity.gpg.sshKeyPath);
      const success = configureGitSSHSigning(repoPath, keyPath, identity.gpg.signCommits);

      if success {
        var msg = "Configured SSH signing with " + keyPath;
        if identity.gpg.hardwareKey {
          msg += " (FIDO2 hardware key, touch policy: " + identity.gpg.touchPolicy + ")";
        }
        return (true, msg);
      } else {
        return (false, "Failed to configure SSH signing");
      }
    } else {
      // GPG signing
      var keyId = identity.gpg.keyId;
      if keyId == "auto" {
        const (found, autoKeyId) = getKeyForEmail(identity.email);
        if !found {
          return (false, "No GPG key found for email: " + identity.email);
        }
        keyId = autoKeyId;
      }

      const success = configureGitGPG(repoPath, keyId,
                                       identity.gpg.signCommits, identity.gpg.autoSignoff);

      if success {
        var msg = "Configured GPG signing with key " + keyId;

        // Check for hardware key and add warnings
        if identity.gpg.hardwareKey || isHardwareKey(keyId) {
          msg += " (hardware key";
          if identity.gpg.touchPolicy != "" {
            msg += ", touch policy: " + identity.gpg.touchPolicy;
          }
          msg += " - physical touch required for commits)";
        }
        return (true, msg);
      } else {
        return (false, "Failed to configure GPG signing");
      }
    }
  }
}
