/*
 * TestUtils.chpl - Common test utilities
 *
 * Provides helper functions for unit tests.
 */
module TestUtils {
  // Repeat a string n times (Chapel stdlib doesn't have this)
  proc repeatStr(s: string, n: int): string {
    var result = "";
    for i in 0..<n {
      result += s;
    }
    return result;
  }

  // Print a separator line
  proc printSeparator(width: int = 50) {
    writeln(repeatStr("=", width));
  }

  // Print test summary
  proc printSummary(testName: string, passed: int, failed: int) {
    writeln();
    printSeparator();
    writeln(testName, ": ", passed, " passed, ", failed, " failed");
    printSeparator();
  }
}
