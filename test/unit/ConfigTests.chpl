/*
 * ConfigTests.chpl - Unit tests for Config module
 *
 * Tests SSH config parsing, git config parsing, and URL rewriting.
 */
prototype module ConfigTests {
  use remote_juggler.Config;
  use remote_juggler.Core;
  use TestUtils;

  config const verbose = false;

  proc main() {
    writeln("=== RemoteJuggler Config Module Tests ===\n");

    var passed = 0;
    var failed = 0;

    // Test 1: Extract host from SSH URL
    {
      writeln("Test 1: Extract host from SSH URL");
      var allPass = true;

      const sshUrl = "git@gitlab-work:company/project.git";
      const host = extractHostFromRemote(sshUrl);

      if host != "gitlab-work" {
        writeln("  FAIL: Expected 'gitlab-work', got '", host, "'");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 2: Extract host from HTTPS URL
    {
      writeln("Test 2: Extract host from HTTPS URL");
      var allPass = true;

      const httpsUrl = "https://gitlab.com/user/repo.git";
      const host = extractHostFromRemote(httpsUrl);

      if host != "gitlab.com" {
        writeln("  FAIL: Expected 'gitlab.com', got '", host, "'");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 3: Extract path from remote URL
    {
      writeln("Test 3: Extract path from remote URL");
      var allPass = true;

      const sshUrl = "git@gitlab-work:company/project.git";
      const path = extractPathFromRemote(sshUrl);

      if path != "company/project.git" {
        writeln("  FAIL: Expected 'company/project.git', got '", path, "'");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 4: SSH directive parsing
    {
      writeln("Test 4: SSH config directive parsing");
      var allPass = true;

      // Host line
      const hostLine = "Host gitlab-work";
      const (hostKey, hostValue) = parseSSHDirective(hostLine);

      if hostKey != "Host" || hostValue != "gitlab-work" {
        writeln("  FAIL: Host line parsing failed: key='", hostKey, "' value='", hostValue, "'");
        allPass = false;
      }

      // HostName with indentation
      const hostnameLine = "    HostName gitlab.com";
      const (hnKey, hnValue) = parseSSHDirective(hostnameLine);

      if hnKey != "HostName" || hnValue != "gitlab.com" {
        writeln("  FAIL: HostName parsing failed: key='", hnKey, "' value='", hnValue, "'");
        allPass = false;
      }

      // IdentityFile
      const identityLine = "  IdentityFile ~/.ssh/id_ed25519_work";
      const (idKey, idValue) = parseSSHDirective(identityLine);

      if idKey != "IdentityFile" || idValue != "~/.ssh/id_ed25519_work" {
        writeln("  FAIL: IdentityFile parsing failed: key='", idKey, "' value='", idValue, "'");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 5: Git config section parsing
    {
      writeln("Test 5: Git config section header parsing");
      var allPass = true;

      const userSection = "[user]";
      const (userType, userData) = parseGitSection(userSection);

      if userType == "" {
        writeln("  FAIL: Should recognize [user] as section");
        allPass = false;
      }

      const urlSection = "[url \"git@gitlab-work:\"]";
      const (urlType, urlData) = parseGitSection(urlSection);

      if urlType == "" {
        writeln("  FAIL: Should recognize URL section");
        allPass = false;
      }

      const notSection = "  email = user@example.com";
      const (notType, notData) = parseGitSection(notSection);

      if notType != "" {
        writeln("  FAIL: Should NOT recognize key=value as section");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 6: Git key-value parsing
    {
      writeln("Test 6: Git config key-value parsing");
      var allPass = true;

      const emailLine = "  email = user@example.com";
      const (key, value) = parseGitKeyValue(emailLine);

      if key != "email" || value != "user@example.com" {
        writeln("  FAIL: key-value parsing failed: key='", key, "' value='", value, "'");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 7: SSHHost provider inference
    {
      writeln("Test 7: SSHHost provider inference");
      var allPass = true;

      var gitlabHost = new SSHHost("gitlab-work", "gitlab.com", "~/.ssh/id_ed25519");
      if gitlabHost.inferProvider() != Provider.GitLab {
        writeln("  FAIL: gitlab.com should infer GitLab provider");
        allPass = false;
      }

      var githubHost = new SSHHost("github", "github.com", "~/.ssh/id_ed25519");
      if githubHost.inferProvider() != Provider.GitHub {
        writeln("  FAIL: github.com should infer GitHub provider");
        allPass = false;
      }

      var bitbucketHost = new SSHHost("bb", "bitbucket.org", "~/.ssh/id_ed25519");
      if bitbucketHost.inferProvider() != Provider.Bitbucket {
        writeln("  FAIL: bitbucket.org should infer Bitbucket provider");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 8: URL rewrite application
    {
      writeln("Test 8: URL rewrite application");
      var allPass = true;

      var rewrite = new URLRewrite("https://gitlab.com/", "git@gitlab-work:");

      const testUrl = "https://gitlab.com/user/repo.git";
      if !rewrite.appliesTo(testUrl) {
        writeln("  FAIL: Rewrite should apply to '", testUrl, "'");
        allPass = false;
      }

      const rewritten = rewrite.apply(testUrl);
      if rewritten != "git@gitlab-work:user/repo.git" {
        writeln("  FAIL: Expected 'git@gitlab-work:user/repo.git', got '", rewritten, "'");
        allPass = false;
      }

      const otherUrl = "https://github.com/user/repo.git";
      if rewrite.appliesTo(otherUrl) {
        writeln("  FAIL: Rewrite should NOT apply to '", otherUrl, "'");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 9: Empty/edge cases
    {
      writeln("Test 9: Edge cases - empty inputs");
      var allPass = true;

      // Empty URL
      const emptyHost = extractHostFromRemote("");
      if emptyHost != "" {
        writeln("  FAIL: Empty URL should return empty host");
        allPass = false;
      }

      // Empty directive line
      const (emptyKey, emptyValue) = parseSSHDirective("");
      if emptyKey != "" || emptyValue != "" {
        writeln("  FAIL: Empty line should return empty key and value");
        allPass = false;
      }

      // Comment line
      const (commentKey, commentValue) = parseSSHDirective("# This is a comment");
      if commentKey != "" || commentValue != "" {
        writeln("  FAIL: Comment line should return empty");
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
    printSummary("Config Tests", passed, failed);

    if failed > 0 then exit(1);
  }
}
