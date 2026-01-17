/*
 * TokenHealthTests.chpl - Unit tests for TokenHealth module
 *
 * Tests token expiry calculation, metadata persistence, and warning thresholds.
 */
prototype module TokenHealthTests {
  use remote_juggler.Core;
  use remote_juggler.TokenHealth;
  use TestUtils;
  use Time;
  use List;

  config const verbose = false;

  proc main() {
    writeln("=== RemoteJuggler TokenHealth Module Tests ===\n");

    var passed = 0;
    var failed = 0;

    // Test 1: TokenMetadata record initialization
    {
      writeln("Test 1: TokenMetadata record defaults");

      const meta = new TokenMetadata();

      var allPass = true;
      if meta.identityName != "" { allPass = false; writeln("  FAIL: identityName should be empty"); }
      if meta.provider != "" { allPass = false; writeln("  FAIL: provider should be empty"); }
      if meta.createdAt != 0.0 { allPass = false; writeln("  FAIL: createdAt should be 0.0"); }
      if meta.lastVerified != 0.0 { allPass = false; writeln("  FAIL: lastVerified should be 0.0"); }
      if meta.expiresAt != 0.0 { allPass = false; writeln("  FAIL: expiresAt should be 0.0"); }
      if meta.tokenType != "pat" { allPass = false; writeln("  FAIL: tokenType should be 'pat'"); }
      if meta.isValid != true { allPass = false; writeln("  FAIL: isValid should be true"); }
      if meta.warningIssued != 0.0 { allPass = false; writeln("  FAIL: warningIssued should be 0.0"); }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 2: TokenHealthResult record initialization
    {
      writeln("Test 2: TokenHealthResult record defaults");

      const result = new TokenHealthResult();

      var allPass = true;
      if result.healthy != false { allPass = false; writeln("  FAIL: healthy should be false"); }
      if result.hasToken != false { allPass = false; writeln("  FAIL: hasToken should be false"); }
      if result.isExpired != false { allPass = false; writeln("  FAIL: isExpired should be false"); }
      if result.daysUntilExpiry != 0 { allPass = false; writeln("  FAIL: daysUntilExpiry should be 0"); }
      if result.needsRenewal != false { allPass = false; writeln("  FAIL: needsRenewal should be false"); }
      if result.message != "" { allPass = false; writeln("  FAIL: message should be empty"); }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 3: Days until expiry calculation - future date
    {
      writeln("Test 3: daysUntilExpiry with future date");

      const now = timeSinceEpoch().totalSeconds();
      const thirtyDaysFromNow = now + (30 * 86400.0);
      const days = daysUntilExpiry(thirtyDaysFromNow);

      // Allow 1 day tolerance for timing
      if days >= 29 && days <= 31 {
        writeln("  PASS (", days, " days)");
        passed += 1;
      } else {
        writeln("  FAIL: expected ~30 days, got ", days);
        failed += 1;
      }
    }

    // Test 4: Days until expiry calculation - past date
    {
      writeln("Test 4: daysUntilExpiry with past date");

      const now = timeSinceEpoch().totalSeconds();
      const tenDaysAgo = now - (10 * 86400.0);
      const days = daysUntilExpiry(tenDaysAgo);

      // Allow 1 day tolerance for timing
      if days >= -11 && days <= -9 {
        writeln("  PASS (", days, " days)");
        passed += 1;
      } else {
        writeln("  FAIL: expected ~-10 days, got ", days);
        failed += 1;
      }
    }

    // Test 5: Days until expiry calculation - unknown (0)
    {
      writeln("Test 5: daysUntilExpiry with unknown expiry (0.0)");

      const days = daysUntilExpiry(0.0);

      if days == 999999 {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: expected 999999, got ", days);
        failed += 1;
      }
    }

    // Test 6: needsRenewal - within 30 days
    {
      writeln("Test 6: needsRenewal returns true when < 30 days");

      const now = timeSinceEpoch().totalSeconds();
      const fifteenDaysFromNow = now + (15 * 86400.0);

      if needsRenewal(fifteenDaysFromNow) {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: should return true for 15 days");
        failed += 1;
      }
    }

    // Test 7: needsRenewal - more than 30 days
    {
      writeln("Test 7: needsRenewal returns false when > 30 days");

      const now = timeSinceEpoch().totalSeconds();
      const sixtyDaysFromNow = now + (60 * 86400.0);

      if !needsRenewal(sixtyDaysFromNow) {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: should return false for 60 days");
        failed += 1;
      }
    }

    // Test 8: needsRenewal - already expired
    {
      writeln("Test 8: needsRenewal returns false when already expired");

      const now = timeSinceEpoch().totalSeconds();
      const fiveDaysAgo = now - (5 * 86400.0);

      if !needsRenewal(fiveDaysAgo) {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: should return false for expired token");
        failed += 1;
      }
    }

    // Test 9: isExpired - past date
    {
      writeln("Test 9: isExpired returns true for past date");

      const now = timeSinceEpoch().totalSeconds();
      const yesterday = now - 86400.0;

      if isExpired(yesterday) {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: should return true for past date");
        failed += 1;
      }
    }

    // Test 10: isExpired - future date
    {
      writeln("Test 10: isExpired returns false for future date");

      const now = timeSinceEpoch().totalSeconds();
      const tomorrow = now + 86400.0;

      if !isExpired(tomorrow) {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: should return false for future date");
        failed += 1;
      }
    }

    // Test 11: isExpired - unknown expiry
    {
      writeln("Test 11: isExpired returns false for unknown expiry (0.0)");

      if !isExpired(0.0) {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: should return false for unknown expiry");
        failed += 1;
      }
    }

    // Test 12: getMetadataKey format
    {
      writeln("Test 12: getMetadataKey format");

      const identity = new GitIdentity(
        name = "personal",
        provider = Provider.GitLab,
        host = "gitlab-personal",
        hostname = "gitlab.com",
        user = "testuser",
        email = "test@example.com"
      );

      const key = getMetadataKey(identity);

      // The key format is "provider:name"
      if key.find("personal") != -1 {
        writeln("  PASS (key: ", key, ")");
        passed += 1;
      } else {
        writeln("  FAIL: key should contain identity name, got: ", key);
        failed += 1;
      }
    }

    // Test 13: shouldWarn rate limiting
    {
      writeln("Test 13: shouldWarn respects 24-hour rate limit");

      const now = timeSinceEpoch().totalSeconds();

      var recentMeta = new TokenMetadata();
      recentMeta.warningIssued = now - 3600.0;  // 1 hour ago

      var oldMeta = new TokenMetadata();
      oldMeta.warningIssued = now - 172800.0;  // 2 days ago

      var allPass = true;
      if shouldWarn(recentMeta) {
        writeln("  FAIL: should not warn for recent warning");
        allPass = false;
      }
      if !shouldWarn(oldMeta) {
        writeln("  FAIL: should warn for old warning");
        allPass = false;
      }

      if allPass {
        writeln("  PASS");
        passed += 1;
      } else {
        failed += 1;
      }
    }

    // Test 14: getMetadataPath returns non-empty
    {
      writeln("Test 14: getMetadataPath returns valid path");

      const path = getMetadataPath();

      if path.size > 0 && path.find("tokens.json") != -1 {
        writeln("  PASS (", path, ")");
        passed += 1;
      } else {
        writeln("  FAIL: path should end with tokens.json, got: ", path);
        failed += 1;
      }
    }

    // Test 15: formatHealthResult output
    {
      writeln("Test 15: formatHealthResult produces output");

      var result = new TokenHealthResult();
      result.healthy = true;
      result.hasToken = true;
      result.message = "Token is valid";

      const formatted = formatHealthResult(result);

      if formatted.size > 0 && formatted.find("Status") != -1 {
        writeln("  PASS");
        passed += 1;
      } else {
        writeln("  FAIL: formatted output should contain 'Status'");
        failed += 1;
      }
    }

    // Summary
    printSummary("TokenHealth Tests", passed, failed);

    if failed > 0 then exit(1);
  }
}
