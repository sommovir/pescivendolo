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
  static const String underwaterSoundFile = '774918__klankbeeld__backswimmer-under-water-134-pm-220725_0457.wav';
  
  // Nome del file per il suono quando il pesce viene ferito
  static const String hurtSoundFile = 'hai_hai.m4a';
  
  // Nome del file per il suono quando il pesce mangia
  static const String eatSoundFile = 'gulp.mp3';
  
  // Nome del file per la musica di sottofondo
  static const String musicFile = 'music.wav';
  
  // Durata approssimativa del file musicale in secondi
  // Questo valore deve essere regolato in base alla durata effettiva del file
  static const int musicDurationSeconds = 60;
  
  // Flag per indicare quali suoni sono disponibili
  static bool _eatSoundAvailable = false;
  static bool _hurtSoundAvailable = false;
  static bool _musicAvailable = false;
  static bool _ambientSoundAvailable = false;
  
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
      
      _initialized = true;
      developer.log('AudioManager: inizializzazione completata. Suoni disponibili: '
          'music=$_musicAvailable, ambient=$_ambientSoundAvailable, '
          'hurt=$_hurtSoundAvailable, eat=$_eatSoundAvailable');
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
    if (_bgmPlaying || !_musicAvailable) {
      developer.log('AudioManager: playBackgroundMusic - già in riproduzione o non disponibile. '
          'bgmPlaying=$_bgmPlaying, musicAvailable=$_musicAvailable');
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
  
  // Riproduci suono ambientale
  static void playAmbientSound() {
    if (_ambientPlaying || !_ambientSoundAvailable) {
      developer.log('AudioManager: playAmbientSound - già in riproduzione o non disponibile. '
          'ambientPlaying=$_ambientPlaying, ambientSoundAvailable=$_ambientSoundAvailable');
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
      
      developer.log('AudioManager: riproduzione suono ferito');
      // Nella versione attuale di flame_audio, non possiamo usare startAt
      // Riproduciamo il file così com'è
      FlameAudio.play(hurtSoundFile);
      developer.log('AudioManager: suono ferito riprodotto con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playHurtSound: $e\n$stackTrace');
    }
  }
  
  // Ferma tutta la musica e i suoni
  static void stopAll() {
    try {
      developer.log('AudioManager: arresto di tutti i suoni');
      // Non possiamo fermare i suoni riprodotti con FlameAudio.play
      // ma possiamo impostare i flag per evitare di riprodurli di nuovo
      _bgmPlaying = false;
      _ambientPlaying = false;
      
      // Fermiamo il timer per il loop della musica
      _musicLoopTimer?.cancel();
      _musicLoopTimer = null;
      
      developer.log('AudioManager: flag di riproduzione reimpostati');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.stopAll: $e\n$stackTrace');
    }
  }
}
