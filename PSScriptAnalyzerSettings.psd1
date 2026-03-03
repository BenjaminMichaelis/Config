@{
    ExcludeRules = @(
        # Cosmetic only - trailing whitespace does not affect script behaviour
        'PSAvoidTrailingWhitespace',

        # Write-Host is appropriate in interactive console/profile scripts
        'PSAvoidUsingWriteHost',

        # Private helper functions in personal scripts are not exported module
        # cmdlets, so approved-verb and singular-noun requirements do not apply
        'PSUseApprovedVerbs',
        'PSUseSingularNouns',

        # Invoke-Expression is used for standard install patterns such as the
        # Chocolatey bootstrap and oh-my-posh shell initialisation
        'PSAvoidUsingInvokeExpression',

        # UTF-8 without BOM is the preferred encoding for cross-platform scripts
        'PSUseBOMForUnicodeEncodedFile',

        # These are standalone scripts and git hooks, not reusable pipeline cmdlets
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseProcessBlockForPipelineCommand',

        # Script-level variables ($UserBucket etc.) are intentionally shared
        # across dot-sourced scripts and are not accidental globals
        'PSAvoidGlobalVars',

        # False positive: $Filter is used inside a pipeline Where-Object block
        # that PSScriptAnalyzer cannot statically trace
        'PSReviewUnusedParameter',

        # Information level only; [OutputType] declarations are documentation
        'PSUseOutputTypeCorrectly',

        # Profile.ps1 uses intentionally empty catch blocks for TLS setup and
        # mutex cleanup that must not interrupt an interactive shell session
        'PSAvoidUsingEmptyCatchBlock',

        # Third-party CLI wrappers (choco, scoop) use positional parameters
        # by convention; enforcing named params here would be incorrect
        'PSAvoidUsingPositionalParameters'
    )
}
