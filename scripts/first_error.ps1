# Usage: Run from project root
# Prints the first matching error line from build_full.log
$pattern = '^\s*e: |^\s*error: |A problem occurred|FAILURE: Build failed|\[\s+\d+ ms\] Exception|Unhandled exception|cannot find symbol|NoSuchMethodError|Compilation failed'
$match = Select-String -Path 'build_full.log' -Pattern $pattern -CaseSensitive:$false | Select-Object -First 1
if ($null -ne $match) {
  Write-Output ("{0}: {1}" -f $match.LineNumber, $match.Line)
} else {
  Write-Output "No error-like lines found in build_full.log"
}