# russiansoundcloud-music: порядок треков в плейлисте мода и проверка на совпадения с другими модами.
# Запускается из build-mod.bat (после сборки) и из shuffle.bat.
param(
    [Parameter(Mandatory = $true)][string]$ModDir,
    [string]$OrderFile = '',
    [switch]$CheckClashes
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 иначе пишет массивы в JSON как {"value":[...],"Count":N}.
if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }
$utf8 = New-Object System.Text.UTF8Encoding $false

function Read-Json([string]$path) {
    return [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
}

# Только буквы и цифры в нижнем регистре: "Cowboy Clicker - Ball!" -> "cowboyclickerball".
function Normalize([string]$text) {
    return ($text.ToLowerInvariant() -replace '[^\p{L}\p{Nd}]', '')
}

# Имя, под которым ReSkate Music Packer кладёт трек в игру (Audio/Music/Assets/ReSkate/<имя>_MG):
# латинские буквы и цифры из "Исполнитель - Название", остальное схлопывается в "_",
# не длиннее 64 символов, а если ничего не осталось - "Song".
function Get-Slug([string]$id) {
    $slug = ''
    foreach ($c in $id.ToCharArray()) {
        if ([int]$c -lt 128 -and [char]::IsLetterOrDigit($c)) { $slug += $c }
        elseif ($slug.Length -gt 0 -and -not $slug.EndsWith('_')) { $slug += '_' }
    }
    $slug = $slug.TrimEnd('_')
    if ($slug.Length -gt 64) { $slug = $slug.Substring(0, 64) }
    if ($slug.Length -eq 0) { $slug = 'Song' }
    return $slug.ToLowerInvariant()
}

# Все треки мода: из плейлистов reskate-music.json и из проекта упаковщика.
function Get-ModSongs([string]$dir) {
    $ids = @()
    $music = Join-Path $dir 'reskate-music.json'
    if (Test-Path -LiteralPath $music) {
        try { foreach ($pl in @((Read-Json $music).playlists)) { $ids += @($pl.songs) } } catch {}
    }
    $project = Join-Path $dir 'reskate-music-project.json'
    if (Test-Path -LiteralPath $project) {
        try {
            foreach ($s in @((Read-Json $project).songs)) {
                if ($s.artist -and $s.title) { $ids += "$($s.artist) - $($s.title)" }
            }
        } catch {}
    }
    return @($ids | Where-Object { $_ } | ForEach-Object { [string]$_ } | Sort-Object -Unique)
}

$musicPath = Join-Path $ModDir 'reskate-music.json'
if (-not (Test-Path -LiteralPath $musicPath)) {
    Write-Host "[!] Не нашёл $musicPath - мод ещё не собран."
    exit 1
}
$modFull = (Resolve-Path -LiteralPath $ModDir).Path.TrimEnd('\', '/')
$clashes = $false

# ---------- совпадения с другими модами ----------
if ($CheckClashes) {
    $ours = @(Get-ModSongs $modFull)
    $ourIds = @{}
    $ourSlugs = @{}
    foreach ($id in $ours) {
        $ourIds[$id.ToLowerInvariant()] = $id
        $slug = Get-Slug $id
        if (-not $ourSlugs.ContainsKey($slug)) { $ourSlugs[$slug] = @() }
        $ourSlugs[$slug] += $id
    }

    $modsDir = Split-Path -Parent $modFull
    foreach ($other in @(Get-ChildItem -LiteralPath $modsDir -Directory)) {
        if ($other.FullName.TrimEnd('\', '/') -ieq $modFull) { continue }
        $theirs = @(Get-ModSongs $other.FullName)
        if ($theirs.Count -eq 0) { continue }
        # Мод того же упаковщика кладёт треки в ту же папку игры, так что одинаковое имя = конфликт.
        $samePacker = Test-Path -LiteralPath (Join-Path $other.FullName 'reskate-build.json')
        $hits = @()
        $nonLatin = $false
        foreach ($t in $theirs) {
            if ($ourIds.ContainsKey($t.ToLowerInvariant())) {
                $hits += "  $($ourIds[$t.ToLowerInvariant()])   (такой же трек есть в этом моде)"
                continue
            }
            if (-not $samePacker) { continue }
            $slug = Get-Slug $t
            if ($ourSlugs.ContainsKey($slug)) {
                foreach ($mine in $ourSlugs[$slug]) { $hits += "  $mine   <->   $t" }
                if ($slug -eq 'song') { $nonLatin = $true }
            }
        }
        if ($hits.Count -eq 0) { continue }
        $clashes = $true
        Write-Host ''
        Write-Host "[!] СОВПАДЕНИЕ с модом ""$($other.Name)"":"
        $hits | Select-Object -Unique | ForEach-Object { Write-Host $_ }
        Write-Host '    Внутри игры у этих треков одно и то же имя. Из-за этого ReSkate выключает'
        Write-Host '    один из модов (значок CONFLICT в MODS), а старые версии ReSkate вылетают.'
        Write-Host '    Убери эти треки из папки music (или выключи другой мод) и пересобери.'
        if ($nonLatin) {
            Write-Host '    Треки, в названии которых нет латинских букв, внутри игры все называются "Song".'
            Write-Host '    Допиши латиницу в имя файла или теги, например "Shalapay - Verity French".'
        }
    }
    if (-not $clashes) { Write-Host '[ok] С другими модами треки не совпадают' }
}

# ---------- порядок ----------
if ($OrderFile) {
    $wanted = @()
    if (Test-Path -LiteralPath $OrderFile) {
        $wanted = @([System.IO.File]::ReadAllLines($OrderFile, $utf8) |
            ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
    }
    $doc = Read-Json $musicPath
    $missing = $false
    foreach ($pl in @($doc.playlists)) {
        $left = New-Object System.Collections.ArrayList
        foreach ($s in @($pl.songs)) { if ($s) { [void]$left.Add([string]$s) } }
        $front = @()
        foreach ($line in $wanted) {
            $words = @($line -split '[\s\-]+' | ForEach-Object { Normalize $_ } | Where-Object { $_ })
            if ($words.Count -eq 0) { continue }
            # Трек, в названии которого есть все слова строки. Если такого нет - тот, где их
            # больше половины, но только если такой один.
            $match = $null
            $best = 0
            $bestSongs = @()
            foreach ($s in $left) {
                $n = Normalize $s
                $found = @($words | Where-Object { $n.Contains($_) }).Count
                if ($found -eq $words.Count) { $match = $s; break }
                if ($found -gt $best) { $best = $found; $bestSongs = @($s) }
                elseif ($found -eq $best -and $found -gt 0) { $bestSongs += $s }
            }
            $guess = $false
            if (-not $match -and $best * 2 -gt $words.Count -and $bestSongs.Count -eq 1) {
                $match = $bestSongs[0]
                $guess = $true
            }
            if ($match) {
                $front += $match
                $left.Remove($match)
                if ($guess) { Write-Host "[?] $($front.Count). $match   (похоже на ""$line"")" }
                else { Write-Host "[ok] $($front.Count). $match" }
            } else {
                Write-Host "[!] Не нашёл трек ""$line"" из order.txt"
                $missing = $true
            }
        }
        $rest = @($left)
        if ($rest.Count -gt 1) { $rest = @($rest | Get-Random -Count $rest.Count) }
        $pl.songs = [string[]]($front + $rest)
        Write-Host "[ok] Остальные $($rest.Count) треков перемешаны"
        if ($missing) {
            Write-Host '    Треки в моде называются так (впиши в order.txt слова из нужного):'
            foreach ($s in @($pl.songs)) { Write-Host "      $s" }
        }
    }
    [System.IO.File]::WriteAllText($musicPath, ($doc | ConvertTo-Json -Depth 10), $utf8)
}

if ($clashes) { exit 3 }
exit 0
