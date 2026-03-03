#Requires -Version 5.1
# commit-msg git hook (PowerShell version)
# Strips AI-generated trailer lines from commit messages while preserving
# human Co-authored-by, Signed-off-by, and all other content.
#
# Handles (case-insensitive) lines such as:
#   Made-with: Cursor
#   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
#   Co-authored-by: GitHub Copilot <noreply@github.com>
#   Co-authored-by: Amazon Q <q@amazon.com>
#   Generated-by: GitHub Copilot

function Remove-AITrailers {
    <#
    .SYNOPSIS
        Filters AI-generated trailer lines from an array of commit-message lines.
    .PARAMETER Lines
        The lines of the commit message to process.
    .OUTPUTS
        String[] – the filtered lines with trailing blank lines removed.
    #>
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines
    )

    # 1. Trailer keys that always indicate AI-generated content
    $markerPattern = '^\s*(made-with|generated-by|suggested-by)\s*:'

    # 2. Co-authored-by where the name starts with a known AI tool
    #    The trailing (\s|<|$) keeps whole-word matching so "Claude" still
    #    matches "Claude Opus 4.6" but won't silently drop "Claudette Smith".
    $aiNamesPattern = '^\s*co-authored?-by\s*:\s*(github\s+copilot|copilot|claude|amazon\s+q|amazon\s+codewhisperer|codewhisperer|gemini|chatgpt|gpt-?\d+|codeium|tabnine|windsurf|opencode)(\s|<|$)'

    # 3. Co-authored-by whose email domain belongs to a known AI provider
    $aiEmailPattern = '^\s*co-authored?-by\s*:.*<[^>]*@(anthropic\.com|cursor\.sh|codeium\.com|cognition\.ai)[^>]*>'

    $filtered = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        if ($line -imatch $markerPattern)  { continue }
        if ($line -imatch $aiNamesPattern) { continue }
        if ($line -imatch $aiEmailPattern) { continue }
        $filtered.Add($line)
    }

    # Remove trailing blank lines
    while ($filtered.Count -gt 0 -and [string]::IsNullOrWhiteSpace($filtered[$filtered.Count - 1])) {
        $filtered.RemoveAt($filtered.Count - 1)
    }

    return $filtered.ToArray()
}

# Run as a git hook when executed directly (not dot-sourced by tests)
if ($MyInvocation.InvocationName -ne '.') {
    $commitMsgFile = if ($args.Count -gt 0) { $args[0] } else { $null }
    if ($commitMsgFile -and (Test-Path $commitMsgFile)) {
        $lines = Get-Content -Path $commitMsgFile -Encoding UTF8
        if ($null -eq $lines) { $lines = @() }
        $filtered = Remove-AITrailers -Lines $lines
        # Write back with LF line endings and a final newline
        $content = if ($filtered.Count -gt 0) { ($filtered -join "`n") + "`n" } else { '' }
        [System.IO.File]::WriteAllText(
            $commitMsgFile,
            $content,
            [System.Text.Encoding]::UTF8
        )
    }
}
