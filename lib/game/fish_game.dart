import 'dart:math';
import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/components/player_fish.dart';
import 'package:pescivendolo_game/game/components/enemy_fish.dart';
import 'package:pescivendolo_game/game/components/octopus_enemy.dart';
import 'package:pescivendolo_game/game/components/hud.dart';
import 'package:pescivendolo_game/game/components/water_background.dart';

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
  
  // Timer per le bolle
  double _bubbleTimer = 0;
  final double _bubbleInterval = 0.5; // Genera bolle ogni 0.5 secondi
  
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
      
      // Aggiungi lo sfondo acquatico
      add(WaterBackgroundComponent());
      
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
      
      // Genera bolle a intervalli regolari
      _bubbleTimer += dt;
      if (_bubbleTimer >= _bubbleInterval) {
        _bubbleTimer = 0;
        _spawnBubble();
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
  
  void _spawnBubble() {
    try {
      // Crea una bolla in una posizione casuale sul fondo dello schermo
      final bubbleSize = _random.nextDouble() * 15 + 5; // Dimensione casuale tra 5 e 20
      final bubbleX = _random.nextDouble() * size.x;
      final bubbleY = size.y + bubbleSize;
      
      final bubble = BubbleComponent(
        position: Vector2(bubbleX, bubbleY),
        size: Vector2(bubbleSize, bubbleSize),
      );
      add(bubble);
    } catch (e, stackTrace) {
      developer.log('Errore in FishGame._spawnBubble: $e\n$stackTrace');
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
      _bubbleTimer = 0;
      
      // Rimuovi tutti i nemici esistenti
      children.whereType<EnemyFish>().forEach((enemy) {
        developer.log('FishGame: rimozione pesce nemico');
        enemy.removeFromParent();
      });
      
      children.whereType<OctopusEnemy>().forEach((octopus) {
        developer.log('FishGame: rimozione polipetto');
        octopus.removeFromParent();
      });
      
      children.whereType<BubbleComponent>().forEach((bubble) {
        bubble.removeFromParent();
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

class WaterBackgroundComponent extends Component {
  @override
  Future<void> onLoad() async {
    final topColor = Paint()..color = const Color(0xFF87CEEB); // Azzurro cielo
    final middleColor = Paint()..color = const Color(0xFF4682B4); // Blu acciaio
    final bottomColor = Paint()..color = const Color(0xFF000080); // Blu navy
    
    // Sfondo a gradiente
    final background = GradientBackgroundComponent(
      colors: [topColor.color, middleColor.color, bottomColor.color],
      stops: const [0.0, 0.6, 1.0],
    );
    add(background);
    
    // Aggiungi raggi di luce
    for (int i = 0; i < 5; i++) {
      final x = Random().nextDouble() * 800;
      final lightRay = LightRayComponent(
        position: Vector2(x, 0),
        width: 100 + Random().nextDouble() * 100,
      );
      add(lightRay);
    }
  }
}

class GradientBackgroundComponent extends PositionComponent {
  final List<Color> colors;
  final List<double> stops;
  
  GradientBackgroundComponent({
    required this.colors,
    required this.stops,
  });
  
  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, 800, 600);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(rect);
    
    canvas.drawRect(rect, paint);
  }
}

class LightRayComponent extends PositionComponent {
  final double width;
  
  LightRayComponent({
    required Vector2 position,
    required this.width,
  }) : super(position: position);
  
  @override
  Future<void> onLoad() async {
    final paint = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..style = PaintingStyle.fill;
    
    add(
      RectangleComponent(
        position: Vector2(0, 0),
        size: Vector2(width, 600),
        paint: paint,
      )
      ..add(
        OpacityEffect.to(
          0.3,
          EffectController(
            duration: 3 + Random().nextDouble() * 2,
            reverseDuration: 3 + Random().nextDouble() * 2,
            infinite: true,
          ),
        ),
      ),
    );
  }
}

class BubbleComponent extends PositionComponent {
  static final Paint _bubblePaint = Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.fill;
  
  BubbleComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);
  
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
