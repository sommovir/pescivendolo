import 'dart:math';
import 'dart:async' as darts;
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/components/water_background.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

void main() {
  // Assicurati che il binding sia inizializzato
  WidgetsFlutterBinding.ensureInitialized();
  
  // Permetti sia portrait che landscape orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pescivendolo Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late FishGame _game;
  bool _isFullScreen = false;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    _game = FishGame();
    
    // Registra l'observer per i cambiamenti di orientamento
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    // Rimuovi l'observer quando il widget viene distrutto
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Ora possiamo controllare l'orientamento in modo sicuro
    _checkOrientation();
  }
  
  @override
  void didChangeMetrics() {
    // Questo metodo viene chiamato quando cambiano le metriche (incluso l'orientamento)
    super.didChangeMetrics();
    _checkOrientation();
  }
  
  void _checkOrientation() {
    // Verifichiamo che il context sia montato prima di usare MediaQuery
    if (!mounted) return;
    
    // Controlla se siamo in modalità landscape
    final orientation = MediaQuery.of(context).orientation;
    final newIsLandscape = orientation == Orientation.landscape;
    
    if (_isLandscape != newIsLandscape) {
      setState(() {
        _isLandscape = newIsLandscape;
      });
      
      // Aggiorna il gioco con la nuova orientazione
      _updateGameBasedOnOrientation();
    }
  }
  
  void _updateGameBasedOnOrientation() {
    // Aggiorna il gioco in base all'orientamento
    if (_game.isLoaded) {
      _game.updateOrientation(_isLandscape);
      
      // Forza l'aggiornamento delle dimensioni del gioco
      _updateGameSize();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget<FishGame>(
            game: _game,
            loadingBuilder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorBuilder: (context, error) => Center(
              child: Text(
                'Si è verificato un errore: $error',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                ),
              ),
            ),
            overlayBuilderMap: {
              'startGame': (context, game) => StartGameOverlay(game: game),
              'gameOver': (context, game) => GameOverOverlay(game: game),
              'gameHud': (context, game) => GameHudOverlay(game: game),
              'touchControls': (context, game) => TouchControlsOverlay(game: game),
            },
            initialActiveOverlays: const ['startGame'],
          ),
          
          // Pulsante Fullscreen
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {
                _toggleFullScreen();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _toggleFullScreen() {
    try {
      // Preserva gli overlay attivi prima di togglefare il fullscreen
      final activeOverlays = _game.overlays.activeOverlays.toList();
      
      // Aggiorna lo stato fullscreen
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
      
      // Applica il fullscreen
      if (_isFullScreen) {
        html.document.documentElement?.requestFullscreen();
      } else {
        html.document.exitFullscreen();
      }
      
      // Piccolo ritardo per assicurarsi che lo stato del DOM sia aggiornato
      Future.delayed(const Duration(milliseconds: 100), () {
        // Assicurati che gli stessi overlay siano attivi dopo il toggle
        _game.overlays.clear();
        for (final overlay in activeOverlays) {
          _game.overlays.add(overlay);
        }
        
        // Forza l'aggiornamento delle dimensioni del gioco
        _updateGameSize();
      });
    } catch (e) {
      print('Errore nel toggle fullscreen: $e');
    }
  }
  
  // Metodo per aggiornare le dimensioni del gioco
  void _updateGameSize() {
    // Ottieni le dimensioni correnti della finestra
    final windowWidth = html.window.innerWidth ?? 0;
    final windowHeight = html.window.innerHeight ?? 0;
    
    // Usa la resize API di Flame per impostare le nuove dimensioni
    _game.onGameResize(Vector2(windowWidth.toDouble(), windowHeight.toDouble()));
    
    // Se necessario, aggiorna anche le dimensioni del canvas/container
    final canvasElement = html.document.getElementById('gameCanvas') as html.CanvasElement?;
    if (canvasElement != null) {
      canvasElement.width = windowWidth;
      canvasElement.height = windowHeight;
    }
    
    // Forza un ridisegno del gioco
    _game.resumeEngine();
  }
}

class StartGameOverlay extends StatefulWidget {
  final FishGame game;

  const StartGameOverlay({super.key, required this.game});

  @override
  State<StartGameOverlay> createState() => _StartGameOverlayState();
}

class _StartGameOverlayState extends State<StartGameOverlay> with TickerProviderStateMixin {
  bool _hoveringStartButton = false;
  late darts.Timer _fishMoveTimer;
  late AnimationController _bubbleAnimationController;
  
  // Immagini dei pesci dagli assets
  final List<String> _fishImages = [
    'assets/images/enemy_fish.png',
    'assets/images/good_fish.png',
    'assets/images/polipetto.png',
    'assets/images/medusa.png',
    'assets/images/murena-elettrica.png',
  ];
  
  // Lista dei pesci animati
  final List<FishAnimation> _fishAnimations = [];
  // Lista di bolle per l'animazione naturale
  final List<NaturalBubble> _naturalBubbles = [];
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    
    // Inizializza le bolle naturali
    _initializeNaturalBubbles();
    
    // Controller per l'animazione delle bolle
    _bubbleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() {
      _updateBubblePositions();
    });
    
    // Avvia l'animazione delle bolle
    _bubbleAnimationController.repeat();
    
    // Crea pesci con posizioni casuali
    _initializeFishAnimations();
    
    // Avvia il timer per muovere i pesci
    _fishMoveTimer = darts.Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateFishPositions();
    });
  }
  
  @override
  void dispose() {
    _fishMoveTimer.cancel();
    _bubbleAnimationController.dispose();
    super.dispose();
  }
  
  void _initializeNaturalBubbles() {
    // Crea un numero appropriato di bolle con posizioni casuali
    for (int i = 0; i < 20; i++) {
      _naturalBubbles.add(NaturalBubble(
        x: _random.nextDouble() * 1000,
        y: _random.nextDouble() * 800 + 200, // Inizia da sotto lo schermo
        radius: _random.nextDouble() * 6 + 3, // Dimensioni varie ma non troppo grandi
        speed: _random.nextDouble() * 0.5 + 0.2, // Molto lento
        opacity: _random.nextDouble() * 0.3 + 0.2, // Semitrasparente
        wobble: _random.nextDouble() * 0.5, // Leggero movimento laterale
      ));
    }
  }
  
  void _updateBubblePositions() {
    setState(() {
      for (final bubble in _naturalBubbles) {
        // Movimento verso l'alto
        bubble.y -= bubble.speed;
        
        // Leggero movimento laterale (wobble)
        bubble.x += sin(bubble.y * 0.05) * bubble.wobble;
        
        // Se la bolla esce dallo schermo in alto, la riposiziona in basso
        if (bubble.y < -bubble.radius * 2) {
          bubble.y = 800 + bubble.radius * 2;
          bubble.x = _random.nextDouble() * 1000;
          bubble.radius = _random.nextDouble() * 6 + 3;
          bubble.speed = _random.nextDouble() * 0.5 + 0.2;
          bubble.opacity = _random.nextDouble() * 0.3 + 0.2;
        }
      }
    });
  }
  
  void _initializeFishAnimations() {
    final random = Random();
    
    // Crea 12 pesci con posizioni e velocità casuali
    for (int i = 0; i < 12; i++) {
      final fishType = random.nextInt(_fishImages.length);
      // Aumento la dimensione dei pesci di sfondo
      final size = random.nextDouble() * 60 + 60; 
      final speed = random.nextDouble() * 60 + 40; // Velocità in pixel al secondo
      
      _fishAnimations.add(FishAnimation(
        image: _fishImages[fishType],
        size: size,
        speed: speed,
        posY: random.nextDouble() * 800,
        posX: random.nextDouble() * 1200 + 800, // Posizione iniziale fuori dallo schermo a destra
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return WaterBackground(
      child: Stack(
        children: [
          // Strato più basso: pesci decorativi
          ..._buildDecoFish(screenSize),
          
          // Strato intermedio: bolle naturali
          ..._buildNaturalBubbles(),
          
          // Strato superiore: contenuto principale (UI)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Titolo del gioco animato
                AnimatedTextKit(
                  animatedTexts: [
                    WavyAnimatedText(
                      'PESCIVENDOLO',
                      textStyle: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(5.0, 5.0),
                          ),
                        ],
                      ),
                      speed: const Duration(milliseconds: 200),
                    ),
                  ],
                  isRepeatingAnimation: true,
                  repeatForever: true,
                ),
                const SizedBox(height: 20),
                
                // Sottotitolo con effetto di digitazione
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'L\'avventura sottomarina',
                      textStyle: const TextStyle(
                        fontSize: 24,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 5.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      speed: const Duration(milliseconds: 100),
                    ),
                  ],
                  totalRepeatCount: 1,
                ),
                const SizedBox(height: 60),
                
                // Card con pulsante
                Container(
                  width: 320,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade800,
                        Colors.blue.shade600,
                        Colors.teal.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.lightBlue.shade300,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Pulsante START GAME con effetto hover
                      MouseRegion(
                        onEnter: (_) => setState(() => _hoveringStartButton = true),
                        onExit: (_) => setState(() => _hoveringStartButton = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: _hoveringStartButton 
                            ? (Matrix4.identity()..scale(1.1))
                            : Matrix4.identity(),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Stack(
                              children: [
                                // Pulsante base
                                ElevatedButton(
                                  onPressed: () {
                                    // Imposta il flag di interazione utente
                                    AudioManager.setUserInteracted();
                                    
                                    // Avvia il gioco
                                    widget.game.startGame();
                                    
                                    // Attiva gli overlay necessari
                                    widget.game.overlays.add('gameHud');
                                    
                                    // Se siamo su mobile/tablet, mostra i controlli touch
                                    if (MediaQuery.of(context).size.width < 768) {
                                      widget.game.overlays.add('touchControls');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                    textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: _hoveringStartButton ? 10 : 5,
                                    shadowColor: Colors.orange.shade900,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_arrow, size: 30),
                                      const SizedBox(width: 10),
                                      const Text('GIOCA'),
                                    ],
                                  ),
                                ),
                                
                                // Effetto di brillantezza con la stessa forma arrotondata
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container()
                                      .animate(
                                        onPlay: (controller) => controller.repeat(),
                                      )
                                      .shimmer(
                                        duration: 2000.ms,
                                        color: Colors.white.withOpacity(0.4),
                                        angle: 45,
                                        size: 1.5,
                                      ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Breve istruzione
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          MediaQuery.of(context).size.width < 768 
                              ? 'Usa il joystick per muoverti' 
                              : 'Usa WASD o frecce per muoverti',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Versione e sviluppatore
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      const Text(
                        'v1.2.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Sviluppato da "esistente-a-tratti"',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildDecoFish(Size screenSize) {
    final List<Widget> fishWidgets = [];
    
    for (final fish in _fishAnimations) {
      fishWidgets.add(
        Positioned(
          left: fish.posX,
          top: fish.posY,
          child: Image.asset(
            fish.image,
            width: fish.size,
            height: fish.size * 0.75,
          ),
        ),
      );
    }
    
    return fishWidgets;
  }
  
  void _updateFishPositions() {
    for (final fish in _fishAnimations) {
      fish.posX -= fish.speed / 60; // Muove il pesce da destra a sinistra
      
      // Se il pesce esce dallo schermo a sinistra, lo riposiziona a destra
      if (fish.posX < -fish.size) {
        fish.posX = 1200 + fish.size;
        fish.posY = Random().nextDouble() * 800;
      }
    }
    
    setState(() {});
  }
  
  // Funzione per verificare se siamo su un dispositivo mobile
  bool _isMobileDevice(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Considera mobile se la larghezza è inferiore a 768px o se è un dispositivo touch
    return mediaQuery.size.width < 768;
  }
  
  // Costruisce le bolle naturali
  List<Widget> _buildNaturalBubbles() {
    final List<Widget> bubbleWidgets = [];
    
    for (final bubble in _naturalBubbles) {
      bubbleWidgets.add(
        Positioned(
          left: bubble.x,
          top: bubble.y,
          child: Container(
            width: bubble.radius * 2,
            height: bubble.radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(bubble.opacity),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(bubble.opacity * 0.5),
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(bubble.radius * 0.3),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: bubble.radius * 0.5,
                  height: bubble.radius * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(bubble.opacity + 0.3),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return bubbleWidgets;
  }
}

class FishAnimation {
  String image;
  double size;
  double speed;
  double posY;
  double posX;
  
  FishAnimation({
    required this.image,
    required this.size,
    required this.speed,
    required this.posY,
    required this.posX,
  });
}

class NaturalBubble {
  double x;
  double y;
  double radius;
  double speed;
  double opacity;
  double wobble;
  
  NaturalBubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
    required this.wobble,
  });
}

// Overlay per il joystick e controlli touch
class TouchControlsOverlay extends StatefulWidget {
  final FishGame game;

  const TouchControlsOverlay({super.key, required this.game});

  @override
  State<TouchControlsOverlay> createState() => _TouchControlsOverlayState();
}

class _TouchControlsOverlayState extends State<TouchControlsOverlay> {
  // Posizione del joystick
  Offset _joystickPosition = Offset.zero;
  Offset _basePosition = const Offset(100, 500); // Posizione base del joystick
  bool _isDragging = false;
  
  // Raggio del joystick
  final double _joystickRadius = 50.0;
  final double _handleRadius = 20.0;
  
  @override
  Widget build(BuildContext context) {
    // Adatta la posizione del joystick in base all'orientamento
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Posiziona il joystick in base all'orientamento
    if (isLandscape) {
      _basePosition = Offset(150, screenSize.height / 2); // A sinistra al centro in landscape
    } else {
      _basePosition = Offset(100, screenSize.height - 150); // In basso a sinistra in portrait
    }
    
    return Positioned.fill(
      child: GestureDetector(
        onPanStart: (details) {
          if (_isWithinJoystick(details.localPosition)) {
            setState(() {
              _isDragging = true;
              _updateJoystickPosition(details.localPosition);
            });
          }
        },
        onPanUpdate: (details) {
          if (_isDragging) {
            setState(() {
              _updateJoystickPosition(details.localPosition);
            });
          }
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
            _joystickPosition = Offset.zero;
            
            // Ferma il movimento del pesce
            widget.game.player.moveUp(false);
            widget.game.player.moveDown(false);
            widget.game.player.moveLeft(false);
            widget.game.player.moveRight(false);
          });
        },
        child: CustomPaint(
          painter: JoystickPainter(
            basePosition: _basePosition,
            joystickPosition: _isDragging ? _basePosition + _joystickPosition : _basePosition,
            baseRadius: _joystickRadius,
            handleRadius: _handleRadius,
          ),
        ),
      ),
    );
  }
  
  bool _isWithinJoystick(Offset position) {
    return (position - _basePosition).distance <= _joystickRadius;
  }
  
  void _updateJoystickPosition(Offset position) {
    // Calcola la posizione relativa rispetto al centro del joystick
    Offset newPosition = position - _basePosition;
    
    // Limita la distanza massima dal centro
    if (newPosition.distance > _joystickRadius) {
      newPosition = newPosition * (_joystickRadius / newPosition.distance);
    }
    
    _joystickPosition = newPosition;
    
    // Aggiorna il movimento del pesce in base alla posizione del joystick
    final double threshold = 0.3 * _joystickRadius;
    
    widget.game.player.moveUp(_joystickPosition.dy < -threshold);
    widget.game.player.moveDown(_joystickPosition.dy > threshold);
    widget.game.player.moveLeft(_joystickPosition.dx < -threshold);
    widget.game.player.moveRight(_joystickPosition.dx > threshold);
  }
}

// Painter per disegnare il joystick
class JoystickPainter extends CustomPainter {
  final Offset basePosition;
  final Offset joystickPosition;
  final double baseRadius;
  final double handleRadius;
  
  JoystickPainter({
    required this.basePosition,
    required this.joystickPosition,
    required this.baseRadius,
    required this.handleRadius,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Disegna la base del joystick
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(basePosition, baseRadius, basePaint);
    
    // Disegna il bordo della base
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(basePosition, baseRadius, borderPaint);
    
    // Disegna il manico del joystick
    final handlePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(joystickPosition, handleRadius, handlePaint);
    
    // Disegna il bordo del manico
    final handleBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(joystickPosition, handleRadius, handleBorderPaint);
  }
  
  @override
  bool shouldRepaint(covariant JoystickPainter oldDelegate) {
    return basePosition != oldDelegate.basePosition ||
           joystickPosition != oldDelegate.joystickPosition;
  }
}

// Overlay per il HUD di gioco con timer
class GameHudOverlay extends StatefulWidget {
  final FishGame game;

  const GameHudOverlay({super.key, required this.game});

  @override
  State<GameHudOverlay> createState() => _GameHudOverlayState();
}

class _GameHudOverlayState extends State<GameHudOverlay> {
  int _seconds = 0;
  int _minutes = 0;
  darts.Timer? _gameTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Avvia timer per il tempo di gioco
    _gameTimer = darts.Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        if (_seconds >= 60) {
          _seconds = 0;
          _minutes++;
        }
      });
    });
  }
  
  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Formatta il tempo trascorso in minuti:secondi
    final minutes = _minutes.toString().padLeft(2, '0');
    final seconds = _seconds.toString().padLeft(2, '0');
    final timeString = '$minutes:$seconds';
    
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                timeString,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatefulWidget {
  final FishGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _hoveringRestartButton = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game Over Text
            const Text(
              'GAME OVER',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.red,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black,
                    offset: Offset(5.0, 5.0),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
            ),
            const SizedBox(height: 20),
            
            // Score
            Text(
              'Punteggio: ${widget.game.score}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
            const SizedBox(height: 40),
            
            // Restart Button
            MouseRegion(
              onEnter: (_) => setState(() => _hoveringRestartButton = true),
              onExit: (_) => setState(() => _hoveringRestartButton = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: _hoveringRestartButton 
                  ? (Matrix4.identity()..scale(1.1))
                  : Matrix4.identity(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          widget.game.reset();
                          
                          // Riattiva l'HUD
                          widget.game.overlays.add('gameHud');
                          
                          // Se siamo su mobile/tablet, riattiva i controlli touch
                          if (MediaQuery.of(context).size.width < 768) {
                            widget.game.overlays.add('touchControls');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: _hoveringRestartButton ? 10 : 5,
                          shadowColor: Colors.blue.shade900,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.replay, size: 30),
                            const SizedBox(width: 10),
                            const Text('RIPROVA'),
                          ],
                        ),
                      ),
                      
                      // Effetto di brillantezza con la stessa forma arrotondata
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Container()
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .shimmer(
                              duration: 2000.ms,
                              color: Colors.white.withOpacity(0.3),
                              angle: 45,
                              size: 1.5,
                            ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
            ),
            
            // Versione
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: const Text(
                'v1.2.0',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
