param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, 1000000)]
    [int]$Count,

    [string]$FilePath = ".dummy_commits.txt",
    [string]$MessagePrefix = "dummy commit"
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

    $staged = @(& git diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect staged changes."
    }

    $staged = $staged | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($staged.Count -gt 0) {
        throw "There are already staged changes. Commit or unstage them before creating dummy commits."
    }

    if (-not (Test-Path -LiteralPath $FilePath)) {
        New-Item -ItemType File -Path $FilePath | Out-Null
    }

    for ($i = 1; $i -le $Count; $i++) {
        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffffffK"
        $line = "{0}`tcommit {1} of {2}`t{3}" -f $timestamp, $i, $Count, [Guid]::NewGuid().ToString()
        Add-Content -LiteralPath $FilePath -Value $line

        Write-Host ""
        Write-Host "Creating local dummy commit $i of $Count"
        Run-Git @("add", "--", $FilePath)
        Run-Git @("commit", "-m", "$MessagePrefix $i/$Count")
    }

    Write-Host ""
    Write-Host "Created $Count local dummy commit(s). No push was performed."
}
catch {
    Write-Error $_
    exit 1
}
