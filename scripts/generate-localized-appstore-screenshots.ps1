param(
    [string]$AppDir = "."
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path $AppDir
$storeDir = Join-Path $root "store\app-store"

Add-Type -AssemblyName System.Drawing

$FontFamily = "Segoe UI"
$Ink = [System.Drawing.Color]::FromArgb(13, 22, 38)
$Muted = [System.Drawing.Color]::FromArgb(94, 104, 122)
$Blue = [System.Drawing.Color]::FromArgb(0, 112, 243)
$Green = [System.Drawing.Color]::FromArgb(21, 134, 76)
$Red = [System.Drawing.Color]::FromArgb(216, 43, 55)
$SoftBlue = [System.Drawing.Color]::FromArgb(232, 243, 255)
$SoftGreen = [System.Drawing.Color]::FromArgb(225, 249, 235)
$SoftRed = [System.Drawing.Color]::FromArgb(255, 232, 228)
$White = [System.Drawing.Color]::White
$Border = [System.Drawing.Color]::FromArgb(208, 222, 236)

function New-Font($size, $style = "Regular") {
    return [System.Drawing.Font]::new($FontFamily, $size, [System.Drawing.FontStyle]::$style, [System.Drawing.GraphicsUnit]::Pixel)
}

function New-Brush($color) {
    return [System.Drawing.SolidBrush]::new($color)
}

function Add-RoundRect($g, $x, $y, $w, $h, $r, $fill, $stroke = $null, $strokeWidth = 1) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Brush $fill), $path)
    if ($null -ne $stroke) {
        $pen = [System.Drawing.Pen]::new($stroke, $strokeWidth)
        $g.DrawPath($pen, $path)
        $pen.Dispose()
    }
    $path.Dispose()
}

function Add-Text($g, $text, $x, $y, $w, $h, $font, $color, $align = "Near") {
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::$align
    $format.LineAlignment = [System.Drawing.StringAlignment]::Near
    $format.Trimming = [System.Drawing.StringTrimming]::EllipsisWord
    $g.DrawString($text, $font, (New-Brush $color), [System.Drawing.RectangleF]::new($x, $y, $w, $h), $format)
    $format.Dispose()
}

function Add-FitLine($g, $text, $x, $y, $w, $h, $size, $minSize, $style, $color, $align = "Near") {
    $font = $null
    for ($s = $size; $s -ge $minSize; $s -= 1) {
        if ($null -ne $font) { $font.Dispose() }
        $font = New-Font $s $style
        $measured = $g.MeasureString($text, $font)
        if ($measured.Width -le $w -and $measured.Height -le $h) {
            Add-Text $g $text $x $y $w $h $font $color $align
            $font.Dispose()
            return
        }
    }
    Add-Text $g $text $x $y $w $h $font $color $align
    $font.Dispose()
}

function Add-FitText($g, $text, $x, $y, $w, $h, $size, $minSize = 58) {
    $font = $null
    for ($s = $size; $s -ge $minSize; $s -= 2) {
        if ($null -ne $font) { $font.Dispose() }
        $font = New-Font $s "Bold"
        $measured = $g.MeasureString($text, $font, [System.Drawing.SizeF]::new($w, 1000))
        if ($measured.Height -le $h) {
            Add-Text $g $text $x $y $w $h $font $Ink
            $font.Dispose()
            return
        }
    }
    Add-Text $g $text $x $y $w $h $font $Ink
    $font.Dispose()
}

function Add-FitBlock($g, $text, $x, $y, $w, $h, $size, $minSize, $style, $color) {
    $font = $null
    for ($s = $size; $s -ge $minSize; $s -= 1) {
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

function Add-Pill($g, $text, $x, $y, $fill, $color) {
    $font = New-Font 34 "Bold"
    $size = $g.MeasureString($text, $font)
    $w = [Math]::Ceiling($size.Width) + 62
    Add-RoundRect $g $x $y $w 76 38 $fill
    Add-Text $g $text $x ($y + 19) $w 40 $font $color "Center"
    $font.Dispose()
    return $w
}

function Add-Callout($g, $copy, $soft) {
    Add-RoundRect $g 90 2338 1110 142 30 $soft
    Add-RoundRect $g 126 2374 1038 90 26 $White $Border 2
    Add-FitLine $g $copy.callTitle 166 2392 930 40 38 28 "Bold" $Ink
    Add-FitLine $g $copy.callSub 166 2434 930 34 28 22 "Regular" $Muted
}

function Add-Centered($g, $text, $x, $y, $w, $h, $font, $color) {
    Add-Text $g $text $x $y $w $h $font $color "Center"
}

function Add-Right($g, $text, $x, $y, $w, $h, $font, $color) {
    Add-Text $g $text $x $y $w $h $font $color "Far"
}

function Add-RecorderPhoneText($g, $image, $ui, $recording) {
    $white = $White
    $card = [System.Drawing.Color]::FromArgb(246, 245, 250)
    $info = [System.Drawing.Color]::FromArgb(247, 247, 247)

    $g.FillRectangle((New-Brush $white), [System.Drawing.Rectangle]::new(365, 1000, 560, 130))
    Add-FitLine $g $(if ($recording) { $ui.recordingTitle } else { $ui.readyTitle }) 365 1015 560 62 54 34 "Bold" ([System.Drawing.Color]::Black) "Center"
    Add-FitLine $g $(if ($recording) { $ui.recordingSub } else { $ui.readySub }) 330 1090 630 42 28 18 "Regular" ([System.Drawing.Color]::FromArgb(139, 139, 142)) "Center"

    $cards = @(
        @{ X = 330; Value = $(if ($recording) { "00:05" } else { "00:07" }); Label = $ui.segment },
        @{ X = 550; Value = $(if ($recording) { "38 dB" } else { "30 dB" }); Label = $ui.level },
        @{ X = 770; Value = $(if ($recording) { $ui.saving } else { $ui.waiting }); Label = $ui.status }
    )
    foreach ($cardInfo in $cards) {
        Add-RoundRect $g $cardInfo.X 1646 190 142 12 $card
        Add-FitLine $g $cardInfo.Value $cardInfo.X 1680 190 48 40 26 "Bold" ([System.Drawing.Color]::Black) "Center"
        Add-FitLine $g $cardInfo.Label $cardInfo.X 1735 190 34 25 18 "Regular" ([System.Drawing.Color]::FromArgb(138, 138, 142)) "Center"
    }

    Add-RoundRect $g 330 1845 630 220 16 $info
    $rows = @(
        @{ Y = 1884; Left = $ui.quality; Right = $ui.high },
        @{ Y = 1948; Left = $ui.cut; Right = $ui.cutValue },
        @{ Y = 2012; Left = $ui.mode; Right = $ui.allMode }
    )
    foreach ($row in $rows) {
        Add-FitLine $g $row.Left 360 $row.Y 245 40 34 24 "Regular" ([System.Drawing.Color]::FromArgb(139, 139, 142))
        Add-FitLine $g $row.Right 635 $row.Y 285 40 32 22 "Bold" ([System.Drawing.Color]::Black) "Far"
    }

    Add-TabLabels $g $ui.tabs 0
}

function Add-FilesPhoneText($g, $image, $ui) {
    $phoneBg = ([System.Drawing.Bitmap]$image).GetPixel(326, 880)
    $white = $White
    $light = [System.Drawing.Color]::FromArgb(172, 172, 176)

    $g.FillRectangle((New-Brush $phoneBg), [System.Drawing.Rectangle]::new(324, 875, 250, 60))
    $g.FillRectangle((New-Brush $phoneBg), [System.Drawing.Rectangle]::new(324, 960, 360, 86))
    Add-FitLine $g $ui.select 330 902 210 38 31 20 "Regular" $Blue
    Add-FitLine $g $ui.files 330 985 340 70 58 42 "Bold" ([System.Drawing.Color]::Black)

    $rowTops = @(1088, 1325, 1562, 1800)
    for ($i = 0; $i -lt 4; $i++) {
        $top = $rowTops[$i]
        $g.FillRectangle((New-Brush $white), [System.Drawing.Rectangle]::new(420, $top, 465, 206))
        $g.FillRectangle((New-Brush $white), [System.Drawing.Rectangle]::new(850, $top + 78, 92, 126))
        Add-FitLine $g $ui.dates[$i] 430 ($top + 25) 360 44 30 18 "Bold" ([System.Drawing.Color]::Black)
        Add-FitLine $g $ui.local 800 ($top + 32) 78 34 23 16 "Regular" ([System.Drawing.Color]::FromArgb(137, 137, 141))
        Add-FitLine $g $ui.meta[$i] 430 ($top + 83) 300 34 22 16 "Regular" ([System.Drawing.Color]::FromArgb(137, 137, 141))
        Add-FitLine $g $ui.modes[$i] 430 ($top + 122) 180 32 22 16 "Regular" ([System.Drawing.Color]::FromArgb(137, 137, 141))
        Add-FitLine $g $ui.qualityFile 610 ($top + 122) 230 32 22 16 "Regular" ([System.Drawing.Color]::FromArgb(137, 137, 141))
        Add-FitLine $g $ui.names[$i] 430 ($top + 158) 390 32 20 14 "Regular" ([System.Drawing.Color]::FromArgb(198, 198, 202))
    }

    Add-TabLabels $g $ui.tabs 1
}

function Add-TabLabels($g, $tabs, $active) {
    $bg1 = $White
    $bg3 = ([System.Drawing.Color]::FromArgb(241, 240, 247))
    $positions = @(
        @{ X = 362; W = 90 },
        @{ X = 587; W = 116 },
        @{ X = 820; W = 112 }
    )
    for ($i = 0; $i -lt 3; $i++) {
        $bg = if ($active -eq 1) { $bg3 } else { $bg1 }
        $g.FillRectangle((New-Brush $bg), [System.Drawing.Rectangle]::new($positions[$i].X, 2200, $positions[$i].W, 42))
        $color = if ($i -eq $active) { $Blue } else { [System.Drawing.Color]::FromArgb(155, 155, 158) }
        Add-FitLine $g $tabs[$i] $positions[$i].X 2200 $positions[$i].W 36 23 14 "Regular" $color "Center"
    }
}

function New-LocalizedShot($template, $dest, $copy, $ui, $kind) {
    $image = [System.Drawing.Image]::FromFile($template)
    $bmp = [System.Drawing.Bitmap]::new($image.Width, $image.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.DrawImage($image, 0, 0, $image.Width, $image.Height)

    $bg = ([System.Drawing.Bitmap]$image).GetPixel(18, 18)
    $g.FillRectangle((New-Brush $bg), [System.Drawing.Rectangle]::new(62, 92, 1120, 430))
    $g.FillRectangle((New-Brush $bg), [System.Drawing.Rectangle]::new(62, 516, 820, 86))
    $g.FillRectangle((New-Brush $bg), [System.Drawing.Rectangle]::new(80, 2322, 1135, 178))

    Add-FitText $g $copy.headline 76 105 1030 202 78 54
    Add-FitBlock $g $copy.subhead 78 328 1010 112 40 28 "Regular" $Muted

    $pill1Color = if ($kind -eq "recording") { $Red } elseif ($kind -eq "free") { $Blue } else { $Green }
    $pill1Fill = if ($kind -eq "recording") { $SoftRed } elseif ($kind -eq "free") { $SoftBlue } else { $SoftGreen }
    $pill2Color = if ($kind -eq "free") { $Green } else { $Blue }
    $pill2Fill = if ($kind -eq "free") { $SoftGreen } else { $SoftBlue }
    $w1 = Add-Pill $g $copy.pillA 76 530 $pill1Fill $pill1Color
    [void](Add-Pill $g $copy.pillB (76 + $w1 + 18) 530 $pill2Fill $pill2Color)

    $soft = if ($kind -eq "recording") { $SoftRed } elseif ($kind -eq "free") { $SoftBlue } else { $SoftGreen }
    Add-Callout $g $copy $soft

    if ($kind -eq "ready") { Add-RecorderPhoneText $g $image $ui $false }
    if ($kind -eq "recording") { Add-RecorderPhoneText $g $image $ui $true }
    if ($kind -eq "free") { Add-FilesPhoneText $g $image $ui }

    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    $image.Dispose()
}

$templates = @(
    @{ Kind = "ready"; File = "01-sound-mode.png"; Template = "store\app-store\es-ES\iphone-67\01-opcion-grabar-por-sonido.png" },
    @{ Kind = "recording"; File = "02-long-recording.png"; Template = "store\app-store\es-ES\iphone-67\02-graba-sin-limite-fijo.png" },
    @{ Kind = "free"; File = "03-free-features.png"; Template = "store\app-store\es-ES\iphone-67\03-todas-las-funciones-gratis.png" }
)

$copy = @{
    "en-US" = @(
        @{ headline = "Option: record when there is sound"; subhead = "You can also record everything continuously. Turn this mode on if you want to avoid silences."; pillA = "Optional mode"; pillB = "Free"; callTitle = "You choose how to record"; callSub = "Continuously or only when sound is detected." },
        @{ headline = "Record everything you need"; subhead = "Works during long sessions and creates files by intervals to keep everything organized."; pillA = "Long sessions"; pillB = "Automatic cuts"; callTitle = "Long recording without fuss"; callSub = "Organize files by time." },
        @{ headline = "All features are free"; subhead = "Play, mark favorites, rename, delete, and share without locking the basics."; pillA = "Free"; pillB = "No account"; callTitle = "Your audio always accessible"; callSub = "Play, organize, and share." }
    )
    "fr-FR" = @(
        @{ headline = "Option : enregistrer quand il y a du son"; subhead = "Vous pouvez aussi tout enregistrer en continu. Activez ce mode pour eviter les silences."; pillA = "Mode optionnel"; pillB = "Gratuit"; callTitle = "Vous choisissez comment enregistrer"; callSub = "En continu ou seulement quand un son est detecte." },
        @{ headline = "Enregistrez tout ce dont vous avez besoin"; subhead = "Fonctionne pendant les longues sessions et cree des fichiers par intervalles pour rester organise."; pillA = "Sessions longues"; pillB = "Decoupes auto"; callTitle = "Enregistrement long, simple"; callSub = "Organisez les fichiers par duree." },
        @{ headline = "Toutes les fonctions sont gratuites"; subhead = "Ecoutez, ajoutez aux favoris, renommez, supprimez et partagez sans bloquer l essentiel."; pillA = "Gratuit"; pillB = "Sans compte"; callTitle = "Vos audios toujours accessibles"; callSub = "Ecoutez, organisez et partagez." }
    )
    "de-DE" = @(
        @{ headline = "Option: aufnehmen, wenn Ton da ist"; subhead = "Du kannst auch alles durchgehend aufnehmen. Aktiviere diesen Modus, wenn du Stille vermeiden willst."; pillA = "Optionaler Modus"; pillB = "Gratis"; callTitle = "Du waehlst, wie du aufnimmst"; callSub = "Durchgehend oder nur, wenn Ton erkannt wird." },
        @{ headline = "Nimm alles auf, was du brauchst"; subhead = "Funktioniert in langen Sitzungen und erstellt Dateien in Intervallen, damit alles geordnet bleibt."; pillA = "Lange Sitzungen"; pillB = "Auto-Schnitte"; callTitle = "Lange Aufnahme ohne Aufwand"; callSub = "Dateien nach Zeit organisieren." },
        @{ headline = "Alle Funktionen sind gratis"; subhead = "Abspielen, Favoriten, Umbenennen, Loeschen und Teilen ohne Sperren der Basisfunktionen."; pillA = "Gratis"; pillB = "Kein Konto"; callTitle = "Deine Audios immer erreichbar"; callSub = "Abspielen, organisieren und teilen." }
    )
    "it" = @(
        @{ headline = "Opzione: registra quando c'e suono"; subhead = "Puoi anche registrare tutto di seguito. Attiva questo modo se vuoi evitare silenzi."; pillA = "Modo opzionale"; pillB = "Gratis"; callTitle = "Scegli come registrare"; callSub = "Tutto di seguito o solo quando rileva suono." },
        @{ headline = "Registra tutto cio che ti serve"; subhead = "Funziona durante sessioni lunghe e crea file per intervalli per tenerli ordinati."; pillA = "Sessioni lunghe"; pillB = "Tagli automatici"; callTitle = "Registrazione lunga semplice"; callSub = "Organizza i file per tempo." },
        @{ headline = "Tutte le funzioni sono gratis"; subhead = "Riproduci, marca preferiti, rinomina, elimina e condividi senza bloccare il basico."; pillA = "Gratis"; pillB = "Senza account"; callTitle = "I tuoi audio sempre accessibili"; callSub = "Riproduci, organizza e condividi." }
    )
    "pt-PT" = @(
        @{ headline = "Opcao: gravar quando ha som"; subhead = "Tambem pode gravar tudo seguido. Ative este modo se quiser evitar silencios."; pillA = "Modo opcional"; pillB = "Gratis"; callTitle = "Escolhe como gravar"; callSub = "Tudo seguido ou so quando deteta som." },
        @{ headline = "Grave tudo o que precisa"; subhead = "Funciona durante sessoes longas e cria ficheiros por intervalos para manter tudo organizado."; pillA = "Sessoes longas"; pillB = "Cortes automaticos"; callTitle = "Gravacao longa sem complicar"; callSub = "Organiza os ficheiros por tempo." },
        @{ headline = "Todas as funcoes sao gratis"; subhead = "Reproduza, marque favoritos, renomeie, apague e partilhe sem bloquear o basico."; pillA = "Gratis"; pillB = "Sem conta"; callTitle = "Os seus audios sempre acessiveis"; callSub = "Reproduza, organize e partilhe." }
    )
    "ca" = @(
        @{ headline = "Opcio: grava quan hi ha so"; subhead = "Tambe pots gravar-ho tot seguit. Activa aquest mode si vols evitar silencis."; pillA = "Mode opcional"; pillB = "Gratis"; callTitle = "Tries com gravar"; callSub = "Tot seguit o nomes quan detecta so." },
        @{ headline = "Grava tot el que necessites"; subhead = "Funciona durant sessions llargues i crea fitxers per intervals per mantenir-ho ordenat."; pillA = "Sessions llargues"; pillB = "Talls automatics"; callTitle = "Gravacio llarga sense complicar"; callSub = "Organitza els fitxers per temps." },
        @{ headline = "Totes les funcions son gratis"; subhead = "Reprodueix, marca preferits, reanomena, elimina i comparteix sense bloquejar el basic."; pillA = "Gratis"; pillB = "Sense compte"; callTitle = "Els teus audios sempre accessibles"; callSub = "Reprodueix, organitza i comparteix." }
    )
}

$ui = @{
    "en-US" = @{
        readyTitle = "Ready"; readySub = "Tap the microphone to start"; recordingTitle = "Recording"; recordingSub = "A new file is created every 30 minutes"
        segment = "Segment"; level = "Level"; status = "Status"; waiting = "Waiting"; saving = "Saving"; quality = "Quality"; high = "High (maximum)"; cut = "Cut"; cutValue = "30 min"; mode = "Mode"; allMode = "All"
        tabs = @("Record", "Files", "Settings"); select = "Select"; files = "Files"; local = "Local"
        dates = @("22 May 2026 at 3:32", "21 May 2026 at 20:36", "21 May 2026 at 20:36", "21 May 2026 at 20:35")
        meta = @("00:07    1.5 MB", "04:04    46.9 MB", "00:03    695 KB", "00:09    1.8 MB")
        modes = @("All", "All", "By sound", "By sound"); qualityFile = "High (maximum)"
        names = @("2026-05-22_03-32-50-888_everything_4257D0...", "2026-05-21_20-36-19-747_everything_D9FEF4...", "2026-05-21_20-36-04-777_soundActivated_A3B...", "2026-05-21_20-35-51-291_soundActivated_2D2...")
    }
    "fr-FR" = @{
        readyTitle = "Pret"; readySub = "Touchez le micro pour demarrer"; recordingTitle = "Enregistrement"; recordingSub = "Un nouveau fichier est cree toutes les 30 minutes"
        segment = "Segment"; level = "Niveau"; status = "Etat"; waiting = "Attente"; saving = "En cours"; quality = "Qualite"; high = "Haute (maximale)"; cut = "Coupe"; cutValue = "30 min"; mode = "Mode"; allMode = "Tout"
        tabs = @("Enreg.", "Fichiers", "Reglages"); select = "Selectionner"; files = "Fichiers"; local = "Local"
        dates = @("22 mai 2026 a 3:32", "21 mai 2026 a 20:36", "21 mai 2026 a 20:36", "21 mai 2026 a 20:35")
        meta = @("00:07    1,5 Mo", "04:04    46,9 Mo", "00:03    695 Ko", "00:09    1,8 Mo")
        modes = @("Tout", "Tout", "Par son", "Par son"); qualityFile = "Haute (max.)"
        names = @("2026-05-22_03-32-50-888_continu_4257D0...", "2026-05-21_20-36-19-747_continu_D9FEF4...", "2026-05-21_20-36-04-777_son_A3B...", "2026-05-21_20-35-51-291_son_2D2...")
    }
    "de-DE" = @{
        readyTitle = "Bereit"; readySub = "Tippe auf das Mikrofon"; recordingTitle = "Aufnahme"; recordingSub = "Alle 30 Minuten wird eine neue Datei erstellt"
        segment = "Segment"; level = "Pegel"; status = "Status"; waiting = "Warten"; saving = "Sichert"; quality = "Qualitaet"; high = "Hoch (maximal)"; cut = "Schnitt"; cutValue = "30 min"; mode = "Modus"; allMode = "Alles"
        tabs = @("Aufnahme", "Dateien", "Einst."); select = "Auswaehlen"; files = "Dateien"; local = "Lokal"
        dates = @("22. Mai 2026 um 3:32", "21. Mai 2026 um 20:36", "21. Mai 2026 um 20:36", "21. Mai 2026 um 20:35")
        meta = @("00:07    1,5 MB", "04:04    46,9 MB", "00:03    695 KB", "00:09    1,8 MB")
        modes = @("Alles", "Alles", "Bei Ton", "Bei Ton"); qualityFile = "Hoch (max.)"
        names = @("2026-05-22_03-32-50-888_durchgehend_4257D0...", "2026-05-21_20-36-19-747_durchgehend_D9FEF4...", "2026-05-21_20-36-04-777_ton_A3B...", "2026-05-21_20-35-51-291_ton_2D2...")
    }
    "it" = @{
        readyTitle = "Pronto"; readySub = "Tocca il microfono per iniziare"; recordingTitle = "Registrazione"; recordingSub = "Viene creato un nuovo file ogni 30 minuti"
        segment = "Segmento"; level = "Livello"; status = "Stato"; waiting = "Attesa"; saving = "Salva"; quality = "Qualita"; high = "Alta (massima)"; cut = "Taglio"; cutValue = "30 min"; mode = "Modo"; allMode = "Tutto"
        tabs = @("Registra", "File", "Impost."); select = "Seleziona"; files = "File"; local = "Locale"
        dates = @("22 mag 2026 alle 3:32", "21 mag 2026 alle 20:36", "21 mag 2026 alle 20:36", "21 mag 2026 alle 20:35")
        meta = @("00:07    1,5 MB", "04:04    46,9 MB", "00:03    695 KB", "00:09    1,8 MB")
        modes = @("Tutto", "Tutto", "Per suono", "Per suono"); qualityFile = "Alta (max.)"
        names = @("2026-05-22_03-32-50-888_tutto_4257D0...", "2026-05-21_20-36-19-747_tutto_D9FEF4...", "2026-05-21_20-36-04-777_suono_A3B...", "2026-05-21_20-35-51-291_suono_2D2...")
    }
    "pt-PT" = @{
        readyTitle = "Pronto"; readySub = "Toque no microfone para comecar"; recordingTitle = "A gravar"; recordingSub = "E criado um ficheiro novo a cada 30 minutos"
        segment = "Segmento"; level = "Nivel"; status = "Estado"; waiting = "Espera"; saving = "A guardar"; quality = "Qualidade"; high = "Alta (maxima)"; cut = "Corte"; cutValue = "30 min"; mode = "Modo"; allMode = "Tudo"
        tabs = @("Gravar", "Ficheiros", "Ajustes"); select = "Selecionar"; files = "Ficheiros"; local = "Local"
        dates = @("22 mai 2026 as 3:32", "21 mai 2026 as 20:36", "21 mai 2026 as 20:36", "21 mai 2026 as 20:35")
        meta = @("00:07    1,5 MB", "04:04    46,9 MB", "00:03    695 KB", "00:09    1,8 MB")
        modes = @("Tudo", "Tudo", "Por som", "Por som"); qualityFile = "Alta (max.)"
        names = @("2026-05-22_03-32-50-888_tudo_4257D0...", "2026-05-21_20-36-19-747_tudo_D9FEF4...", "2026-05-21_20-36-04-777_som_A3B...", "2026-05-21_20-35-51-291_som_2D2...")
    }
    "ca" = @{
        readyTitle = "Preparat"; readySub = "Toca el microfon per comencar"; recordingTitle = "Gravant"; recordingSub = "Es crea un fitxer nou cada 30 minuts"
        segment = "Segment"; level = "Nivell"; status = "Estat"; waiting = "Espera"; saving = "Desant"; quality = "Qualitat"; high = "Alta (maxima)"; cut = "Tall"; cutValue = "30 min"; mode = "Mode"; allMode = "Tot"
        tabs = @("Gravar", "Fitxers", "Ajustos"); select = "Seleccionar"; files = "Fitxers"; local = "Local"
        dates = @("22 maig 2026 a les 3:32", "21 maig 2026 a les 20:36", "21 maig 2026 a les 20:36", "21 maig 2026 a les 20:35")
        meta = @("00:07    1,5 MB", "04:04    46,9 MB", "00:03    695 KB", "00:09    1,8 MB")
        modes = @("Tot", "Tot", "Per so", "Per so"); qualityFile = "Alta (max.)"
        names = @("2026-05-22_03-32-50-888_tot_4257D0...", "2026-05-21_20-36-19-747_tot_D9FEF4...", "2026-05-21_20-36-04-777_so_A3B...", "2026-05-21_20-35-51-291_so_2D2...")
    }
}

foreach ($locale in $copy.Keys) {
    $dir = Join-Path $storeDir "$locale\iphone-67"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    for ($i = 0; $i -lt $templates.Count; $i++) {
        $templatePath = Join-Path $root $templates[$i].Template
        $dest = Join-Path $dir $templates[$i].File
        New-LocalizedShot $templatePath $dest $copy[$locale][$i] $ui[$locale] $templates[$i].Kind
        Write-Host "$locale $($templates[$i].File)"
    }
}
