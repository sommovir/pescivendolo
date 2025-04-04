import 'dart:math';
import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/components/player_fish.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/hud.dart';

class FishGame extends FlameGame with KeyboardEvents, HasCollisionDetection {
  late PlayerFish player;
  final Random _random = Random();
  int score = 0;
  int lives = 3;
  double _spawnTimer = 0;
  final double _spawnInterval = 2.0; // Spawn enemy every 2 seconds
  
  // Timer per il polipetto
  double _octopusSpawnTimer = 0;
  final double _octopusSpawnInterval = 5.0; // Spawn octopus every 5 seconds
  
  late Hud hud;
  
  // Flag per indicare se il gioco è iniziato
  bool _gameStarted = false;
  
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
      
      // Mostra l'overlay di avvio
      overlays.add('startGame');
      
      // Pausa il gioco fino a quando l'utente non preme il pulsante Start
      pauseEngine();
      
      developer.log('FishGame: onLoad completato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.onLoad: $e\n$stackTrace');
    }
  }
  
  // Metodo per avviare il gioco
  void startGame() {
    try {
      developer.log('FishGame: avvio del gioco');
      
      // Rimuovi l'overlay di avvio
      overlays.remove('startGame');
      
      // Imposta il flag di interazione utente per l'audio
      AudioManager.setUserInteracted();
      
      // Avvia la musica di sottofondo e il suono ambientale
      AudioManager.playBackgroundMusic();
      AudioManager.playAmbientSound();
      
      // Genera il primo nemico
      _spawnEnemy();
      
      // Imposta il flag di gioco iniziato
      _gameStarted = true;
      
      // Riprendi il motore di gioco
      resumeEngine();
      
      developer.log('FishGame: gioco avviato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.startGame: $e\n$stackTrace');
    }
  }

  @override
  void update(double dt) {
    try {
      super.update(dt);
      
      // Se il gioco non è ancora iniziato, non fare nulla
      if (!_gameStarted) return;
      
      // Aggiorna i controlli del giocatore in base ai tasti premuti
      _updatePlayerControls();
      
      // Genera nemici a intervalli
      _spawnTimer += dt;
      if (_spawnTimer >= _spawnInterval) {
        _spawnTimer = 0;
        _spawnEnemy();
      }
      
      // Genera polipetti a intervalli più lunghi
      _octopusSpawnTimer += dt;
      if (_octopusSpawnTimer >= _octopusSpawnInterval) {
        _octopusSpawnTimer = 0;
        // 30% di probabilità di generare un polipetto
        if (_random.nextDouble() < 0.3) {
          _spawnOctopus();
        }
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
  
  void _spawnOctopus() {
    try {
      developer.log('FishGame: generazione polipetto');
      // Crea un polipetto sul fondale sul lato destro dello schermo
      final octopus = OctopusEnemy(
        position: Vector2(
          size.x + 50, // Inizia fuori dallo schermo a destra
          size.y * 0.85, // Posizione Y fissa sul fondale
        ),
      );
      add(octopus);
      developer.log('FishGame: polipetto generato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnOctopus: $e\n$stackTrace');
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
    try {
      developer.log('FishGame: reset del gioco');
      
      // Rimuovi l'overlay di game over
      overlays.remove('gameOver');
      
      // Reimposta lo stato del gioco
      score = 0;
      lives = 3;
      _spawnTimer = 0;
      _octopusSpawnTimer = 0;
      
      // Rimuovi tutti i nemici esistenti
      children.whereType<EnemyFish>().forEach((enemy) {
        developer.log('FishGame: rimozione pesce nemico');
        enemy.removeFromParent();
      });
      
      children.whereType<OctopusEnemy>().forEach((octopus) {
        developer.log('FishGame: rimozione polipetto');
        octopus.removeFromParent();
      });
      
      // Reimposta la posizione del giocatore
      player.position = Vector2(100, 300);
      developer.log('FishGame: posizione del giocatore reimpostata');
      
      // Ferma tutti i suoni
      AudioManager.stopAll();
      
      // Riavvia la musica e i suoni ambientali
      AudioManager.playBackgroundMusic();
      AudioManager.playAmbientSound();
      
      // Genera un nuovo nemico per iniziare
      _spawnEnemy();
      
      // Riprendi il motore di gioco
      resumeEngine();
      developer.log('FishGame: motore di gioco ripreso');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.reset: $e\n$stackTrace');
    }
  }
  
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysPressed.clear();
    _keysPressed.addAll(keysPressed);
    return KeyEventResult.handled;
  }
}
