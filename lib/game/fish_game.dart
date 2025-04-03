import 'dart:math';
import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/components/player_fish.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/hud.dart';

class FishGame extends FlameGame with KeyboardEvents, HasCollisionDetection {
  late PlayerFish player;
  final Random _random = Random();
  int score = 0;
  int lives = 3;
  double _spawnTimer = 0;
  final double _spawnInterval = 2.0; // Spawn enemy every 2 seconds
  late Hud hud;
  
  // Tasti premuti
  final Set<LogicalKeyboardKey> _keysPressed = {};

  @override
  Future<void> onLoad() async {
    developer.log('FishGame: onLoad iniziato');
    try {
      await super.onLoad();
      
      // Inizializza l'audio manager
      await AudioManager.initialize();
      
      developer.log('FishGame: impostazione sfondo');
      // Imposta lo sfondo blu per rappresentare l'acqua
      camera.viewfinder.visibleGameSize = Vector2(800, 600);
      
      developer.log('FishGame: creazione player');
      // Aggiungi il pesce giocatore
      player = PlayerFish();
      add(player);
      
      developer.log('FishGame: creazione HUD');
      // Aggiungi l'HUD
      hud = Hud();
      add(hud);
      
      developer.log('FishGame: creazione primo nemico');
      // Inizializza il primo nemico
      _spawnEnemy();
      
      // Avvia la musica di sottofondo e il suono ambientale
      AudioManager.playBackgroundMusic();
      AudioManager.playAmbientSound();
      
      developer.log('FishGame: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.onLoad: $e\n$stackTrace');
    }
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      // Aggiorna i controlli del giocatore in base ai tasti premuti
      _updatePlayerControls();
      
      // Genera nemici a intervalli
      _spawnTimer += dt;
      if (_spawnTimer >= _spawnInterval) {
        _spawnTimer = 0;
        _spawnEnemy();
      }
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.update: $e\n$stackTrace');
    }
  }
  
  void _updatePlayerControls() {
    // Controlla i movimenti in base ai tasti premuti
    player.moveUp(_keysPressed.contains(LogicalKeyboardKey.keyW) || 
                 _keysPressed.contains(LogicalKeyboardKey.arrowUp));
    
    player.moveDown(_keysPressed.contains(LogicalKeyboardKey.keyS) || 
                   _keysPressed.contains(LogicalKeyboardKey.arrowDown));
    
    player.moveLeft(_keysPressed.contains(LogicalKeyboardKey.keyA) || 
                   _keysPressed.contains(LogicalKeyboardKey.arrowLeft));
    
    player.moveRight(_keysPressed.contains(LogicalKeyboardKey.keyD) || 
                    _keysPressed.contains(LogicalKeyboardKey.arrowRight));
  }

  void _spawnEnemy() {
    try {
      developer.log('FishGame: generazione nemico');
      // Crea pesci nemici in posizioni Y casuali sul lato destro dello schermo
      final enemyFish = EnemyFish(
        position: Vector2(
          size.x + 50, // Inizia fuori dallo schermo a destra
          _random.nextDouble() * (size.y - 100) + 50, // Posizione Y casuale
        ),
        isDangerous: _random.nextBool(), // 50% di probabilità di essere pericoloso
      );
      add(enemyFish);
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnEnemy: $e\n$stackTrace');
    }
  }

  void increaseScore() {
    score++;
    // Riproduci suono quando mangia un pesce
    AudioManager.playEatSound();
  }

  void decreaseLives() {
    lives--;
    // Riproduci suono quando viene ferito
    AudioManager.playHurtSound();
    
    if (lives <= 0) {
      overlays.add('gameOver');
      pauseEngine();
    }
  }

  void reset() {
    // Reimposta lo stato del gioco
    score = 0;
    lives = 3;
    _spawnTimer = 0;
    
    // Rimuovi tutti i nemici
    children.whereType<EnemyFish>().forEach((enemy) => enemy.removeFromParent());
    
    // Reimposta la posizione del giocatore
    player.position = Vector2(100, 300);
    
    // Riprendi il gioco
    resumeEngine();
    
    // Riavvia la musica di sottofondo e il suono ambientale
    AudioManager.playBackgroundMusic();
    AudioManager.playAmbientSound();
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    try {
      // Aggiorna il set di tasti premuti
      if (event is KeyDownEvent) {
        _keysPressed.add(event.logicalKey);
        developer.log('Tasto premuto: ${event.logicalKey}');
      } else if (event is KeyUpEvent) {
        _keysPressed.remove(event.logicalKey);
        developer.log('Tasto rilasciato: ${event.logicalKey}');
      }
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.onKeyEvent: $e\n$stackTrace');
    }
    
    return KeyEventResult.handled;
  }
  
  @override
  void onRemove() {
    // Ferma tutti i suoni quando il gioco viene rimosso
    AudioManager.stopAll();
    super.onRemove();
  }
}
