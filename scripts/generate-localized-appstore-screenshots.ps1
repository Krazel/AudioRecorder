param(
    [string]$AppDir = "."
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path $AppDir
$storeDir = Join-Path $root "store\app-store"

Add-Type -AssemblyName System.Drawing

$FontFamily = "Segoe UI"
$Bg = [System.Drawing.Color]::FromArgb(247, 249, 252)
$Panel = [System.Drawing.Color]::White
$Ink = [System.Drawing.Color]::FromArgb(18, 28, 45)
$Muted = [System.Drawing.Color]::FromArgb(101, 111, 128)
$Blue = [System.Drawing.Color]::FromArgb(20, 113, 232)
$Red = [System.Drawing.Color]::FromArgb(240, 61, 58)
$Green = [System.Drawing.Color]::FromArgb(20, 148, 70)
$Amber = [System.Drawing.Color]::FromArgb(232, 176, 12)
$SoftBlue = [System.Drawing.Color]::FromArgb(234, 244, 255)
$SoftGreen = [System.Drawing.Color]::FromArgb(237, 252, 242)
$SoftRed = [System.Drawing.Color]::FromArgb(255, 241, 240)
$White = [System.Drawing.Color]::White

function New-Font($size, $style = "Regular") {
    return [System.Drawing.Font]::new($FontFamily, $size, [System.Drawing.FontStyle]::$style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Brush($color) {
    return [System.Drawing.SolidBrush]::new($color)
}

function Add-RoundRect($g, $x, $y, $w, $h, $r, $fill, $stroke = $null, $strokeWidth = 1) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    if ($r -le 0) {
        $path.AddRectangle([System.Drawing.RectangleF]::new($x, $y, $w, $h))
    } else {
        $d = $r * 2
        $path.AddArc($x, $y, $d, $d, 180, 90)
        $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
        $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
        $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
        $path.CloseFigure()
    }
    $g.FillPath((Brush $fill), $path)
    if ($null -ne $stroke) {
        $pen = [System.Drawing.Pen]::new($stroke, $strokeWidth)
        $g.DrawPath($pen, $path)
        $pen.Dispose()
    }
    $path.Dispose()
}

function Add-Text($g, $text, $x, $y, $w, $h, $font, $color, $align = "Near", $line = "Near") {
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::$align
    $format.LineAlignment = [System.Drawing.StringAlignment]::$line
    $format.Trimming = [System.Drawing.StringTrimming]::EllipsisWord
    $format.FormatFlags = 0
    $g.DrawString($text, $font, (Brush $color), [System.Drawing.RectangleF]::new($x, $y, $w, $h), $format)
    $format.Dispose()
}

function Add-FitText($g, $text, $x, $y, $w, $h, $size, $style, $color, $minSize = 34) {
    $font = $null
    for ($s = $size; $s -ge $minSize; $s -= 2) {
        if ($null -ne $font) { $font.Dispose() }
        $font = New-Font $s $style
        $measured = $g.MeasureString($text, $font, [System.Drawing.SizeF]::new($w, 1000))
        if ($measured.Height -le $h) {
            Add-Text $g $text $x $y $w $h $font $color
            $font.Dispose()
            return
        }
    }
    Add-Text $g $text $x $y $w $h $font $color
    $font.Dispose()
}

function Add-Waves($g) {
    $colors = @(
        [System.Drawing.Color]::FromArgb(70, 49, 128, 235),
        [System.Drawing.Color]::FromArgb(44, 20, 148, 70),
        [System.Drawing.Color]::FromArgb(35, 240, 61, 58)
    )
    for ($i = 0; $i -lt 3; $i++) {
        $pen = [System.Drawing.Pen]::new($colors[$i], 3)
        $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $y = 470 + ($i * 32)
        $path.AddBezier(0, $y, 260, $y - 55, 430, $y + 35, 645, $y)
        $path.AddBezier(645, $y, 850, $y - 45, 1040, $y + 45, 1290, $y)
        $g.DrawPath($pen, $path)
        $path.Dispose()
        $pen.Dispose()
    }
}

function Add-Pill($g, $text, $x, $y, $w, $fill, $color) {
    Add-RoundRect $g $x $y $w 48 24 $fill
    Add-Text $g $text $x ($y + 8) $w 30 (New-Font 19 "Bold") $color "Center"
}

function Add-Phone($g, $x, $y, $w, $h) {
    Add-RoundRect $g ($x - 7) ($y - 7) ($w + 14) ($h + 14) 56 ([System.Drawing.Color]::FromArgb(18, 27, 43))
    Add-RoundRect $g $x $y $w $h 48 $Panel
    Add-RoundRect $g ($x + ($w / 2) - 54) ($y + 24) 108 18 9 ([System.Drawing.Color]::FromArgb(18, 27, 43))
}

function Add-TabBar($g, $x, $y, $w, $labels, $active) {
    Add-RoundRect $g $x $y $w 96 0 $Panel
    for ($i = 0; $i -lt 3; $i++) {
        $color = if ($i -eq $active) { $Blue } else { [System.Drawing.Color]::FromArgb(165, 172, 184) }
        Add-Text $g $labels[$i] ($x + $i * ($w / 3)) ($y + 36) ($w / 3) 34 (New-Font 18 "Bold") $color "Center"
    }
}

function Add-RecorderUI($g, $x, $y, $w, $h, $copy, $recording) {
    Add-Text $g $copy.recTitle ($x + 34) ($y + 92) ($w - 68) 58 (New-Font 37 "Bold") $Ink "Center"
    Add-Text $g $copy.recSub ($x + 45) ($y + 150) ($w - 90) 44 (New-Font 18) $Muted "Center"
    $cx = $x + ($w / 2)
    $cy = $y + 390
    $outer = [System.Drawing.RectangleF]::new($cx - 145, $cy - 145, 290, 290)
    $inner = [System.Drawing.RectangleF]::new($cx - 108, $cy - 108, 216, 216)
    $fill = if ($recording) { [System.Drawing.Color]::FromArgb(255, 219, 219) } else { [System.Drawing.Color]::FromArgb(239, 240, 243) }
    $stroke = if ($recording) { $Red } else { [System.Drawing.Color]::FromArgb(134, 137, 143) }
    $g.FillEllipse((Brush $fill), $outer)
    $g.DrawEllipse([System.Drawing.Pen]::new($stroke, 6), $inner)
    if ($recording) {
        Add-RoundRect $g ($cx - 42) ($cy - 42) 84 84 12 $Red
    } else {
        Add-Text $g "Mic" ($cx - 80) ($cy - 38) 160 76 (New-Font 38 "Bold") ([System.Drawing.Color]::Black) "Center" "Center"
    }
    $stats = if ($recording) {
        @(@("00:05", $copy.segment), @("38 dB", $copy.level), @($copy.saving, $copy.status))
    } else {
        @(@("00:07", $copy.segment), @("30 dB", $copy.level), @($copy.waiting, $copy.status))
    }
    for ($i = 0; $i -lt 3; $i++) {
        $bx = $x + 42 + ($i * (($w - 84) / 3))
        Add-RoundRect $g $bx ($y + 615) 142 96 12 ([System.Drawing.Color]::FromArgb(242, 242, 248))
        Add-Text $g $stats[$i][0] $bx ($y + 634) 142 34 (New-Font 24 "Bold") $Ink "Center"
        Add-Text $g $stats[$i][1] $bx ($y + 670) 142 25 (New-Font 15) $Muted "Center"
    }
    Add-RoundRect $g ($x + 42) ($y + 760) ($w - 84) 174 12 ([System.Drawing.Color]::FromArgb(247, 247, 247))
    $rows = @(@($copy.quality, $copy.high), @($copy.cut, $copy.cutValue), @($copy.mode, $copy.allMode))
    for ($i = 0; $i -lt 3; $i++) {
        $ry = $y + 790 + ($i * 48)
        Add-Text $g $rows[$i][0] ($x + 70) $ry 180 30 (New-Font 19) $Muted
        Add-Text $g $rows[$i][1] ($x + 285) $ry 210 30 (New-Font 19 "Bold") $Ink "Far"
    }
}

function Add-FilesUI($g, $x, $y, $w, $h, $copy) {
    Add-Text $g $copy.select ($x + 34) ($y + 80) 160 32 (New-Font 18 "Bold") $Blue
    Add-Text $g $copy.files ($x + 34) ($y + 124) ($w - 68) 58 (New-Font 42 "Bold") $Ink
    $names = @($copy.fileA, $copy.fileB, $copy.fileC, $copy.fileD)
    $details = @($copy.detailA, $copy.detailB, $copy.detailC, $copy.detailD)
    for ($i = 0; $i -lt 4; $i++) {
        $rowY = $y + 230 + ($i * 162)
        Add-RoundRect $g ($x + 34) $rowY ($w - 68) 134 16 $Panel
        Add-Text $g "Play" ($x + 58) ($rowY + 48) 64 28 (New-Font 15 "Bold") ([System.Drawing.Color]::Black) "Center"
        Add-Text $g $names[$i] ($x + 138) ($rowY + 22) 245 32 (New-Font 20 "Bold") $Ink
        Add-Text $g $copy.local ($x + 415) ($rowY + 22) 70 28 (New-Font 15) $Muted "Far"
        Add-Text $g $details[$i] ($x + 138) ($rowY + 58) 260 26 (New-Font 15) $Muted
        Add-Text $g "AAC" ($x + 138) ($rowY + 88) 70 24 (New-Font 14) $Muted
        $starColor = if ($i -lt 2) { $Amber } else { $Muted }
        Add-Text $g "*" ($x + 455) ($rowY + 34) 40 42 (New-Font 30 "Bold") $starColor "Center"
    }
}

function Add-Callout($g, $title, $sub, $accent, $soft) {
    Add-RoundRect $g 84 2438 1122 112 24 $White
    Add-RoundRect $g 105 2458 1080 72 18 $soft
    Add-Text $g $title 132 2468 560 28 (New-Font 19 "Bold") $Ink
    Add-Text $g $sub 132 2497 920 24 (New-Font 15) $Muted
}

function New-Shot($locale, $file, $copy, $kind) {
    $dir = Join-Path $storeDir "$locale\iphone-67"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $path = Join-Path $dir $file
    $bmp = [System.Drawing.Bitmap]::new(1290, 2796)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.Clear($Bg)
    Add-Waves $g
    Add-FitText $g $copy.headline 70 84 900 190 62 "Bold" $Ink 42
    Add-Text $g $copy.subhead 72 270 970 82 (New-Font 23) $Muted
    Add-Pill $g $copy.pillA 76 390 170 $SoftGreen $Green
    Add-Pill $g $copy.pillB 270 390 150 $SoftBlue $Blue
    $phoneX = 388
    $phoneY = 590
    $phoneW = 514
    $phoneH = 1290
    Add-Phone $g $phoneX $phoneY $phoneW $phoneH
    if ($kind -eq "ready") { Add-RecorderUI $g $phoneX ($phoneY + 18) $phoneW ($phoneH - 36) $copy $false; Add-TabBar $g $phoneX ($phoneY + 1156) $phoneW $copy.tabs 0; Add-Callout $g $copy.callTitle $copy.callSub $Blue $SoftGreen }
    if ($kind -eq "recording") { Add-RecorderUI $g $phoneX ($phoneY + 18) $phoneW ($phoneH - 36) $copy $true; Add-TabBar $g $phoneX ($phoneY + 1156) $phoneW $copy.tabs 0; Add-Callout $g $copy.callTitle $copy.callSub $Red $SoftRed }
    if ($kind -eq "files") { Add-FilesUI $g $phoneX ($phoneY + 18) $phoneW ($phoneH - 36) $copy; Add-TabBar $g $phoneX ($phoneY + 1156) $phoneW $copy.tabs 1; Add-Callout $g $copy.callTitle $copy.callSub $Green $SoftBlue }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    return $path
}

$baseUi = @{
    segment = "Segmento"; level = "Nivel"; status = "Estado"; waiting = "Espera"; saving = "Guardando"; quality = "Calidad"; high = "Alta"; cut = "Corte"; cutValue = "30 min"; mode = "Modo"; allMode = "Todo"; recTitle = "Preparado"; recSub = "Toca el microfono para empezar"; select = "Seleccionar"; files = "Archivos"; local = "Local"; tabs = @("Grabar", "Archivos", "Ajustes")
    fileA = "Reunion larga"; fileB = "Idea rapida"; fileC = "Nota de voz"; fileD = "Clase de audio"; detailA = "22 May 2026 a las 3:32"; detailB = "21 May 2026 a las 20:36"; detailC = "21 May 2026 a las 20:36"; detailD = "21 May 2026 a las 20:35"
}

$locales = @{
    "en-US" = @(
        @{ headline = "Option: record when there is sound"; subhead = "Also record everything followed. Turn this mode on if you want to avoid silence."; pillA = "Optional mode"; pillB = "Free"; callTitle = "You choose how to record"; callSub = "Everything followed or only when sound is detected." },
        @{ headline = "Record everything you need"; subhead = "Works during long sessions and creates files by intervals to keep it organized."; pillA = "Long sessions"; pillB = "Automatic cuts"; callTitle = "Long recording without fuss"; callSub = "Organize files by time." },
        @{ headline = "All features are free"; subhead = "Play, favorite, rename, delete, and share without locking the basics."; pillA = "Free"; pillB = "No account"; callTitle = "Your audio always accessible"; callSub = "Play, organize, and share." }
    )
    "fr-FR" = @(
        @{ headline = "Option : enregistrer quand il y a du son"; subhead = "Vous pouvez aussi tout enregistrer. Activez ce mode pour eviter les silences."; pillA = "Mode optionnel"; pillB = "Gratuit"; callTitle = "Vous choisissez le mode"; callSub = "Tout enregistrer ou seulement quand il y a du son." },
        @{ headline = "Enregistrez tout ce dont vous avez besoin"; subhead = "Fonctionne pendant les longues sessions et cree des fichiers par intervalles."; pillA = "Sessions longues"; pillB = "Decoupes auto"; callTitle = "Enregistrement long, simple"; callSub = "Organisez les fichiers par duree." },
        @{ headline = "Toutes les fonctions sont gratuites"; subhead = "Ecoutez, ajoutez aux favoris, renommez, supprimez et partagez."; pillA = "Gratuit"; pillB = "Sans compte"; callTitle = "Vos audios restent accessibles"; callSub = "Ecoutez, organisez et partagez." }
    )
    "de-DE" = @(
        @{ headline = "Option: aufnehmen, wenn Ton da ist"; subhead = "Du kannst auch alles durchgehend aufnehmen. Nutze diesen Modus gegen Stille."; pillA = "Optionaler Modus"; pillB = "Gratis"; callTitle = "Du waehlst die Aufnahmeart"; callSub = "Durchgehend oder nur bei erkanntem Ton." },
        @{ headline = "Nimm alles auf, was du brauchst"; subhead = "Laeuft in langen Sitzungen und erstellt Dateien nach Intervallen."; pillA = "Lange Sitzungen"; pillB = "Auto-Schnitte"; callTitle = "Lange Aufnahme ohne Aufwand"; callSub = "Dateien nach Zeit ordnen." },
        @{ headline = "Alle Funktionen sind gratis"; subhead = "Abspielen, Favoriten, Umbenennen, Loeschen und Teilen ohne Sperren."; pillA = "Gratis"; pillB = "Kein Konto"; callTitle = "Deine Audios bleiben erreichbar"; callSub = "Abspielen, ordnen und teilen." }
    )
    "it" = @(
        @{ headline = "Opzione: registra quando c'e suono"; subhead = "Puoi anche registrare tutto di seguito. Attiva questo modo per evitare silenzi."; pillA = "Modo opzionale"; pillB = "Gratis"; callTitle = "Scegli come registrare"; callSub = "Tutto di seguito o solo quando rileva suono." },
        @{ headline = "Registra tutto cio che ti serve"; subhead = "Funziona durante sessioni lunghe e crea file per intervalli."; pillA = "Sessioni lunghe"; pillB = "Tagli automatici"; callTitle = "Registrazione lunga semplice"; callSub = "Organizza i file per tempo." },
        @{ headline = "Tutte le funzioni sono gratis"; subhead = "Riproduci, preferiti, rinomina, elimina e condividi senza blocchi."; pillA = "Gratis"; pillB = "Senza account"; callTitle = "I tuoi audio sempre accessibili"; callSub = "Riproduci, organizza e condividi." }
    )
    "pt-PT" = @(
        @{ headline = "Opcao: gravar quando ha som"; subhead = "Tambem pode gravar tudo seguido. Ative este modo para evitar silencios."; pillA = "Modo opcional"; pillB = "Gratis"; callTitle = "Escolhe como gravar"; callSub = "Tudo seguido ou so quando deteta som." },
        @{ headline = "Grave tudo o que precisa"; subhead = "Funciona em sessoes longas e cria ficheiros por intervalos."; pillA = "Sessoes longas"; pillB = "Cortes automaticos"; callTitle = "Gravacao longa sem complicar"; callSub = "Organiza ficheiros por tempo." },
        @{ headline = "Todas as funcoes sao gratis"; subhead = "Reproduza, favoritos, renomeie, apague e partilhe sem bloquear o basico."; pillA = "Gratis"; pillB = "Sem conta"; callTitle = "Os seus audios sempre acessiveis"; callSub = "Reproduza, organize e partilhe." }
    )
    "ca" = @(
        @{ headline = "Opcio: grava quan hi ha so"; subhead = "Tambee pots gravar-ho tot seguit. Activa aquest mode per evitar silencis."; pillA = "Mode opcional"; pillB = "Gratis"; callTitle = "Tries com gravar"; callSub = "Tot seguit o nomes quan detecta so." },
        @{ headline = "Grava tot el que necessites"; subhead = "Funciona durant sessions llargues i crea fitxers per intervals."; pillA = "Sessions llargues"; pillB = "Talls automatics"; callTitle = "Gravacio llarga sense complicar"; callSub = "Organitza els fitxers per temps." },
        @{ headline = "Totes les funcions son gratis"; subhead = "Reprodueix, preferits, reanomena, elimina i comparteix sense bloquejos."; pillA = "Gratis"; pillB = "Sense compte"; callTitle = "Els teus audios sempre accessibles"; callSub = "Reprodueix, organitza i comparteix." }
    )
}

$uiByLocale = @{
    "en-US" = @{ segment = "Segment"; level = "Level"; status = "Status"; waiting = "Waiting"; saving = "Saving"; quality = "Quality"; high = "High"; cut = "Cut"; cutValue = "30 min"; mode = "Mode"; allMode = "All"; recTitle = "Ready"; recSub = "Tap the microphone to start"; select = "Select"; files = "Files"; local = "Local"; tabs = @("Record", "Files", "Settings"); fileA = "Long meeting"; fileB = "Quick idea"; fileC = "Voice note"; fileD = "Audio class"; detailA = "22 May 2026 at 3:32"; detailB = "21 May 2026 at 20:36"; detailC = "21 May 2026 at 20:36"; detailD = "21 May 2026 at 20:35" }
    "fr-FR" = @{ segment = "Segment"; level = "Niveau"; status = "Etat"; waiting = "Attente"; saving = "En cours"; quality = "Qualite"; high = "Haute"; cut = "Coupe"; cutValue = "30 min"; mode = "Mode"; allMode = "Tout"; recTitle = "Pret"; recSub = "Touchez le micro pour demarrer"; select = "Selectionner"; files = "Fichiers"; local = "Local"; tabs = @("Enregistrer", "Fichiers", "Reglages"); fileA = "Reunion longue"; fileB = "Idee rapide"; fileC = "Note vocale"; fileD = "Cours audio"; detailA = "22 mai 2026 a 3:32"; detailB = "21 mai 2026 a 20:36"; detailC = "21 mai 2026 a 20:36"; detailD = "21 mai 2026 a 20:35" }
    "de-DE" = @{ segment = "Segment"; level = "Pegel"; status = "Status"; waiting = "Warten"; saving = "Sichert"; quality = "Qualitaet"; high = "Hoch"; cut = "Schnitt"; cutValue = "30 Min"; mode = "Modus"; allMode = "Alles"; recTitle = "Bereit"; recSub = "Tippe auf das Mikrofon"; select = "Auswaehlen"; files = "Dateien"; local = "Lokal"; tabs = @("Aufnahme", "Dateien", "Einstellungen"); fileA = "Langes Meeting"; fileB = "Schnelle Idee"; fileC = "Sprachnotiz"; fileD = "Audiokurs"; detailA = "22 Mai 2026 um 3:32"; detailB = "21 Mai 2026 um 20:36"; detailC = "21 Mai 2026 um 20:36"; detailD = "21 Mai 2026 um 20:35" }
    "it" = @{ segment = "Segmento"; level = "Livello"; status = "Stato"; waiting = "Attesa"; saving = "Salva"; quality = "Qualita"; high = "Alta"; cut = "Taglio"; cutValue = "30 min"; mode = "Modo"; allMode = "Tutto"; recTitle = "Pronto"; recSub = "Tocca il microfono"; select = "Seleziona"; files = "File"; local = "Locale"; tabs = @("Registra", "File", "Impostazioni"); fileA = "Riunione lunga"; fileB = "Idea rapida"; fileC = "Nota vocale"; fileD = "Lezione audio"; detailA = "22 mag 2026 alle 3:32"; detailB = "21 mag 2026 alle 20:36"; detailC = "21 mag 2026 alle 20:36"; detailD = "21 mag 2026 alle 20:35" }
    "pt-PT" = @{ segment = "Segmento"; level = "Nivel"; status = "Estado"; waiting = "Espera"; saving = "A guardar"; quality = "Qualidade"; high = "Alta"; cut = "Corte"; cutValue = "30 min"; mode = "Modo"; allMode = "Tudo"; recTitle = "Pronto"; recSub = "Toque no microfone"; select = "Selecionar"; files = "Ficheiros"; local = "Local"; tabs = @("Gravar", "Ficheiros", "Ajustes"); fileA = "Reuniao longa"; fileB = "Ideia rapida"; fileC = "Nota de voz"; fileD = "Aula de audio"; detailA = "22 mai 2026 as 3:32"; detailB = "21 mai 2026 as 20:36"; detailC = "21 mai 2026 as 20:36"; detailD = "21 mai 2026 as 20:35" }
    "ca" = @{ segment = "Segment"; level = "Nivell"; status = "Estat"; waiting = "Espera"; saving = "Desant"; quality = "Qualitat"; high = "Alta"; cut = "Tall"; cutValue = "30 min"; mode = "Mode"; allMode = "Tot"; recTitle = "Preparat"; recSub = "Toca el microfon"; select = "Seleccionar"; files = "Fitxers"; local = "Local"; tabs = @("Gravar", "Fitxers", "Ajustos"); fileA = "Reunio llarga"; fileB = "Idea rapida"; fileC = "Nota de veu"; fileD = "Classe audio"; detailA = "22 maig 2026 a les 3:32"; detailB = "21 maig 2026 a les 20:36"; detailC = "21 maig 2026 a les 20:36"; detailD = "21 maig 2026 a les 20:35" }
}

foreach ($locale in $locales.Keys) {
    $screens = $locales[$locale]
    for ($i = 0; $i -lt 3; $i++) {
        $copy = @{}
        foreach ($key in $baseUi.Keys) { $copy[$key] = $baseUi[$key] }
        foreach ($key in $uiByLocale[$locale].Keys) { $copy[$key] = $uiByLocale[$locale][$key] }
        foreach ($key in $screens[$i].Keys) { $copy[$key] = $screens[$i][$key] }
        $file = @("01-sound-mode.png", "02-long-recording.png", "03-free-features.png")[$i]
        $kind = @("ready", "recording", "files")[$i]
        $out = New-Shot $locale $file $copy $kind
        Write-Host "$locale $file"
    }
}
