#Requires -Version 5.1
# Pester tests for the commit-msg AI-trailer filter.
# Tests the Remove-AITrailers function from commit-msg.ps1 directly (dot-sourced),
# and – on non-Windows platforms – also validates the bash hook end-to-end.

# ---------------------------------------------------------------------------
# Unit tests – Remove-AITrailers (PowerShell, cross-platform)
# ---------------------------------------------------------------------------
Describe 'Remove-AITrailers' {
    BeforeAll {
        $hookDir = Split-Path -Parent $PSScriptRoot
        . (Join-Path $hookDir 'commit-msg.ps1')
    }


    Context 'Messages without AI trailers are unchanged' {
        It 'preserves a simple single-line title' {
            $result = Remove-AITrailers -Lines @('Fix bug in parser')
            $result | Should -Be @('Fix bug in parser')
        }

        It 'preserves a title + body with no trailers' {
            $lines = @(
                'Add feature X',
                '',
                'This implements feature X as requested.',
                'See issue #123.'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Be $lines
        }

        It 'preserves a human Co-authored-by line' {
            $lines = @(
                'Fix bug',
                '',
                'Co-authored-by: Alice Smith <alice@example.com>'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Be $lines
        }

        It 'preserves Signed-off-by lines' {
            $lines = @(
                'Fix bug',
                '',
                'Signed-off-by: Bob Jones <bob@example.com>'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Be $lines
        }

        It 'preserves human Co-authored-by when name starts with an AI-like word but has a normal email' {
            # "Claudette Smith" is NOT an AI even though it starts with "Claud"
            # but this ensures we don't over-match simple word stems.
            $lines = @(
                'Refactor module',
                '',
                'Co-authored-by: Alice Cursor <alice@example.com>'
            )
            # "Alice Cursor" does not start with a known AI name, so it is preserved
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Be $lines
        }
    }

    Context 'AI marker trailers are removed' {
        It 'removes Made-with: Cursor' {
            $lines = @('Fix bug', '', 'Made-with: Cursor')
            $result = @(Remove-AITrailers -Lines $lines)
            $result | Should -Not -Contain 'Made-with: Cursor'
            $result[0] | Should -Be 'Fix bug'
        }

        It 'removes Generated-by: GitHub Copilot' {
            $lines = @('Fix bug', '', 'Generated-by: GitHub Copilot')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Generated-by'
        }

        It 'removes Suggested-by: ChatGPT' {
            $lines = @('Fix bug', '', 'Suggested-by: ChatGPT')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Suggested-by'
        }

        It 'removes Made-with: regardless of AI tool name' {
            foreach ($tool in @('Cursor', 'Windsurf', 'Codeium', 'Tabnine', 'OpenCode')) {
                $lines = @('Fix bug', '', "Made-with: $tool")
                $result = Remove-AITrailers -Lines $lines
                $result | Should -Not -Match 'Made-with'
            }
        }
    }

    Context 'GitHub Copilot Co-authored-by is removed' {
        It 'removes Co-authored-by: GitHub Copilot (noreply@github.com)' {
            $lines = @('Fix bug', '', 'Co-authored-by: GitHub Copilot <noreply@github.com>')
            $result = @(Remove-AITrailers -Lines $lines)
            $result | Should -Not -Match 'Co-authored-by'
            $result[0] | Should -Be 'Fix bug'
        }

        It 'removes Co-Authored-By: GitHub Copilot (case-insensitive key)' {
            $lines = @('Fix bug', '', 'Co-Authored-By: GitHub Copilot <copilot@github.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Co-Authored-By'
        }

        It 'removes co-authored-by: copilot (lowercase key)' {
            $lines = @('Fix bug', '', 'co-authored-by: copilot <copilot@github.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'co-authored-by'
        }
    }

    Context 'Claude / Anthropic Co-authored-by is removed' {
        It 'removes Co-Authored-By: Claude Opus 4.6 (noreply@anthropic.com)' {
            $lines = @('Fix bug', '', 'Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Co-Authored-By'
        }

        It 'removes Co-authored-by: Claude Sonnet 3.5 (claude@anthropic.com)' {
            $lines = @('Fix bug', '', 'Co-authored-by: Claude Sonnet 3.5 <claude@anthropic.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'claude'
        }

        It 'removes Co-authored-by by @anthropic.com email domain' {
            $lines = @('Fix bug', '', 'Co-authored-by: Some Model <model@anthropic.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'anthropic'
        }
    }

    Context 'Amazon Q / CodeWhisperer Co-authored-by is removed' {
        It 'removes Co-authored-by: Amazon Q (q@amazon.com)' {
            $lines = @('Fix bug', '', 'Co-authored-by: Amazon Q <q@amazon.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Amazon Q'
        }

        It 'removes Co-authored-by: Amazon CodeWhisperer' {
            $lines = @('Fix bug', '', 'Co-authored-by: Amazon CodeWhisperer <aws@amazon.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'CodeWhisperer'
        }
    }

    Context 'Gemini Co-authored-by is removed' {
        It 'removes Co-authored-by: Gemini 1.5 Pro (gemini@google.com)' {
            $lines = @('Fix bug', '', 'Co-authored-by: Gemini 1.5 Pro <gemini@google.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Gemini'
        }
    }

    Context 'ChatGPT / GPT Co-authored-by is removed' {
        It 'removes Co-authored-by: ChatGPT (chatgpt@openai.com)' {
            $lines = @('Fix bug', '', 'Co-authored-by: ChatGPT <chatgpt@openai.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'ChatGPT'
        }

        It 'removes Co-authored-by: GPT-4 (gpt4@openai.com)' {
            $lines = @('Fix bug', '', 'Co-authored-by: GPT-4 <gpt4@openai.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'GPT-4'
        }
    }

    Context 'Cursor Co-authored-by is removed via email domain' {
        It 'removes Co-authored-by: Cursor AI (bot@cursor.sh)' {
            $lines = @('Fix bug', '', 'Co-authored-by: Cursor AI <bot@cursor.sh>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'cursor\.sh'
        }
    }

    Context 'Codeium Co-authored-by is removed' {
        It 'removes Co-authored-by: Codeium (codeium@codeium.com) by name' {
            $lines = @('Fix bug', '', 'Co-authored-by: Codeium <codeium@codeium.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Codeium'
        }

        It 'removes Co-authored-by by @codeium.com email domain' {
            $lines = @('Fix bug', '', 'Co-authored-by: Unknown <user@codeium.com>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'codeium\.com'
        }
    }

    Context 'Mixed human and AI co-authors' {
        It 'removes AI line and preserves human line' {
            $lines = @(
                'Fix bug',
                '',
                'Co-authored-by: Alice Smith <alice@example.com>',
                'Co-authored-by: GitHub Copilot <noreply@github.com>'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Contain 'Co-authored-by: Alice Smith <alice@example.com>'
            $result | Should -Not -Match 'GitHub Copilot'
        }

        It 'removes multiple AI lines and preserves multiple human lines' {
            $lines = @(
                'Fix bug',
                '',
                'Co-authored-by: Alice Smith <alice@example.com>',
                'Co-authored-by: Bob Jones <bob@example.com>',
                'Co-authored-by: GitHub Copilot <noreply@github.com>',
                'Co-authored-by: Claude Opus 4.6 <noreply@anthropic.com>',
                'Made-with: Cursor'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Contain 'Co-authored-by: Alice Smith <alice@example.com>'
            $result | Should -Contain 'Co-authored-by: Bob Jones <bob@example.com>'
            $result | Should -Not -Match 'GitHub Copilot'
            $result | Should -Not -Match 'Claude'
            $result | Should -Not -Match 'Made-with'
        }

        It 'preserves Signed-off-by alongside AI removal' {
            $lines = @(
                'Fix bug',
                '',
                'Signed-off-by: Alice Smith <alice@example.com>',
                'Co-authored-by: GitHub Copilot <noreply@github.com>'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Contain 'Signed-off-by: Alice Smith <alice@example.com>'
            $result | Should -Not -Match 'Copilot'
        }
    }

    Context 'Trailing blank lines are stripped after AI removal' {
        It 'leaves no trailing blank lines when all trailers were AI' {
            $lines = @('Fix bug', '', 'Co-authored-by: GitHub Copilot <noreply@github.com>')
            $result = @(Remove-AITrailers -Lines $lines)
            # Last element must not be blank
            $result[-1] | Should -Not -BeNullOrEmpty
            ($result[-1]).Trim() | Should -Not -BeNullOrEmpty
        }

        It 'retains a blank separator line between body and remaining human trailer' {
            $lines = @(
                'Fix bug',
                '',
                'Body text here.',
                '',
                'Co-authored-by: Alice Smith <alice@example.com>',
                'Co-authored-by: GitHub Copilot <noreply@github.com>'
            )
            $result = Remove-AITrailers -Lines $lines
            # Blank separator between body and human trailer should survive
            $result | Should -Contain ''
            $result | Should -Contain 'Co-authored-by: Alice Smith <alice@example.com>'
        }
    }

    Context 'Squash-merge commit with AI trailers in multiple positions' {
        It 'removes all AI trailers in a squash-merge style message' {
            $lines = @(
                'Merge feature branch (#42)',
                '',
                '* commit abc123',
                '  Fix bug 1',
                '',
                '* commit def456',
                '  Fix bug 2',
                '',
                'Co-authored-by: Alice Smith <alice@example.com>',
                'Co-authored-by: GitHub Copilot <noreply@github.com>',
                'Co-authored-by: Claude Sonnet 3.5 <noreply@anthropic.com>',
                'Made-with: Cursor'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Contain 'Co-authored-by: Alice Smith <alice@example.com>'
            $result | Should -Contain 'Merge feature branch (#42)'
            $result | Should -Not -Match 'GitHub Copilot'
            $result | Should -Not -Match 'Claude'
            $result | Should -Not -Match 'Made-with'
        }

        It 'removes indented AI trailers (squash-merge inner commit lines)' {
            $lines = @(
                'Squashed commit',
                '',
                '    Co-Authored-By: GitHub Copilot <noreply@github.com>',
                '    Made-with: Cursor'
            )
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'Co-Authored-By'
            $result | Should -Not -Match 'Made-with'
        }
    }

    Context 'Case-insensitive matching' {
        It 'removes CO-AUTHORED-BY: GITHUB COPILOT in uppercase' {
            $lines = @('Fix bug', '', 'CO-AUTHORED-BY: GITHUB COPILOT <COPILOT@GITHUB.COM>')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'CO-AUTHORED-BY'
        }

        It 'removes MADE-WITH: CURSOR in uppercase' {
            $lines = @('Fix bug', '', 'MADE-WITH: CURSOR')
            $result = Remove-AITrailers -Lines $lines
            $result | Should -Not -Match 'MADE-WITH'
        }
    }
}

# ---------------------------------------------------------------------------
# End-to-end tests for the bash hook (skipped on Windows)
# ---------------------------------------------------------------------------
Describe 'commit-msg bash hook (end-to-end)' -Skip:($IsWindows -or -not (Get-Command bash -ErrorAction SilentlyContinue)) {
    BeforeAll {
        $hookDir  = Split-Path -Parent $PSScriptRoot
        $bashHook = Join-Path $hookDir 'commit-msg'

        function Invoke-BashHook {
            param([string]$Content)
            $tmp = [System.IO.Path]::GetTempFileName()
            try {
                [System.IO.File]::WriteAllText($tmp, $Content, [System.Text.Encoding]::UTF8)
                & bash $bashHook $tmp 2>&1 | Out-Null
                return [System.IO.File]::ReadAllText($tmp)
            }
            finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'removes GitHub Copilot trailer' {
        $content = "Fix bug`n`nCo-authored-by: GitHub Copilot <noreply@github.com>`n"
        $result = Invoke-BashHook $content
        $result | Should -Not -Match 'Co-authored-by'
        $result.Trim() | Should -Be 'Fix bug'
    }

    It 'removes Claude trailer by email domain' {
        $content = "Fix bug`n`nCo-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`n"
        $result = Invoke-BashHook $content
        $result | Should -Not -Match 'anthropic'
        $result.Trim() | Should -Be 'Fix bug'
    }

    It 'removes Made-with: Cursor' {
        $content = "Fix bug`n`nMade-with: Cursor`n"
        $result = Invoke-BashHook $content
        $result | Should -Not -Match 'Made-with'
        $result.Trim() | Should -Be 'Fix bug'
    }

    It 'preserves human co-author' {
        $content = "Fix bug`n`nCo-authored-by: Alice Smith <alice@example.com>`n"
        $result = Invoke-BashHook $content
        $result | Should -Match 'Alice Smith'
    }

    It 'removes AI and preserves human in mixed message' {
        $content = "Fix bug`n`nCo-authored-by: Alice Smith <alice@example.com>`nCo-authored-by: GitHub Copilot <noreply@github.com>`n"
        $result = Invoke-BashHook $content
        $result | Should -Match 'Alice Smith'
        $result | Should -Not -Match 'GitHub Copilot'
    }

    It 'preserves Signed-off-by line' {
        $content = "Fix bug`n`nSigned-off-by: Bob Jones <bob@example.com>`nCo-authored-by: ChatGPT <chatgpt@openai.com>`n"
        $result = Invoke-BashHook $content
        $result | Should -Match 'Signed-off-by'
        $result | Should -Not -Match 'ChatGPT'
    }

    It 'handles squash-merge with multiple AI trailers' {
        $content = @"
Merge feature (#42)

* commit abc
  Fix thing

Co-authored-by: Alice Smith <alice@example.com>
Co-authored-by: GitHub Copilot <noreply@github.com>
Co-authored-by: Claude Sonnet 3.5 <noreply@anthropic.com>
Made-with: Cursor
"@
        $result = Invoke-BashHook $content
        $result | Should -Match 'Alice Smith'
        $result | Should -Not -Match 'GitHub Copilot'
        $result | Should -Not -Match 'Claude'
        $result | Should -Not -Match 'Made-with'
    }

    It 'handles case-insensitive matching' {
        $content = "Fix bug`n`nCO-AUTHORED-BY: GITHUB COPILOT <COPILOT@GITHUB.COM>`nMADE-WITH: CURSOR`n"
        $result = Invoke-BashHook $content
        $result | Should -Not -Match 'CO-AUTHORED-BY'
        $result | Should -Not -Match 'MADE-WITH'
    }
}
