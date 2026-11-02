$composeArgs = @($args)
$dockerDesktopPath = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'

Push-Location (Join-Path $PSScriptRoot '..')
try {
    & docker info --format '{{.ServerVersion}}' *> $null
    if ($LASTEXITCODE -ne 0) {
        if (-not (Test-Path $dockerDesktopPath)) {
            Write-Error 'Docker Desktop is not installed. Install and start Docker Desktop, then run this task again.'
            exit 1
        }

        if (-not (Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue)) {
            Write-Output 'Starting Docker Desktop...'
            Start-Process -FilePath $dockerDesktopPath
        }

        Write-Output 'Waiting for the Docker engine...'
        $dockerReady = $false
        for ($attempt = 0; $attempt -lt 36; $attempt++) {
            Start-Sleep -Seconds 5
            & docker info --format '{{.ServerVersion}}' *> $null
            if ($LASTEXITCODE -eq 0) {
                $dockerReady = $true
                break
            }
        }

        if (-not $dockerReady) {
            Write-Error 'Docker Desktop did not become ready within 3 minutes. Check Docker Desktop, then run this task again.'
            exit 1
        }
    }

    & docker compose @composeArgs
    $composeExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($composeExitCode -ne 0) {
    exit $composeExitCode
}

$services = [System.Collections.Generic.List[string]]::new()
$skipNext = $false
$optionsWithValues = @('-f', '--file', '-p', '--project-name', '--profile', '--env-file', '--project-directory')

foreach ($argument in $composeArgs) {
    if ($skipNext) {
        $skipNext = $false
        continue
    }

    if ($optionsWithValues -contains $argument) {
        $skipNext = $true
        continue
    }

    if ($argument -eq 'up' -or $argument.StartsWith('-')) {
        continue
    }

    $services.Add($argument)
}

if ($services.Count -eq 0) {
    $services.AddRange([string[]]@('admin', 'client', 'api'))
}

foreach ($service in $services) {
    $url = switch ($service) {
        'admin' { 'http://localhost:8002' }
        'client' { 'http://localhost:8081' }
        'api' { 'http://localhost:8001/docs' }
        default { $null }
    }

    if ($url) {
        $serviceReady = $false
        for ($attempt = 0; $attempt -lt 24; $attempt++) {
            try {
                $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 3 -UseBasicParsing
                if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                    $serviceReady = $true
                    break
                }
                Start-Sleep -Seconds 5
            }
            catch {
                Start-Sleep -Seconds 5
            }
        }

        if (-not $serviceReady) {
            Write-Error "${service} did not respond at $url within 2 minutes."
            exit 1
        }

        Write-Output "Opening ${service}: $url"
        Start-Process $url
    }
}
