# Script PowerShell per il deploy su GitHub Pages
Write-Host "Avvio del processo di deploy su GitHub Pages..." -ForegroundColor Cyan

# 1. Controllo se ci sono modifiche non committate
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "Ci sono modifiche non committate nel repository. Committa o stasha le modifiche prima di procedere." -ForegroundColor Red
    Write-Host $gitStatus
    exit 1
}

# 2. Salva il branch corrente
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Branch corrente: $currentBranch" -ForegroundColor Cyan

# 3. Assicurati che siamo sul branch master
if ($currentBranch -ne "master") {
    Write-Host "Cambio al branch master..." -ForegroundColor Yellow
    git checkout master
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Errore nel cambio a master. Uscita." -ForegroundColor Red
        exit 1
    }
}

# 4. Pull delle ultime modifiche
Write-Host "Pull delle ultime modifiche da origin/master..." -ForegroundColor Cyan
git pull origin master
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore nel pull da origin/master. Continuo comunque..." -ForegroundColor Yellow
}

# 5. Esegui flutter build web
Write-Host "Esecuzione di flutter build web..." -ForegroundColor Cyan
flutter build web --release --base-href /pescivendolo/
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore nella build web. Uscita." -ForegroundColor Red
    exit 1
}

# 6. Copia i file della build in una cartella temporanea
Write-Host "Salvataggio dei file della build..." -ForegroundColor Cyan
$tempDir = New-Item -Path ".\temp-build" -ItemType Directory -Force
Copy-Item -Path ".\build\web\*" -Destination $tempDir.FullName -Recurse -Force

# 7. Cambia al branch gh-pages
Write-Host "Cambio al branch gh-pages..." -ForegroundColor Yellow
git checkout gh-pages
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore nel cambio a gh-pages. Uscita." -ForegroundColor Red
    # Torna al branch originale
    git checkout $currentBranch
    exit 1
}

# 8. Rimuovi i file vecchi (tranne .git)
Write-Host "Rimozione dei file vecchi..." -ForegroundColor Cyan
Get-ChildItem -Path "." -Exclude @(".git", "temp-build") | Remove-Item -Recurse -Force

# 9. Copia i nuovi file
Write-Host "Copia dei nuovi file..." -ForegroundColor Cyan
Copy-Item -Path "$tempDir\*" -Destination "." -Recurse -Force

# 10. Aggiungi il file .nojekyll se non esiste
if (-not (Test-Path ".nojekyll")) {
    New-Item -Path ".nojekyll" -ItemType File -Force | Out-Null
    Write-Host "File .nojekyll creato" -ForegroundColor Green
}

# 11. Aggiungi tutti i file per il commit
Write-Host "Aggiunta dei file per il commit..." -ForegroundColor Cyan
git add -A
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore nell'aggiungere i file. Uscita." -ForegroundColor Red
    # Torna al branch originale
    git checkout $currentBranch
    exit 1
}

# 12. Commit delle modifiche
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Commit delle modifiche..." -ForegroundColor Cyan
git commit -m "Deploy automatico: $timestamp"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore nel commit. Uscita." -ForegroundColor Red
    # Torna al branch originale
    git checkout $currentBranch
    exit 1
}

# 13. Push al branch gh-pages
Write-Host "Push delle modifiche a gh-pages..." -ForegroundColor Cyan
git push origin gh-pages
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore nel push a gh-pages. Uscita." -ForegroundColor Red
    # Torna al branch originale
    git checkout $currentBranch
    exit 1
}

# 14. Torna al branch originale
Write-Host "Ritorno al branch originale: $currentBranch" -ForegroundColor Yellow
git checkout $currentBranch
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore nel tornare al branch originale. Controlla lo stato del repository." -ForegroundColor Red
    exit 1
}

# 15. Rimuovi la cartella temporanea
Write-Host "Pulizia dei file temporanei..." -ForegroundColor Cyan
Remove-Item -Path $tempDir.FullName -Recurse -Force

Write-Host "Deploy completato con successo! Il sito è ora disponibile su https://sommovir.github.io/pescivendolo/" -ForegroundColor Green
