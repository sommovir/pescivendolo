import 'package:flame_audio/flame_audio.dart';
import 'dart:developer' as developer;
import 'dart:html' as html;

class AudioManager {
  static bool _initialized = false;

  // Volume di musica e ambientale, regolabili dall'utente e persistiti tra
  // una sessione e l'altra. L'ambientale parte basso perché la registrazione
  // subacquea ha un rumore di fondo molto presente.
  static const String _musicVolumeKey = 'pescivendolo_music_volume';
  static const String _ambientVolumeKey = 'pescivendolo_ambient_volume';
  static double _musicVolume = 0.5;
  static double _ambientVolume = 0.03;
  static bool _volumeLoaded = false;

  static void _ensureVolumeLoaded() {
    if (_volumeLoaded) return;
    _volumeLoaded = true;
    try {
      final storedMusic = html.window.localStorage[_musicVolumeKey];
      final storedAmbient = html.window.localStorage[_ambientVolumeKey];
      if (storedMusic != null) _musicVolume = double.tryParse(storedMusic) ?? _musicVolume;
      if (storedAmbient != null) _ambientVolume = double.tryParse(storedAmbient) ?? _ambientVolume;
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager._ensureVolumeLoaded: $e\n$stackTrace');
    }
  }

  static double get musicVolume {
    _ensureVolumeLoaded();
    return _musicVolume;
  }

  static double get ambientVolume {
    _ensureVolumeLoaded();
    return _ambientVolume;
  }

  // Aggiorna il volume della musica, applicandolo subito se sta suonando e
  // persistendolo per le prossime sessioni.
  static Future<void> setMusicVolume(double volume) async {
    _ensureVolumeLoaded();
    _musicVolume = volume.clamp(0.0, 1.0);
    try {
      html.window.localStorage[_musicVolumeKey] = _musicVolume.toString();
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.setMusicVolume (salvataggio): $e\n$stackTrace');
    }
    try {
      if (FlameAudio.bgm.isPlaying) {
        await FlameAudio.bgm.audioPlayer.setVolume(_musicVolume);
      }
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.setMusicVolume: $e\n$stackTrace');
    }
  }

  // Aggiorna il volume dell'ambientale, applicandolo subito se sta suonando
  // e persistendolo per le prossime sessioni.
  static Future<void> setAmbientVolume(double volume) async {
    _ensureVolumeLoaded();
    _ambientVolume = volume.clamp(0.0, 1.0);
    try {
      html.window.localStorage[_ambientVolumeKey] = _ambientVolume.toString();
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.setAmbientVolume (salvataggio): $e\n$stackTrace');
    }
    try {
      await _ambientPlayer?.setVolume(_ambientVolume);
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.setAmbientVolume: $e\n$stackTrace');
    }
  }

  // Flag per indicare se l'utente ha interagito con la pagina
  // Necessario per i browser web che richiedono un'interazione utente
  // prima di riprodurre l'audio
  static bool _userInteracted = false;

  // Player dedicato al suono ambientale subacqueo, in loop.
  // Diversamente dalla musica (che usa FlameAudio.bgm), questo è un secondo
  // loop indipendente che suona in parallelo, quindi ha bisogno del proprio
  // AudioPlayer per poter essere davvero fermato/messo in pausa.
  static AudioPlayer? _ambientPlayer;

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

  // Nome del file per il suono dello scudo di invulnerabilità
  static const String shieldSoundFile = 'shield.mp3';

  // Nome del file per il suono di raccolta di monetine e tesori normali
  static const String coinSoundFile = 'coin.mp3';

  // Nome del file per il suono di raccolta del tesoro massimo (tier 3)
  static const String bigTreasureSoundFile = 'tesorone.mp3';

  // Nome del file per il suono di Marmo Carpa quando mangia/distrugge qualcosa
  static const String marmoMagnaSoundFile = 'marmoMagna.mp3';

  // Flag per indicare quali suoni sono disponibili
  static bool _eatSoundAvailable = false;
  static bool _hurtSoundAvailable = false;
  static bool _musicAvailable = false;
  static bool _ambientSoundAvailable = false;
  static bool _electroShockAvailable = false;
  static bool _shieldSoundAvailable = false;
  static bool _coinSoundAvailable = false;
  static bool _bigTreasureSoundAvailable = false;
  static bool _marmoMagnaSoundAvailable = false;

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

      // Bgm è il player dedicato di flame_audio per la musica di sottofondo:
      // gestisce da solo release+loop+volume ad ogni play(), quindi non serve
      // più nessun timer per "ravvivare" il loop manualmente.
      await FlameAudio.bgm.initialize();

      // Precarica gli effetti sonori individualmente per catturare eventuali errori
      try {
        await FlameAudio.audioCache.load(musicFile);
        _musicAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento musicFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(underwaterSoundFile);
        _ambientSoundAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento underwaterSoundFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(hurtSoundFile);
        _hurtSoundAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento hurtSoundFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(eatSoundFile);
        _eatSoundAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento eatSoundFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(electroShockFile);
        _electroShockAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento electroShockFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(shieldSoundFile);
        _shieldSoundAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento shieldSoundFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(coinSoundFile);
        _coinSoundAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento coinSoundFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(bigTreasureSoundFile);
        _bigTreasureSoundAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento bigTreasureSoundFile: $e\n$stackTrace');
      }

      try {
        await FlameAudio.audioCache.load(marmoMagnaSoundFile);
        _marmoMagnaSoundAvailable = true;
      } catch (e, stackTrace) {
        developer.log('AudioManager: ERRORE caricamento marmoMagnaSoundFile: $e\n$stackTrace');
      }

      _initialized = true;
      developer.log('AudioManager: inizializzazione completata. Suoni disponibili: '
          'music=$_musicAvailable, ambient=$_ambientSoundAvailable, '
          'hurt=$_hurtSoundAvailable, eat=$_eatSoundAvailable, electroShock=$_electroShockAvailable, shield=$_shieldSoundAvailable');
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
      if (_initialized && !FlameAudio.bgm.isPlaying && _musicAvailable) {
        playBackgroundMusic();
      }

      if (_initialized && _ambientPlayer == null && _ambientSoundAvailable) {
        playAmbientSound();
      }
    }
  }

  // Riproduci musica di sottofondo in loop.
  //
  // FlameAudio.bgm.play() è sicuro da chiamare anche se una traccia è già in
  // riproduzione: rilascia da sola il player precedente prima di far partire
  // il nuovo giro, quindi non può più sovrapporsi a se stessa né "ripartire"
  // per via di una stima sbagliata della durata del file.
  static Future<void> playBackgroundMusic() async {
    if (!_musicAvailable) {
      developer.log('AudioManager: playBackgroundMusic - musica non disponibile');
      return;
    }
    if (!_userInteracted) {
      developer.log('AudioManager: impossibile riprodurre musica, utente non ha ancora interagito con la pagina');
      return;
    }

    try {
      await FlameAudio.bgm.play(musicFile, volume: musicVolume);
      developer.log('AudioManager: musica di sottofondo avviata con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playBackgroundMusic: $e\n$stackTrace');
    }
  }

  // Ferma la musica di sottofondo
  static Future<void> stopBackgroundMusic() async {
    try {
      await FlameAudio.bgm.stop();
      developer.log('AudioManager: musica di sottofondo fermata');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.stopBackgroundMusic: $e\n$stackTrace');
    }
  }

  // Riproduci suono ambientale in loop (usa un AudioPlayer dedicato, separato
  // dalla musica, così i due loop non si mischiano e possono essere fermati
  // indipendentemente).
  static Future<void> playAmbientSound() async {
    if (!_ambientSoundAvailable) {
      developer.log('AudioManager: playAmbientSound - suono non disponibile');
      return;
    }
    if (!_userInteracted) {
      developer.log('AudioManager: impossibile riprodurre suono ambientale, utente non ha ancora interagito con la pagina');
      return;
    }

    try {
      // Ferma ed elimina un eventuale player ambientale precedente prima di
      // crearne uno nuovo, per evitare due loop sovrapposti.
      await _ambientPlayer?.stop();
      await _ambientPlayer?.dispose();
      // Volume regolabile dall'utente (vedi setAmbientVolume): la
      // registrazione subacquea ha un rumore di fondo molto presente.
      _ambientPlayer = await FlameAudio.loop(underwaterSoundFile, volume: ambientVolume);
      developer.log('AudioManager: suono ambientale avviato con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playAmbientSound: $e\n$stackTrace');
    }
  }

  // Ferma il suono ambientale
  static Future<void> stopAmbientSound() async {
    try {
      final player = _ambientPlayer;
      _ambientPlayer = null;
      await player?.stop();
      await player?.dispose();
      developer.log('AudioManager: suono ambientale fermato');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.stopAmbientSound: $e\n$stackTrace');
    }
  }

  // Mette in pausa musica e suono ambientale (usato dal pulsante di pausa),
  // senza fermarli/rilasciarli: resume() li riprende esattamente da dove
  // erano rimasti.
  static Future<void> pauseAll() async {
    try {
      if (FlameAudio.bgm.isPlaying) {
        await FlameAudio.bgm.pause();
      }
      await _ambientPlayer?.pause();
      developer.log('AudioManager: audio messo in pausa');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.pauseAll: $e\n$stackTrace');
    }
  }

  // Riprende musica e suono ambientale dopo pauseAll()
  static Future<void> resumeAll() async {
    try {
      if (_musicAvailable && _userInteracted) {
        await FlameAudio.bgm.resume();
      }
      if (_ambientPlayer != null) {
        await _ambientPlayer!.resume();
      }
      developer.log('AudioManager: audio ripreso');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.resumeAll: $e\n$stackTrace');
    }
  }

  // Riproduci suono quando mangia un pesce
  //
  // NOTA: questi one-shot devono essere `async` + `await`ati dentro il
  // proprio try/catch. Chiamare FlameAudio.play() senza await lo rende un
  // Future non gestito: se il browser interrompe la riproduzione (es.
  // AbortError "interrupted by a call to pause()", frequente quando molti
  // suoni brevi si sovrappongono), l'eccezione non viene catturata da un
  // try/catch sincrono e risulta in un'eccezione non gestita che può
  // bloccare il resto del gioco.
  static Future<void> playEatSound() async {
    if (!_eatSoundAvailable) return;
    if (!_userInteracted) return;

    final now = DateTime.now();
    if (now.difference(_lastEatSound) < _minSoundInterval) return;
    _lastEatSound = now;

    try {
      await FlameAudio.play(eatSoundFile);
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playEatSound: $e\n$stackTrace');
    }
  }

  // Riproduci suono quando si raccoglie una monetina o un tesoro normale
  static Future<void> playCoinSound() async {
    if (!_coinSoundAvailable) return;
    if (!_userInteracted) return;

    try {
      await FlameAudio.play(coinSoundFile);
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playCoinSound: $e\n$stackTrace');
    }
  }

  // Riproduci suono quando si raccoglie il tesoro massimo (tier 3)
  static Future<void> playBigTreasureSound() async {
    if (!_bigTreasureSoundAvailable) return;
    if (!_userInteracted) return;

    try {
      await FlameAudio.play(bigTreasureSoundFile);
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playBigTreasureSound: $e\n$stackTrace');
    }
  }

  static DateTime _lastMarmoMagnaSound = DateTime.now().subtract(const Duration(seconds: 1));

  // Riproduci suono quando Marmo Carpa mangia/distrugge qualcosa.
  // Con un piccolo throttle: mangiando più cose quasi nello stesso istante
  // (es. l'attacco terra) altrimenti si sovrapporrebbero decine di copie
  // dello stesso suono.
  static Future<void> playMarmoMagnaSound() async {
    if (!_marmoMagnaSoundAvailable) return;
    if (!_userInteracted) return;

    final now = DateTime.now();
    if (now.difference(_lastMarmoMagnaSound) < _minSoundInterval) return;
    _lastMarmoMagnaSound = now;

    try {
      await FlameAudio.play(marmoMagnaSoundFile);
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playMarmoMagnaSound: $e\n$stackTrace');
    }
  }

  // Riproduci suono quando viene ferito
  static Future<void> playHurtSound() async {
    if (!_hurtSoundAvailable) return;
    if (!_userInteracted) return;

    final now = DateTime.now();
    if (now.difference(_lastHurtSound) < _minSoundInterval) return;
    _lastHurtSound = now;

    try {
      await FlameAudio.play(hurtSoundFile);
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playHurtSound: $e\n$stackTrace');
    }
  }

  // Riproduci un effetto sonoro generico
  static Future<void> playSoundEffect(String fileName, {double volume = 1.0}) async {
    if (!_userInteracted) return;

    final now = DateTime.now();
    if (now.difference(_lastEffectSound) < _minSoundInterval) return;
    _lastEffectSound = now;

    try {
      await FlameAudio.play(fileName, volume: volume);
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playSoundEffect: $e\n$stackTrace');
    }
  }

  // shield.mp3 dura molto più a lungo (~50s) della durata effettiva dello
  // scudo (10s): senza tenere un riferimento al player non c'è modo di
  // fermarlo quando l'invulnerabilità termina, e continua a suonare per
  // conto suo. Teniamo quindi il player per poterlo fermare esplicitamente.
  static AudioPlayer? _shieldPlayer;

  // Metodo specifico per riprodurre il suono dello scudo
  static Future<void> playShieldSound() async {
    if (!_shieldSoundAvailable) return;
    if (!_userInteracted) return;

    try {
      await _shieldPlayer?.stop();
      await _shieldPlayer?.dispose();
      _shieldPlayer = await FlameAudio.play(shieldSoundFile, volume: 1.0);
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.playShieldSound: $e\n$stackTrace');
    }
  }

  // Ferma il suono dello scudo, chiamato quando l'invulnerabilità termina.
  static Future<void> stopShieldSound() async {
    try {
      final player = _shieldPlayer;
      _shieldPlayer = null;
      await player?.stop();
      await player?.dispose();
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.stopShieldSound: $e\n$stackTrace');
    }
  }

  // Ferma musica e suono ambientale (es. su reset/restart del gioco)
  static Future<void> stopAll() async {
    try {
      await stopBackgroundMusic();
      await stopAmbientSound();
      await stopShieldSound();
      developer.log('AudioManager: tutti i suoni fermati con successo');
    } catch (e, stackTrace) {
      developer.log('ERRORE in AudioManager.stopAll: $e\n$stackTrace');
    }
  }
}
