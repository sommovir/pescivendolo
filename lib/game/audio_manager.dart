import 'package:flame_audio/flame_audio.dart';
import 'dart:developer' as developer;

class AudioManager {
  static bool _initialized = false;
  static bool _bgmPlaying = false;
  static bool _ambientPlaying = false;
  
  // Nome del file per il suono ambientale subacqueo
  static const String underwaterSoundFile = '774918__klankbeeld__backswimmer-under-water-134-pm-220725_0457.wav';
  
  // Nome del file per il suono quando il pesce viene ferito
  static const String hurtSoundFile = 'hai_hai.m4a';
  
  // Nome del file per il suono quando il pesce mangia
  static const String eatSoundFile = 'gulp.mp3';
  
  // Nome del file per la musica di sottofondo
  static const String musicFile = 'music.wav';
  
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
      
      // Precarica gli effetti sonori che sappiamo esistere
      await FlameAudio.audioCache.loadAll([
        musicFile,
        underwaterSoundFile,
        hurtSoundFile,
        eatSoundFile,
      ]);
      
      // I suoni sono disponibili
      _hurtSoundAvailable = true;
      _eatSoundAvailable = true;
      _musicAvailable = true;
      _ambientSoundAvailable = true;
      
      _initialized = true;
      developer.log('AudioManager: inizializzazione completata');
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.initialize: $e\n$stackTrace');
    }
  }
  
  // Riproduci musica di sottofondo
  static void playBackgroundMusic() {
    if (_bgmPlaying || !_musicAvailable) return;
    
    try {
      developer.log('AudioManager: avvio musica di sottofondo');
      // Per la musica di sottofondo, utilizziamo FlameAudio.bgm che supporta il loop
      FlameAudio.bgm.play(musicFile);
      _bgmPlaying = true;
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.playBackgroundMusic: $e\n$stackTrace');
    }
  }
  
  // Riproduci suono ambientale
  static void playAmbientSound() {
    if (_ambientPlaying || !_ambientSoundAvailable) return;
    
    try {
      developer.log('AudioManager: avvio suono ambientale');
      // Per il suono ambientale, utilizziamo FlameAudio.bgm con volume più basso
      FlameAudio.bgm.play(underwaterSoundFile, volume: 0.3);
      _ambientPlaying = true;
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.playAmbientSound: $e\n$stackTrace');
    }
  }
  
  // Riproduci suono quando mangia un pesce
  static void playEatSound() {
    if (!_eatSoundAvailable) return;
    
    try {
      developer.log('AudioManager: riproduzione suono mangia');
      FlameAudio.play(eatSoundFile);
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.playEatSound: $e\n$stackTrace');
    }
  }
  
  // Riproduci suono quando viene ferito
  static void playHurtSound() {
    if (!_hurtSoundAvailable) return;
    
    try {
      developer.log('AudioManager: riproduzione suono ferito');
      // Nella versione attuale di flame_audio, non possiamo usare startAt
      // Riproduciamo il file così com'è
      FlameAudio.play(hurtSoundFile);
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.playHurtSound: $e\n$stackTrace');
    }
  }
  
  // Ferma tutta la musica e i suoni
  static void stopAll() {
    try {
      developer.log('AudioManager: arresto di tutti i suoni');
      // Fermiamo la musica di sottofondo
      FlameAudio.bgm.stop();
      _bgmPlaying = false;
      _ambientPlaying = false;
    } catch (e, stackTrace) {
      developer.log('Errore in AudioManager.stopAll: $e\n$stackTrace');
    }
  }
}
