$files = Get-ChildItem -Path $PSScriptRoot -File | Where-Object { $_.Name -match '^(.+)\.7z\.(\d+)$' }
$count = 0
foreach ($file in $files) {
    if ($file.Name -match '^(.+)\.7z\.(\d+)$') {
        $prefix = $Matches[1]
        $num = $Matches[2]
        $newName = "$prefix.$num.md"
        Rename-Item -LiteralPath $file.FullName -NewName $newName
        Write-Host "$($file.Name) -> $newName"
        $count++
    }
}
Write-Host "Done. Renamed $count files."
