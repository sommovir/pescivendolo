import 'dart:math';
import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/effects.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/electric_eel_enemy.dart';
import 'package:pescivendolo_game/game/components/hud.dart';
import 'package:pescivendolo_game/game/components/jellyfish_enemy.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/player_fish.dart';
import 'package:pescivendolo_game/game/components/shield_effect.dart';
import 'package:pescivendolo_game/game/components/swordfish_enemy.dart';
import 'package:pescivendolo_game/game/components/whale_powerup.dart';

class FishGame extends FlameGame with KeyboardEvents, HasCollisionDetection {
  late PlayerFish player;
  final Random _random = Random();
  int score = 0;
  
  // Sistema di vita
  double _health = 100.0; // Vita al 100%
  
  // Timer per lo spawn
  double _spawnTimer = 0;
  double _spawnInterval = 2.0; // Spawn enemy every 2 seconds
  
  // Timer per il polipetto
  double _octopusSpawnTimer = 0;
  double _octopusSpawnInterval = 10.0; // Spawn octopus every 10 seconds (più frequente)
  
  // Timer per le meduse
  double _jellyfishSpawnTimer = 0;
  double _jellyfishSpawnInterval = 8.0; // Spawn jellyfish every 8 seconds (increased frequency from 20)
  
  // Timer per la murena elettrica
  double _eelSpawnTimer = 0;
  double _eelSpawnInterval = 5.0; // Spawn electric eel every 5 seconds (aumentato ulteriormente)
  
  // Timer per il pesce spada
  double _swordfishSpawnTimer = 0;
  double _swordfishSpawnInterval = 8.0; // Spawn pesce spada ogni 8 secondi (ancora più frequente)
  int _maxSimultaneousSwordfish = 1; // Numero massimo di pesci spada simultanei, aumenterà col tempo
  
  // Timer per le bolle
  double _bubbleTimer = 0;
  final double _bubbleInterval = 0.5; // Genera bolle ogni 0.5 secondi
  
  // Timer per aumentare la difficoltà
  double _difficultyTimer = 0;
  final double _difficultyInterval = 30.0; // Aumenta difficoltà ogni 30 secondi
  int _difficultyLevel = 1;
  
  // Parametri per la progressione della difficoltà
  double _baseEnemySpeed = 100.0;
  double _maxEnemySpeed = 350.0; // Velocità massima aumentata
  int _maxJellyfishInSwarm = 3; // Inizia con branchi piccoli
  
  // Tempo di gioco
  double _gameTime = 0.0;
  
  // Getter pubblico per il tempo di gioco
  double get gameTime => _gameTime;
  
  late Hud hud;
  
  // Flag per indicare se il gioco è iniziato
  bool _gameStarted = false;
  
  // Tasti premuti
  final Set<LogicalKeyboardKey> _keysPressed = {};
  
  // Stato dell'orientamento
  bool _isLandscapeMode = false;
  bool get isLandscapeMode => _isLandscapeMode;
  
  // Parametri per la balena
  double _whaleSpawnTimer = 0;
  double _whaleSpawnInterval = 25.0; // Aumentato da 15 a 25 secondi
  
  // Parametri per l'invulnerabilità
  double _invulnerabilityCharge = 0.0; // Carica corrente (0-100%)
  double _invulnerabilityTimer = 0.0; // Timer per la durata dell'invulnerabilità
  final double _invulnerabilityDuration = 10.0; // Durata dell'invulnerabilità in secondi
  bool _isPlayerInvulnerable = false; // Flag per indicare se il giocatore è invulnerabile
  ShieldEffect? _shieldEffect; // Effetto visivo dello scudo
  
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
      
      // Aggiungi lo sfondo acquatico come primo componente
      // per assicurarsi che copra l'intero schermo
      final waterBackground = WaterBackgroundComponent();
      add(waterBackground);
      
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
      
      // Aggiorna il tempo di gioco
      _gameTime += dt;
      
      // Aggiorna i controlli del giocatore in base ai tasti premuti
      _updatePlayerControls();
      
      // Aggiorna la difficoltà del gioco
      _updateDifficulty(dt);
      
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
        
        // Probabilità crescente in base al livello di difficoltà
        double octopusChance = 0.1 + (_difficultyLevel * 0.03);
        if (_random.nextDouble() < octopusChance) {
          _spawnOctopus();
        }
      }
      
      // Genera meduse a intervalli
      _jellyfishSpawnTimer += dt;
      if (_jellyfishSpawnTimer >= _jellyfishSpawnInterval) {
        _jellyfishSpawnTimer = 0;
        
        // Probabilità crescente in base al livello di difficoltà
        double jellyfishChance = 0.2 + (_difficultyLevel * 0.05);
        if (_random.nextDouble() < jellyfishChance) {
          _spawnJellyfishSwarm();
        }
      }
      
      // Genera murene elettriche a intervalli
      _eelSpawnTimer += dt;
      if (_eelSpawnTimer >= _eelSpawnInterval) {
        _eelSpawnTimer = 0;
        
        // Probabilità crescente in base al livello di difficoltà
        double eelChance = 0.15 + (_difficultyLevel * 0.04); // Aumentata
        if (_random.nextDouble() < eelChance) {
          _spawnElectricEel();
        }
      }
      
      // Genera pesci spada a intervalli
      _swordfishSpawnTimer += dt;
      if (_swordfishSpawnTimer >= _swordfishSpawnInterval) {
        _swordfishSpawnTimer = 0;
        // Probabilità crescente in base al livello di difficoltà
        double swordfishChance = 0.1 + (_difficultyLevel * 0.02); // Aumentata
        if (_random.nextDouble() < swordfishChance) {
          _spawnSwordfish();
        }
      }
      
      // Genera balene a intervalli
      _whaleSpawnTimer += dt;
      if (_whaleSpawnTimer >= _whaleSpawnInterval) {
        _whaleSpawnTimer = 0;
        // Probabilità fissa (le balene sono rare ma più frequenti)
        double whaleChance = 0.4; // Ridotto da 0.6 a 0.4 (40% di probabilità ogni 25 secondi)
        if (_random.nextDouble() < whaleChance) {
          _spawnWhale();
        }
      }
      
      // Genera bolle a intervalli regolari
      _bubbleTimer += dt;
      if (_bubbleTimer >= _bubbleInterval) {
        _bubbleTimer = 0;
        _spawnBubble();
      }
      
      // Aggiorna il timer dell'invulnerabilità se attiva
      if (_isPlayerInvulnerable) {
        _invulnerabilityTimer -= dt;
        
        // Se il timer scade, disattiva l'invulnerabilità
        if (_invulnerabilityTimer <= 0) {
          _deactivateInvulnerability();
        }
      }
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.update: $e\n$stackTrace');
    }
  }
  
  void _updateDifficulty(double dt) {
    // Aumenta la difficoltà nel tempo
    _difficultyTimer += dt;
    if (_difficultyTimer >= _difficultyInterval) {
      _difficultyTimer = 0;
      _difficultyLevel++;
      
      // Aumenta la velocità dei nemici
      _baseEnemySpeed = min(_baseEnemySpeed + 15.0, _maxEnemySpeed); // Aumento più rapido
      
      // Riduci gli intervalli di spawn
      _spawnInterval = max(_spawnInterval * 0.95, 0.7); // Minimo 0.7 secondi
      _octopusSpawnInterval = max(_octopusSpawnInterval * 0.95, 8.0); // Minimo 8 secondi
      _jellyfishSpawnInterval = max(_jellyfishSpawnInterval * 0.9, 8.0); // Minimo 8 secondi
      _eelSpawnInterval = max(_eelSpawnInterval * 0.9, 5.0); // Minimo 5 secondi
      
      // Aumenta la dimensione dei branchi di meduse
      _maxJellyfishInSwarm = min(_maxJellyfishInSwarm + 1, 12); // Massimo 12 meduse
      
      // Aumenta il numero massimo di pesci spada simultanei
      _maxSimultaneousSwordfish = min(_maxSimultaneousSwordfish + 1, 3); // Massimo 3 pesci spada
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
      
      // Calcola la velocità in base al livello di difficoltà
      // Aggiungi un po' di casualità alla velocità
      double speedVariation = _random.nextDouble() * 30.0 - 15.0; // ±15
      double enemySpeed = _baseEnemySpeed + speedVariation;
      
      // Crea pesci nemici in posizioni Y casuali sul lato destro dello schermo
      final enemyFish = EnemyFish(
        position: Vector2(
          size.x + 50, // Inizia fuori dallo schermo a destra
          _random.nextDouble() * (size.y - 100) + 50, // Posizione Y casuale
        ),
        isDangerous: _random.nextBool(), // 50% di probabilità di essere pericoloso
        speed: enemySpeed,
      );
      add(enemyFish);
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnEnemy: $e\n$stackTrace');
    }
  }
  
  void _spawnOctopus() {
    try {
      developer.log('FishGame: generazione polipetto');
      
      // Calcola la velocità in base al livello di difficoltà
      double speedVariation = _random.nextDouble() * 20.0 - 10.0; // ±10
      double octopusSpeed = _baseEnemySpeed * 0.8 + speedVariation; // Più lento dei pesci
      
      // Crea un polipetto sul fondale sul lato destro dello schermo
      final octopus = OctopusEnemy(
        position: Vector2(
          size.x + 50, // Inizia fuori dallo schermo a destra
          size.y * 0.85, // Posizione Y fissa sul fondale
        ),
      );
      // Imposta la velocità del polipetto
      octopus.speed = octopusSpeed;
      add(octopus);
      developer.log('FishGame: polipetto generato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnOctopus: $e\n$stackTrace');
    }
  }
  
  void _spawnJellyfishSwarm() {
    try {
      developer.log('FishGame: generazione branco di meduse');
      
      // Determina la dimensione del branco in base al livello di difficoltà
      int swarmSize = 2 + _random.nextInt(_maxJellyfishInSwarm - 1);
      
      // Calcola la velocità base per questo branco (le meduse sono lente)
      double speedVariation = _random.nextDouble() * 20.0 - 10.0; // ±10
      double jellyfishSpeed = (_baseEnemySpeed * 0.7) + speedVariation;
      
      // Posizione Y di base per il branco
      double baseY = _random.nextDouble() * (size.y - 200) + 100;
      
      // Genera il branco di meduse
      for (int i = 0; i < swarmSize; i++) {
        // Varia leggermente la posizione Y e X per ogni medusa
        double offsetY = _random.nextDouble() * 100 - 50; // ±50
        double offsetX = _random.nextDouble() * 150; // 0-150 (distanza orizzontale tra meduse)
        
        // Varia leggermente la dimensione di ogni medusa (aumentata a 8-11x)
        double sizeMultiplier = 8.0 + _random.nextDouble() * 3.0; // Da 8x a 11x
        
        final jellyfish = JellyfishEnemy(
          position: Vector2(
            size.x + 50 + offsetX, // Inizia fuori dallo schermo a destra
            baseY + offsetY, // Posizione Y variabile attorno alla base
          ),
          speed: jellyfishSpeed,
          sizeMultiplier: sizeMultiplier,
        );
        add(jellyfish);
      }
      
      developer.log('FishGame: branco di $swarmSize meduse generato con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnJellyfishSwarm: $e\n$stackTrace');
    }
  }
  
  void _spawnElectricEel() {
    try {
      developer.log('FishGame: generazione murena elettrica');
      
      // Calcola la velocità in base al livello di difficoltà (velocità variabile)
      double speedVariation = _random.nextDouble() * 40.0 - 20.0; // ±20
      double eelSpeed = _baseEnemySpeed + speedVariation;
      
      // Posizione Y casuale per la murena
      double posY = _random.nextDouble() * (size.y - 150) + 75;
      
      // Dimensione della murena (12-14 volte un pesce rosso, raddoppiata)
      double sizeMultiplier = 12.0 + _random.nextDouble() * 2.0; // Da 12x a 14x
      
      final eel = ElectricEelEnemy(
        position: Vector2(
          size.x + 50, // Inizia fuori dallo schermo a destra
          posY, // Posizione Y casuale
        ),
        speed: eelSpeed,
        sizeMultiplier: sizeMultiplier,
      );
      add(eel);
      
      developer.log('FishGame: murena elettrica generata con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnElectricEel: $e\n$stackTrace');
    }
  }
  
  void _spawnSwordfish() {
    try {
      developer.log('FishGame: generazione pesce spada');
      
      // Calcola quanti pesci spada generare contemporaneamente in base al livello di difficoltà
      int swordfishCount = _random.nextInt(_maxSimultaneousSwordfish) + 1;
      
      for (int i = 0; i < swordfishCount; i++) {
        // Calcola la velocità in base al livello di difficoltà (velocità variabile)
        double baseSpeed = _baseEnemySpeed + (_difficultyLevel * 25); // Base speed increases with difficulty
        double speedVariation = _random.nextDouble() * 30.0 - 15.0; // ±15
        double swordfishSpeed = baseSpeed + speedVariation;
        
        // Posizione Y casuale per il pesce spada
        double posY = _random.nextDouble() * (size.y - 150) + 75;
        
        // Dimensione del pesce spada (aumentata a 25x come richiesto)
        double sizeMultiplier = 25.0 + _random.nextDouble() * 0.5; // Da 25x a 25.5x
        
        // Durata del tremore casuale tra 1 e 3 secondi come richiesto
        double peekingDuration = 1.0 + _random.nextDouble() * 2.0; // Da 1 a 3 secondi
        
        // La velocità di carica è molto più alta della velocità normale
        double chargeSpeed = swordfishSpeed * 4.0; // 4.0 volte più veloce durante la carica (aumentata)
        
        final swordfish = SwordfishEnemy(
          position: Vector2(
            size.x + 20, // Inizia appena fuori dallo schermo a destra
            posY, // Posizione Y casuale
          ),
          speed: swordfishSpeed,
          sizeMultiplier: sizeMultiplier,
          chargeSpeed: chargeSpeed,
          peekingDuration: peekingDuration,
        );
        add(swordfish);
        developer.log('FishGame: pesce spada #$i generato con successo');
      }
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnSwordfish: $e\n$stackTrace');
    }
  }
  
  void _spawnWhale() {
    try {
      developer.log('FishGame: generazione balena');
      
      // Calcola la velocità (la balena è più lenta)
      double baseSpeed = _baseEnemySpeed * 0.4; // 40% della velocità base
      double speedVariation = _random.nextDouble() * 20.0 - 10.0; // ±10
      double whaleSpeed = baseSpeed + speedVariation;
      
      // La balena appare a sinistra e si muove verso destra
      double posY = _random.nextDouble() * (size.y - 150) + 75;
      
      // Dimensione della balena (molto più grande)
      double sizeMultiplier = 15.0; // Aumentata da 8.0 a 15.0
      
      final whale = WhalePowerup(
        position: Vector2(
          -50, // Inizia appena fuori dallo schermo a sinistra
          posY, // Posizione Y casuale
        ),
        speed: whaleSpeed,
        sizeMultiplier: sizeMultiplier,
      );
      
      add(whale);
      developer.log('FishGame: balena generata con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnWhale: $e\n$stackTrace');
    }
  }
  
  void _spawnBubble() {
    try {
      // Crea una bolla in una posizione casuale sul fondo dello schermo
      final bubble = BubbleComponent(
        position: Vector2(
          _random.nextDouble() * size.x,
          size.y + 10, // Inizia appena sotto il bordo inferiore
        ),
        speed: _random.nextDouble() * 30 + 20, // Velocità casuale tra 20 e 50
        size: Vector2(
          _random.nextDouble() * 10 + 5, // Dimensione casuale tra 5 e 15
          _random.nextDouble() * 10 + 5,
        ),
      );
      add(bubble);
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnBubble: $e\n$stackTrace');
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysPressed.clear();
    _keysPressed.addAll(keysPressed);
    return KeyEventResult.handled;
  }
  
  void increaseScore([int points = 1]) {
    score += points;
    AudioManager.playEatSound(); // Usa il metodo esistente
  }
  
  // Metodi per gestire la salute del giocatore
  double get health => _health;
  
  // Metodo per danneggiare il player, usato dalle murene elettriche
  void damagePlayer(double amount) {
    decreaseHealth(amount);
  }
  
  void decreaseHealth(double amount) {
    // Se il giocatore è invulnerabile, non subisce danni
    if (_isPlayerInvulnerable) {
      developer.log('FishGame: giocatore invulnerabile, danno ignorato');
      return;
    }
    
    // Altrimenti applica il danno normalmente
    _health = max(0, _health - amount);
    AudioManager.playHurtSound();
    
    if (_health <= 0) {
      // Quando la salute arriva a zero, il giocatore perde
      _gameOver();
    }
  }
  
  void increaseHealth(double amount) {
    try {
      // Calcola nuovo valore ma non superare il 100%
      final newHealth = min(100.0, _health + amount);
      
      // Se il nuovo valore è diverso da quello attuale, riproduci il suono
      if (newHealth > _health) {
        AudioManager.playEatSound(); // Usa il metodo esistente
      }
      
      // Aggiorna la salute
      _health = newHealth;
      
      developer.log('FishGame: aumentata salute a $_health');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.increaseHealth: $e\n$stackTrace');
    }
  }
  
  void _gameOver() {
    overlays.add('gameOver');
    pauseEngine();
  }
  
  // Aggiungiamo il metodo reset che era presente nella versione precedente
  void reset() {
    try {
      developer.log('FishGame: reset del gioco');
      
      // Ferma tutti gli audio in corso prima di qualsiasi altra operazione
      AudioManager.stopAll();
      
      // Rimuovi tutti i nemici esistenti
      children.whereType<EnemyFish>().forEach((enemy) {
        developer.log('FishGame: rimozione pesce nemico');
        enemy.removeFromParent();
      });
      
      children.whereType<OctopusEnemy>().forEach((octopus) {
        developer.log('FishGame: rimozione polipetto');
        octopus.removeFromParent();
      });
      
      children.whereType<JellyfishEnemy>().forEach((jellyfish) {
        developer.log('FishGame: rimozione medusa');
        jellyfish.removeFromParent();
      });
      
      children.whereType<ElectricEelEnemy>().forEach((eel) {
        developer.log('FishGame: rimozione murena elettrica');
        eel.removeFromParent();
      });
      
      children.whereType<SwordfishEnemy>().forEach((swordfish) {
        developer.log('FishGame: rimozione pesce spada');
        swordfish.removeFromParent();
      });
      
      children.whereType<WhalePowerup>().forEach((whale) {
        developer.log('FishGame: rimozione balena');
        whale.removeFromParent();
      });
      
      children.whereType<BubbleComponent>().forEach((bubble) {
        bubble.removeFromParent();
      });
      
      // Resetta lo stato del gioco
      score = 0;
      _spawnTimer = 0;
      _octopusSpawnTimer = 0;
      _jellyfishSpawnTimer = 0;
      _eelSpawnTimer = 0;
      _swordfishSpawnTimer = 0;
      _whaleSpawnTimer = 0;
      _bubbleTimer = 0;
      _difficultyTimer = 0;
      _difficultyLevel = 1;
      _baseEnemySpeed = 100.0;
      _health = 100.0;
      _invulnerabilityCharge = 0.0;
      _invulnerabilityTimer = 0.0;
      _isPlayerInvulnerable = false;
      
      // Se il giocatore è stato rimosso, ricrealo
      if (!children.contains(player)) {
        player = PlayerFish();
        add(player);
        developer.log('FishGame: creato nuovo giocatore');
      } else {
        // Altrimenti, reimposta solo la posizione
        player.position = Vector2(100, 300);
        developer.log('FishGame: posizione del giocatore reimpostata');
      }
      
      // Rimuovi l'overlay di game over se presente
      overlays.remove('gameOver');
      
      // Riavvia la musica e i suoni ambientali dopo un breve ritardo
      // per assicurarsi che l'audio precedente sia completamente fermato
      Future.delayed(const Duration(milliseconds: 500), () {
        AudioManager.playBackgroundMusic();
        AudioManager.playAmbientSound();
      });
      
      // Genera un nuovo nemico per iniziare
      _spawnEnemy();
      
      // Riprendi il motore di gioco
      resumeEngine();
      developer.log('FishGame: motore di gioco ripreso con successo');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.reset: $e\n$stackTrace');
    }
  }
  
  // Metodi per la gestione dell'invulnerabilità
  double get invulnerabilityCharge => _invulnerabilityCharge;
  double get invulnerabilityTimer => _invulnerabilityTimer;
  bool get isPlayerInvulnerable => _isPlayerInvulnerable;
  
  void increaseInvulnerabilityCharge(double amount) {
    // Aggiungi carica solo se non siamo già invulnerabili
    if (!_isPlayerInvulnerable) {
      _invulnerabilityCharge = min(100.0, _invulnerabilityCharge + amount);
      developer.log('FishGame: carica invulnerabilità a $_invulnerabilityCharge%');
    }
  }
  
  void activateInvulnerability() {
    try {
      if (_isPlayerInvulnerable) return;
      
      developer.log('FishGame: attivazione invulnerabilità');
      _isPlayerInvulnerable = true;
      _invulnerabilityTimer = _invulnerabilityDuration;
      _invulnerabilityCharge = 0; // Resetta la carica
      
      // Riproduci il suono di attivazione dello scudo
      developer.log('FishGame: riproduzione suono scudo...');
      AudioManager.playShieldSound(); // Usiamo il nuovo suono specifico per lo scudo
      developer.log('FishGame: richiesta riproduzione suono scudo completata');
      
      // Aggiungi effetto visivo di scudo attorno al giocatore
      if (_shieldEffect != null && _shieldEffect!.isMounted) {
        _shieldEffect!.removeFromParent();
      }
      
      _shieldEffect = ShieldEffect(
        radius: player.size.length * 0.6, // Ridotto da 0.7 a 0.6 per un migliore adattamento
        duration: _invulnerabilityDuration,
      );
      
      // Nota: ora lo shield è già configurato con anchor=Anchor.center nel suo costruttore
      player.add(_shieldEffect!);
      
      developer.log('FishGame: invulnerabilità attivata per $_invulnerabilityDuration secondi');
    } catch (e, stackTrace) {
      developer.log('ERRORE in FishGame.activateInvulnerability: $e\n$stackTrace');
    }
  }
  
  void _deactivateInvulnerability() {
    try {
      developer.log('FishGame: disattivazione invulnerabilità');
      _isPlayerInvulnerable = false;
      
      // Rimuovi l'effetto visivo di scudo
      if (_shieldEffect != null && _shieldEffect!.isMounted) {
        _shieldEffect!.removeFromParent();
        _shieldEffect = null;
      }
      
      developer.log('FishGame: invulnerabilità disattivata');
    } catch (e, stackTrace) {
      developer.log('ERRORE in FishGame._deactivateInvulnerability: $e\n$stackTrace');
    }
  }
  
  // Metodo per aggiornare l'orientamento
  void updateOrientation(bool isLandscape) {
    try {
      _isLandscapeMode = isLandscape;
      
      // Aggiusta la posizione del player se necessario
      if (player.isLoaded) {
        // Assicurati che il player sia sempre in una posizione visibile
        if (player.position.x > size.x - player.size.x) {
          player.position.x = size.x - player.size.x;
        }
        if (player.position.y > size.y - player.size.y) {
          player.position.y = size.y - player.size.y;
        }
      }
      
      // Aggiorna i componenti dello sfondo
      children.whereType<FullScreenGradientComponent>().forEach((component) {
        component.onGameResize(size);
      });
      
      developer.log('FishGame: orientamento aggiornato a ${isLandscape ? 'landscape' : 'portrait'}');
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame.updateOrientation: $e\n$stackTrace');
    }
  }
}

class WaterBackgroundComponent extends Component {
  @override
  Future<void> onLoad() async {
    // Aggiungi solo uno sfondo a gradiente che copre l'intero schermo
    final background = FullScreenGradientComponent();
    add(background);
    
    // Nessun raggio di luce - rimossi completamente per eliminare le strisce verticali
  }
}

class FullScreenGradientComponent extends PositionComponent with HasGameRef {
  @override
  Future<void> onLoad() async {
    // Assicurati che il componente copra l'intero schermo
    size = gameRef.size;
    position = Vector2.zero();
    
    // Imposta la priorità più bassa per essere disegnato prima di tutto
    priority = -100;
  }
  
  @override
  void onGameResize(Vector2 gameSize) {
    // Aggiorna le dimensioni ogni volta che la dimensione del gioco cambia
    size = gameSize;
    position = Vector2.zero();
    super.onGameResize(gameSize);
  }
  
  @override
  void render(Canvas canvas) {
    // Assicurati che le dimensioni siano sempre aggiornate
    final screenSize = gameRef.size;
    size = screenSize;
    
    // Crea un gradiente che copre l'intero schermo
    final rect = Rect.fromLTWH(0, 0, screenSize.x, screenSize.y);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF87CEEB), // Azzurro cielo
          const Color(0xFF4682B4), // Blu acciaio
          const Color(0xFF000080), // Blu navy
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);
    
    // Disegna un rettangolo che copre l'intero schermo
    canvas.drawRect(rect, paint);
  }
}

class BubbleComponent extends PositionComponent {
  static final Paint _bubblePaint = Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.fill;
  
  BubbleComponent({
    required Vector2 position,
    required double speed,
    required Vector2 size,
  }) : super(position: position, size: size) {
    this.speed = speed;
  }
  
  late double speed;
  
  @override
  Future<void> onLoad() async {
    // Aggiungi un effetto di movimento verso l'alto con leggero zigzag
    final random = Random();
    final speedY = 30 + random.nextDouble() * 20;
    final speedX = (random.nextDouble() * 10) - 5;
    
    add(
      MoveEffect.by(
        Vector2(speedX, -600 - size.y),
        EffectController(
          duration: 600 / speedY,
        ),
        onComplete: () => removeFromParent(),
      ),
    );
  }
  
  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      _bubblePaint,
    );
    
    // Riflesso della bolla
    final highlightPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.x * 0.3, size.y * 0.3),
      size.x * 0.2,
      highlightPaint,
    );
  }
}
