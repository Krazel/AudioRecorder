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
    Add-Text $g $copy.callTitle 166 2394 930 40 (New-Font 38 "Bold") $Ink
    Add-Text $g $copy.callSub 166 2437 930 34 (New-Font 28) $Muted
}

function New-LocalizedShot($template, $dest, $copy, $kind) {
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
    Add-Text $g $copy.subhead 78 328 1010 112 (New-Font 40) $Muted

    $pill1Color = if ($kind -eq "recording") { $Red } elseif ($kind -eq "free") { $Blue } else { $Green }
    $pill1Fill = if ($kind -eq "recording") { $SoftRed } elseif ($kind -eq "free") { $SoftBlue } else { $SoftGreen }
    $pill2Color = if ($kind -eq "free") { $Green } else { $Blue }
    $pill2Fill = if ($kind -eq "free") { $SoftGreen } else { $SoftBlue }
    $w1 = Add-Pill $g $copy.pillA 76 530 $pill1Fill $pill1Color
    [void](Add-Pill $g $copy.pillB (76 + $w1 + 18) 530 $pill2Fill $pill2Color)

    $soft = if ($kind -eq "recording") { $SoftRed } elseif ($kind -eq "free") { $SoftBlue } else { $SoftGreen }
    Add-Callout $g $copy $soft

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

foreach ($locale in $copy.Keys) {
    $dir = Join-Path $storeDir "$locale\iphone-67"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    for ($i = 0; $i -lt $templates.Count; $i++) {
        $templatePath = Join-Path $root $templates[$i].Template
        $dest = Join-Path $dir $templates[$i].File
        New-LocalizedShot $templatePath $dest $copy[$locale][$i] $templates[$i].Kind
        Write-Host "$locale $($templates[$i].File)"
    }
}
