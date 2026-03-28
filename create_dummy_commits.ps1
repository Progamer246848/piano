param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, 1000000)]
    [int]$Count,

    [Parameter(Position = 1)]
    [string]$CommitDate = "",

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

    $baseCommitDate = $null
    if (-not [string]::IsNullOrWhiteSpace($CommitDate)) {
        try {
            $baseCommitDate = [datetime]::ParseExact(
                $CommitDate,
                "yyyy-MM-dd",
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        }
        catch {
            throw "CommitDate must be in yyyy-MM-dd format, for example 2026-03-27."
        }
    }

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
        $commitMoment = $null
        if ($null -ne $baseCommitDate) {
            $commitMoment = [datetimeoffset]::new(
                $baseCommitDate.Year,
                $baseCommitDate.Month,
                $baseCommitDate.Day,
                12,
                0,
                0,
                [datetimeoffset]::Now.Offset
            ).AddMinutes($i - 1)
            $timestamp = $commitMoment.ToString("yyyy-MM-ddTHH:mm:ssK")
        }
        else {
            $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffffffK"
        }

        $line = "{0}`tcommit {1} of {2}`t{3}" -f $timestamp, $i, $Count, [Guid]::NewGuid().ToString()
        Add-Content -LiteralPath $FilePath -Value $line

        Write-Host ""
        Write-Host "Creating local dummy commit $i of $Count"
        Run-Git @("add", "--", $FilePath)

        if ($null -ne $commitMoment) {
            $env:GIT_AUTHOR_DATE = $timestamp
            $env:GIT_COMMITTER_DATE = $timestamp
        }

        try {
            Run-Git @("commit", "-m", "$MessagePrefix $i/$Count")
        }
        finally {
            if ($null -ne $commitMoment) {
                Remove-Item Env:GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
                Remove-Item Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
    Write-Host "Created $Count local dummy commit(s). No push was performed."
}
catch {
    Write-Error $_
    exit 1
}
