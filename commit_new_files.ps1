param(
    [string]$Remote = "origin",
    [string]$Branch = ""
)

$ErrorActionPreference = "Stop"

function Run-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

try {
    Run-Git @("rev-parse", "--is-inside-work-tree") | Out-Null

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        $Branch = (& git branch --show-current).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Branch)) {
            throw "Could not determine the current branch. Pass -Branch explicitly."
        }
    }

    $files = @(& git ls-files --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list untracked files."
    }

    $files = $files | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($files.Count -eq 0) {
        Write-Host "No new untracked files found."
        exit 0
    }

    foreach ($file in $files) {
        Write-Host ""
        Write-Host "Adding: $file"
        Run-Git @("add", "--", $file)

        $message = "add $file"
        Write-Host "Committing: $message"
        Run-Git @("commit", "-m", $message)

        Write-Host "Pushing to $Remote/$Branch"
        Run-Git @("push", $Remote, $Branch)
    }

    Write-Host ""
    Write-Host "Finished processing $($files.Count) file(s)."
}
catch {
    Write-Error $_
    exit 1
}
