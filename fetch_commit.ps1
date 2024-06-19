param (
    [string]$RepoOwner,
    [string]$RepoName,
    [string]$FilePath,
    [string]$TargetDate
)

try {
    # GitHub API endpoint
    $baseUri = "https://api.github.com/repos/$RepoOwner/$RepoName/commits?path=$FilePath"

    Write-Output "Fetching commits from: $baseUri"

    # Fetch commits for the file
    $commits = Invoke-RestMethod -Uri $baseUri -Method Get

    # Convert target date to DateTime object
    $targetDateTime = Get-Date $TargetDate

    # Initialize variables to track closest commit
    $closestCommit = $null
    $minDiff = [System.Double]::MaxValue

    foreach ($commit in $commits) {
        $commitDate = [datetime]$commit.commit.author.date

        # Calculate difference in seconds (positive if commit date is older than target date)
        $diff = ($targetDateTime - $commitDate).TotalSeconds

        if ($diff -ge 0 -and $diff -lt $minDiff) {
            $minDiff = $diff
            $closestCommit = $commit
        }
    }

    if ($closestCommit -ne $null) {
        # Output the closest older commit SHA
        Write-Output "$($closestCommit.sha),$($closestCommit.commit.author.date)"

    } else {
        Write-Output "No commits found older than '$TargetDate' for file '$FilePath' in repository '$RepoOwner/$RepoName'."
    }
}
catch {
    Write-Host "Error fetching commits: $_"
    exit 1
}
