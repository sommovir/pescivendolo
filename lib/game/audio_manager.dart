import 'package:flame_audio/flame_audio.dart';
import 'dart:developer' as developer;
import 'dart:async';

class AudioManager {
  static bool _initialized = false;
  static bool _bgmPlaying = false;
  static bool _ambientPlaying = false;
  
  // Flag per indicare se l'utente ha interagito con la pagina
  // Necessario per i browser web che richiedono un'interazione utente
  // prima di riprodurre l'audio
  static bool _userInteracted = false;
  
  // Timer per il loop della musica
  static Timer? _musicLoopTimer;
  
  // Nome del file per il suono ambientale subacqueo
  static const String underwaterSoundFile = '774918__klankbeeld__backswimmer-under-water-134-pm-220725_0457.mp3';
  
  // Nome del file per il suono quando il pesce viene ferito
  static const String hurtSoundFile = 'hai_hai.m4a';
  
  // Nome del file per il suono quando il pesce mangia
  static const String eatSoundFile = 'gulp.mp3';
  
  // Nome del file per la musica di sottofondo
  static const String musicFile = 'music.wav';
  
  // Nome del file per il suono della scarica elettrica
  static const String electroShockFile = 'electro_shock.wav';
  
  // Durata approssimativa del file musicale in secondi
  // Questo valore deve essere regolato in base alla durata effettiva del file
  static const int musicDurationSeconds = 60;
  
  // Flag per indicare quali suoni sono disponibili
  static bool _eatSoundAvailable = false;
  static bool _hurtSoundAvailable = false;
  static bool _musicAvailable = false;
  static bool _ambientSoundAvailable = false;
  static bool _electroShockAvailable = false;
  
  // Variabili per limitare la riproduzione troppo frequente
  static DateTime _lastEatSound = DateTime.now().subtract(const Duration(seconds: 1));
  static DateTime _lastHurtSound = DateTime.now().subtract(const Duration(seconds: 1));
  static DateTime _lastEffectSound = DateTime.now().subtract(const Duration(seconds: 1));
  static const Duration _minSoundInterval = Duration(milliseconds: 100);
  
  // Inizializza l'audio manager
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      developer.log('AudioManager: inizializzazione');
      
      // Verifica che l'audio cache sia inizializzato
      developer.log('AudioManager: verifica audio cache');
      if (FlameAudio.audioCache == null) {
        developer.log('AudioManager: ERRORE - audioCache è null');
        return;
      }
      
      // Log dei percorsi di ricerca dell'audio cache
      developer.log('AudioManager: percorsi di ricerca audio cache: ${FlameAudio.audioCache.prefix}');
      
      // Precarica gli effetti sonori individualmente per catturare eventuali errori
      try {
        developer.log('AudioManager: caricamento musicFile: $musicFile');
        await FlameAudio.audioCache.load(musicFile);
        _musicAvailable = true;
        developer.log('AudioManager: musicFile caricato con successo');
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento musicFile: $e\n$stackTrace');
      }
      
      try {
        developer.log('AudioManager: caricamento underwaterSoundFile: $underwaterSoundFile');
        await FlameAudio.audioCache.load(underwaterSoundFile);
        _ambientSoundAvailable = true;
        developer.log('AudioManager: underwaterSoundFile caricato con successo');
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento underwaterSoundFile: $e\n$stackTrace');
      }
      
      try {
        developer.log('AudioManager: caricamento hurtSoundFile: $hurtSoundFile');
        await FlameAudio.audioCache.load(hurtSoundFile);
        _hurtSoundAvailable = true;
        developer.log('AudioManager: hurtSoundFile caricato con successo');
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento hurtSoundFile: $e\n$stackTrace');
      }
      
      try {
        developer.log('AudioManager: caricamento eatSoundFile: $eatSoundFile');
        await FlameAudio.audioCache.load(eatSoundFile);
        _eatSoundAvailable = true;
        developer.log('AudioManager: eatSoundFile caricato con successo');
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento eatSoundFile: $e\n$stackTrace');
      }
      
      try {
        developer.log('AudioManager: caricamento electroShockFile: $electroShockFile');
        await FlameAudio.audioCache.load(electroShockFile);
        _electroShockAvailable = true;
        developer.log('AudioManager: electroShockFile caricato con successo');
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento electroShockFile: $e\n$stackTrace');
      }
      
      _initialized = true;
      developer.log('AudioManager: inizializzazione completata. Suoni disponibili: '
          'music=$_musicAvailable, ambient=$_ambientSoundAvailable, '
          'hurt=$_hurtSoundAvailable, eat=$_eatSoundAvailable, electroShock=$_electroShockAvailable');
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.initialize: $e\n$stackTrace');
    }
  }
  
  // Imposta il flag di interazione utente
  // Chiamare questo metodo quando l'utente interagisce con la pagina
  static void setUserInteracted() {
    if (!_userInteracted) {
      developer.log('AudioManager: utente ha interagito con la pagina');
      _userInteracted = true;
      
      // Se l'audio è stato inizializzato ma non è ancora stato riprodotto,
      // proviamo a riprodurlo ora che l'utente ha interagito
      if (_initialized && !_bgmPlaying && _musicAvailable) {
        developer.log('AudioManager: tentativo di riprodurre musica dopo interazione utente');
        playBackgroundMusic();
      }
      
      if (_initialized && !_ambientPlaying && _ambientSoundAvailable) {
        developer.log('AudioManager: tentativo di riprodurre suono ambientale dopo interazione utente');
        playAmbientSound();
      }
    }
  }
  
  // Riproduci musica di sottofondo in loop
  static void playBackgroundMusic() {
    // Assicurati che eventuali musiche precedenti siano fermate
    stopBackgroundMusic();
    
    if (!_musicAvailable) {
      developer.log('AudioManager: playBackgroundMusic - musica non disponibile');
      return;
    }
    
    try {
      developer.log('AudioManager: avvio musica di sottofondo');
      
      // Nei browser web, l'audio può essere riprodotto solo dopo un'interazione dell'utente
      if (!_userInteracted) {
        developer.log('AudioManager: impossibile riprodurre musica, utente non ha ancora interagito con la pagina');
        return;
      }
      
      // Utilizziamo FlameAudio.play invece di FlameAudio.bgm.play
      // Questo metodo funziona meglio in Flutter Web
      FlameAudio.play(musicFile, volume: 0.5);
      developer.log('AudioManager: musica di sottofondo avviata con successo');
      _bgmPlaying = true;
      
      // Imposta un timer per riprodurre la musica in loop
      // Cancelliamo eventuali timer esistenti
      _musicLoopTimer?.cancel();
      
      // Creiamo un nuovo timer che riproduce la musica ogni musicDurationSeconds
      _musicLoopTimer = Timer.periodic(Duration(seconds: musicDurationSeconds - 1), (timer) {
        if (_bgmPlaying && _userInteracted) {
          developer.log('AudioManager: riavvio musica di sottofondo (loop)');
          FlameAudio.play(musicFile, volume: 0.5);
        } else {
          // Se la musica è stata fermata, fermiamo anche il timer
          timer.cancel();
          _musicLoopTimer = null;
        }
      });
      
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playBackgroundMusic: $e\n$stackTrace');
    }
  }
  
  // Ferma la musica di sottofondo
  static void stopBackgroundMusic() {
    if (_bgmPlaying) {
      developer.log('AudioManager: arresto musica di sottofondo');
      _bgmPlaying = false;
      
      // Ferma il timer per il loop della musica
      _musicLoopTimer?.cancel();
      _musicLoopTimer = null;
      
      // In Flame Audio non c'è un modo diretto per fermare un audio in riproduzione
      // ma possiamo impostare il flag a false per evitare che venga riprodotto di nuovo
      developer.log('AudioManager: musica di sottofondo fermata');
    }
  }
  
  // Riproduci suono ambientale
  static void playAmbientSound() {
    // Assicurati che eventuali suoni ambientali precedenti siano fermati
    stopAmbientSound();
    
    if (!_ambientSoundAvailable) {
      developer.log('AudioManager: playAmbientSound - suono non disponibile');
      return;
    }
    
    try {
      developer.log('AudioManager: avvio suono ambientale');
      
      // Nei browser web, l'audio può essere riprodotto solo dopo un'interazione dell'utente
      if (!_userInteracted) {
        developer.log('AudioManager: impossibile riprodurre suono ambientale, utente non ha ancora interagito con la pagina');
        return;
      }
      
      // Utilizziamo FlameAudio.play invece di FlameAudio.bgm.play
      // Questo metodo funziona meglio in Flutter Web
      FlameAudio.play(underwaterSoundFile, volume: 0.3);
      developer.log('AudioManager: suono ambientale avviato con successo');
      _ambientPlaying = true;
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playAmbientSound: $e\n$stackTrace');
    }
  }
  
  // Ferma il suono ambientale
  static void stopAmbientSound() {
    if (_ambientPlaying) {
      developer.log('AudioManager: arresto suono ambientale');
      _ambientPlaying = false;
      
      // In Flame Audio non c'è un modo diretto per fermare un audio in riproduzione
      // ma possiamo impostare il flag a false per evitare che venga riprodotto di nuovo
      developer.log('AudioManager: suono ambientale fermato');
    }
  }
  
  // Riproduci suono quando mangia un pesce
  static void playEatSound() {
    if (!_eatSoundAvailable) {
      developer.log('AudioManager: playEatSound - suono non disponibile');
      return;
    }
    
    try {
      // Nei browser web, l'audio può essere riprodotto solo dopo un'interazione dell'utente
      if (!_userInteracted) {
        developer.log('AudioManager: impossibile riprodurre suono mangia, utente non ha ancora interagito con la pagina');
        return;
      }
      
      // Limita la frequenza di riproduzione per evitare overflow
      final now = DateTime.now();
      if (now.difference(_lastEatSound) < _minSoundInterval) {
        developer.log('AudioManager: riproduzione suono mangia troppo frequente, ignorata');
        return;
      }
      _lastEatSound = now;
      
      developer.log('AudioManager: riproduzione suono mangia');
      FlameAudio.play(eatSoundFile);
      developer.log('AudioManager: suono mangia riprodotto con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playEatSound: $e\n$stackTrace');
    }
  }
  
  // Riproduci suono quando viene ferito
  static void playHurtSound() {
    if (!_hurtSoundAvailable) {
      developer.log('AudioManager: playHurtSound - suono non disponibile');
      return;
    }
    
    try {
      // Nei browser web, l'audio può essere riprodotto solo dopo un'interazione dell'utente
      if (!_userInteracted) {
        developer.log('AudioManager: impossibile riprodurre suono ferito, utente non ha ancora interagito con la pagina');
        return;
      }
      
      // Limita la frequenza di riproduzione per evitare overflow
      final now = DateTime.now();
      if (now.difference(_lastHurtSound) < _minSoundInterval) {
        developer.log('AudioManager: riproduzione suono ferito troppo frequente, ignorata');
        return;
      }
      _lastHurtSound = now;
      
      developer.log('AudioManager: riproduzione suono ferito');
      // Nella versione attuale di flame_audio, non possiamo usare startAt
      // Riproduciamo il file così com'è
      FlameAudio.play(hurtSoundFile);
      developer.log('AudioManager: suono ferito riprodotto con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playHurtSound: $e\n$stackTrace');
    }
  }
  
  // Riproduci un effetto sonoro generico
  static void playSoundEffect(String fileName, {double volume = 1.0}) {
    try {
      // Nei browser web, l'audio può essere riprodotto solo dopo un'interazione dell'utente
      if (!_userInteracted) {
        developer.log('AudioManager: impossibile riprodurre l\'effetto sonoro $fileName, utente non ha ancora interagito con la pagina');
        return;
      }
      
      // Limita la frequenza di riproduzione per evitare overflow
      final now = DateTime.now();
      if (now.difference(_lastEffectSound) < _minSoundInterval) {
        developer.log('AudioManager: riproduzione effetto sonoro troppo frequente, ignorata');
        return;
      }
      _lastEffectSound = now;
      
      developer.log('AudioManager: riproduzione effetto sonoro $fileName');
      FlameAudio.play(fileName, volume: volume);
      developer.log('AudioManager: effetto sonoro riprodotto con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playSoundEffect: $e\n$stackTrace');
    }
  }
  
  // Ferma tutta la musica e i suoni in modo più deciso
  static void stopAll() {
    try {
      developer.log('AudioManager: arresto completo di tutti i suoni');
      
      // Ferma la musica di sottofondo
      _bgmPlaying = false;
      
      // Ferma il suono ambientale
      _ambientPlaying = false;
      
      // Ferma il timer per il loop della musica
      _musicLoopTimer?.cancel();
      _musicLoopTimer = null;
      
      // In Flame Audio non c'è un modo diretto per fermare un audio in riproduzione
      // Tentiamo di accedere all'audio pool e svuotarlo
      try {
        // Rimuoviamo gli audio dal cache per forzare il ricaricamento
        FlameAudio.audioCache.clearAll();
        developer.log('AudioManager: audio cache svuotata con successo');
      } catch (e) {
        developer.log('AudioManager: errore durante lo svuotamento della cache: $e');
      }
      
      developer.log('AudioManager: tutti i suoni fermati con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.stopAll: $e\n$stackTrace');
    }
  }
}
