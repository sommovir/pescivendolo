# Pescivendolo - L'avventura sottomarina

Un gioco 2D sviluppato con Flutter e il framework Flame, dove controlli un pesce arancione che deve mangiare pesci verdi (sicuri) ed evitare pesci rossi (pericolosi).

![Screenshot del gioco](screenshot.png)

## Come giocare

- **Controlli**: Usa i tasti WASD o le frecce direzionali per muovere il pesciolino
- **Obiettivo**: Mangia i pesci verdi per aumentare il tuo punteggio
- **Pericoli**: Evita i pesci rossi e altri che ti toglieranno una vita
- **Vite**: Hai 3 vite per completare la partita

## Caratteristiche

- Grafica semplice ma accattivante con effetti subacquei
- Effetti sonori e musica di sottofondo
- Sistema di punteggio e vite
- Interfaccia utente intuitiva
- Animazioni fluide

## Tecnologie utilizzate

- [Flutter](https://flutter.dev)
- [Flame Game Engine](https://flame-engine.org)
- [Flame Audio](https://pub.dev/packages/flame_audio)
- [Animated Text Kit](https://pub.dev/packages/animated_text_kit)
- [Flutter Animate](https://pub.dev/packages/flutter_animate)

## Sviluppo

### Prerequisiti

- Flutter SDK (versione 3.x o superiore)
- Editor di codice (VS Code, Android Studio, ecc.)

### Installazione

1. Clona questo repository
2. Esegui `flutter pub get` per installare le dipendenze
3. Esegui `flutter run` per avviare il gioco in modalità debug

### Build per il web

```
flutter build web --release
```

## Deployment

Il gioco è configurato per essere facilmente pubblicato su GitHub Pages utilizzando il workflow incluso.

1. Effettua il push del codice su GitHub
2. Nella sezione "Settings" del repository, vai a "Pages"
3. Configura il source come "GitHub Actions"
4. Il gioco sarà automaticamente deployato ad ogni push sul branch principale

## Crediti

- Effetti sonori: vari autori (vedi licenze nella cartella assets)
- Grafica: creata come SVG
