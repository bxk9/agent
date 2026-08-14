$files = Get-ChildItem -Path $PSScriptRoot -File | Where-Object { $_.Name -match '^(.+)\.(\d+)\.md$' }
$count = 0
foreach ($file in $files) {
    if ($file.Name -match '^(.+)\.(\d+)\.md$') {
        $prefix = $Matches[1]
        $num = $Matches[2]
        $newName = "$prefix.7z.$num"
        Rename-Item -LiteralPath $file.FullName -NewName $newName
        Write-Host "$($file.Name) -> $newName"
        $count++
    }
}
Write-Host "Done. Renamed $count files."
