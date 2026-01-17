/*
 * IdentityTests.chpl - Unit tests for Identity module
 *
 * Tests identity registration, lookup, and validation.
 */
prototype module IdentityTests {
  use remote_juggler.Identity;
  use remote_juggler.Core;
  use TestUtils;

  config const verbose = false;

  proc main() {
    writeln("=== RemoteJuggler Identity Module Tests ===\n");

    var passed = 0;
    var failed = 0;

    // Test 1: GitIdentity record creation
    {
      writeln("Test 1: GitIdentity record initialization");
      var allPass = true;

      const identity = new GitIdentity(
        name = "test-identity",
        provider = Provider.GitLab,
        host = "gitlab-test",
        hostname = "gitlab.com",
        user = "testuser",
        email = "test@example.com"
      );

      if identity.name != "test-identity" { allPass = false; writeln("  FAIL: name"); }
      if identity.provider != Provider.GitLab { allPass = false; writeln("  FAIL: provider"); }
      if identity.host != "gitlab-test" { allPass = false; writeln("  FAIL: host"); }
      if identity.hostname != "gitlab.com" { allPass = false; writeln("  FAIL: hostname"); }
      if identity.user != "testuser" { allPass = false; writeln("  FAIL: user"); }
      if identity.email != "test@example.com" { allPass = false; writeln("  FAIL: email"); }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 2: GitIdentity.isValid()
    {
      writeln("Test 2: GitIdentity validity check");
      var allPass = true;

      // Valid identity
      const valid = new GitIdentity(
        name = "valid",
        provider = Provider.GitLab,
        host = "gitlab-test",
        hostname = "gitlab.com",
        user = "user",
        email = "user@example.com"
      );

      if !valid.isValid() {
        writeln("  FAIL: Valid identity should return isValid() = true");
        allPass = false;
      }

      // Invalid - empty name
      const emptyName = new GitIdentity(
        name = "",
        provider = Provider.GitLab,
        host = "gitlab-test",
        hostname = "gitlab.com",
        user = "user",
        email = "user@example.com"
      );

      if emptyName.isValid() {
        writeln("  FAIL: Empty name identity should be invalid");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 3: Identity registration and lookup
    {
      writeln("Test 3: Identity registration and lookup");
      var allPass = true;

      // Clear any existing identities
      clearIdentities();

      const testId = new GitIdentity(
        name = "lookup-test",
        provider = Provider.GitLab,
        host = "gitlab-lookup",
        hostname = "gitlab.com",
        user = "lookupuser",
        email = "lookup@example.com"
      );

      registerIdentity(testId);

      // Verify we can get it back
      const (found, retrieved) = getIdentity("lookup-test");

      if !found {
        writeln("  FAIL: Should find registered identity");
        allPass = false;
      } else if retrieved.name != "lookup-test" {
        writeln("  FAIL: Retrieved identity name mismatch");
        allPass = false;
      } else if retrieved.email != "lookup@example.com" {
        writeln("  FAIL: Retrieved identity email mismatch");
        allPass = false;
      }

      // Verify non-existent identity returns not found
      const (notFound, _) = getIdentity("nonexistent");
      if notFound {
        writeln("  FAIL: Should not find non-existent identity");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }

      // Clean up
      clearIdentities();
    }

    // Test 4: Identity count
    {
      writeln("Test 4: Identity count tracking");
      var allPass = true;

      clearIdentities();

      if identityCount() != 0 {
        writeln("  FAIL: Should start with 0 identities after clear");
        allPass = false;
      }

      registerIdentity(new GitIdentity(
        name = "count-test-1",
        provider = Provider.GitLab,
        host = "host1",
        hostname = "gitlab.com",
        user = "user1",
        email = "user1@example.com"
      ));

      if identityCount() != 1 {
        writeln("  FAIL: Should have 1 identity after first registration");
        allPass = false;
      }

      registerIdentity(new GitIdentity(
        name = "count-test-2",
        provider = Provider.GitHub,
        host = "host2",
        hostname = "github.com",
        user = "user2",
        email = "user2@example.com"
      ));

      if identityCount() != 2 {
        writeln("  FAIL: Should have 2 identities after second registration");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }

      clearIdentities();
    }

    // Test 5: List identities by provider
    {
      writeln("Test 5: List identities by provider");
      var allPass = true;

      clearIdentities();

      // Register identities with different providers
      registerIdentity(new GitIdentity(name = "gl-1", provider = Provider.GitLab, host = "gl1", hostname = "gitlab.com", user = "u1", email = "e1@test.com"));
      registerIdentity(new GitIdentity(name = "gl-2", provider = Provider.GitLab, host = "gl2", hostname = "gitlab.com", user = "u2", email = "e2@test.com"));
      registerIdentity(new GitIdentity(name = "gh-1", provider = Provider.GitHub, host = "gh1", hostname = "github.com", user = "u3", email = "e3@test.com"));

      const gitlabIds = listIdentities(Provider.GitLab);
      if gitlabIds.size != 2 {
        writeln("  FAIL: Should have 2 GitLab identities, got ", gitlabIds.size);
        allPass = false;
      }

      const githubIds = listIdentities(Provider.GitHub);
      if githubIds.size != 1 {
        writeln("  FAIL: Should have 1 GitHub identity, got ", githubIds.size);
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }

      clearIdentities();
    }

    // Test 6: List identity names
    {
      writeln("Test 6: List identity names");
      var allPass = true;

      clearIdentities();

      registerIdentity(new GitIdentity(name = "alpha", provider = Provider.GitLab, host = "a", hostname = "gitlab.com", user = "u", email = "e@t.com"));
      registerIdentity(new GitIdentity(name = "beta", provider = Provider.GitHub, host = "b", hostname = "github.com", user = "u", email = "e@t.com"));

      const names = listIdentityNames();

      if names.size != 2 {
        writeln("  FAIL: Should have 2 identity names, got ", names.size);
        allPass = false;
      }

      var hasAlpha = false;
      var hasBeta = false;
      for name in names {
        if name == "alpha" then hasAlpha = true;
        if name == "beta" then hasBeta = true;
      }

      if !hasAlpha || !hasBeta {
        writeln("  FAIL: Should contain both 'alpha' and 'beta'");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }

      clearIdentities();
    }

    // Test 7: GPGConfig record
    {
      writeln("Test 7: GPGConfig record initialization");
      var allPass = true;

      const defaultGPG = new GPGConfig();
      if defaultGPG.keyId != "" {
        writeln("  FAIL: Default keyId should be empty");
        allPass = false;
      }

      const configuredGPG = new GPGConfig(
        keyId = "ABC123",
        signCommits = true,
        signTags = true,
        autoSignoff = false
      );

      if configuredGPG.keyId != "ABC123" {
        writeln("  FAIL: keyId should be 'ABC123'");
        allPass = false;
      }
      if !configuredGPG.signCommits {
        writeln("  FAIL: signCommits should be true");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 8: GitIdentity with GPG config
    {
      writeln("Test 8: GitIdentity with GPG configuration");
      var allPass = true;

      var identity = new GitIdentity(
        name = "gpg-test",
        provider = Provider.GitLab,
        host = "gitlab-gpg",
        hostname = "gitlab.com",
        user = "gpguser",
        email = "gpg@example.com"
      );

      identity.gpg = new GPGConfig(keyId = "DEADBEEF", signCommits = true, signTags = true, autoSignoff = true);

      if identity.gpg.keyId != "DEADBEEF" {
        writeln("  FAIL: GPG keyId not set correctly");
        allPass = false;
      }

      if !identity.gpg.signCommits {
        writeln("  FAIL: GPG signCommits should be true");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Summary
    printSummary("Identity Tests", passed, failed);

    if failed > 0 then exit(1);
  }
}
