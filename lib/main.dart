import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:pescivendolo_game/game/fish_game.dart';
import 'package:pescivendolo_game/game/audio_manager.dart';
import 'package:pescivendolo_game/game/components/water_background.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer' as developer;
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pescivendolo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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

class _GameScreenState extends State<GameScreen> {
  late final FishGame game;
  
  @override
  void initState() {
    super.initState();
    game = FishGame();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // Cattura tutti i tocchi/clic sull'intero schermo
        onTapDown: (_) {
          developer.log('Utente ha interagito con lo schermo');
          AudioManager.setUserInteracted();
        },
        // Assicurati che il GestureDetector copra l'intera area
        behavior: HitTestBehavior.translucent,
        child: GameWidget<FishGame>(
          game: game,
          overlayBuilderMap: {
            'gameOver': (context, game) => GameOverOverlay(game: game),
            'startGame': (context, game) => StartGameOverlay(game: game),
          },
          initialActiveOverlays: const ['startGame'],
          backgroundBuilder: (context) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade300,
                  Colors.blue.shade900,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StartGameOverlay extends StatefulWidget {
  final FishGame game;

  const StartGameOverlay({super.key, required this.game});

  @override
  State<StartGameOverlay> createState() => _StartGameOverlayState();
}

class _StartGameOverlayState extends State<StartGameOverlay> {
  bool _hoveringStartButton = false;
  final List<String> _fishImages = [
    'https://www.pngall.com/wp-content/uploads/5/Tropical-Fish-PNG-Image-HD.png',
    'https://www.pngall.com/wp-content/uploads/5/Tropical-Fish-PNG-Free-Download.png',
    'https://www.pngall.com/wp-content/uploads/5/Tropical-Fish-PNG-Free-Image.png',
    'https://www.pngall.com/wp-content/uploads/5/Tropical-Fish-PNG-Clipart.png',
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return WaterBackground(
      child: Stack(
        children: [
          // Effetto particelle di bolle
          Positioned.fill(
            child: _buildBubbleEffect(screenSize),
          ),
          
          // Pesci decorativi animati
          ..._buildDecoFish(),
          
          // Contenuto principale
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
                const SizedBox(height: 40),
                
                // Istruzioni con animazione di fade-in
                Container(
                  padding: const EdgeInsets.all(20),
                  width: 400,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Istruzioni:',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInstructionRow(
                        Icons.keyboard_arrow_up, 
                        'Usa i tasti WASD o le frecce direzionali per muoverti'
                      ),
                      _buildInstructionRow(
                        Icons.catching_pokemon, 
                        'Mangia i pesci verdi (sicuri) per guadagnare punti'
                      ),
                      _buildInstructionRow(
                        Icons.dangerous, 
                        'Evita i pesci rossi (pericolosi) e i polipetti'
                      ),
                      _buildInstructionRow(
                        Icons.favorite, 
                        'Hai 3 vite, non sprecarle!'
                      ),
                    ],
                  ).animate().fadeIn(duration: 800.ms, delay: 300.ms),
                ),
                const SizedBox(height: 40),
                
                // Pulsante START GAME con effetto hover
                MouseRegion(
                  onEnter: (_) => setState(() => _hoveringStartButton = true),
                  onExit: (_) => setState(() => _hoveringStartButton = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: _hoveringStartButton 
                      ? (Matrix4.identity()..scale(1.1))
                      : Matrix4.identity(),
                    child: ElevatedButton(
                      onPressed: () {
                        // Imposta il flag di interazione utente
                        AudioManager.setUserInteracted();
                        
                        // Avvia il gioco
                        widget.game.startGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hoveringStartButton 
                          ? Colors.green.shade400 
                          : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        elevation: _hoveringStartButton ? 15 : 10,
                        shadowColor: Colors.black.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('START GAME'),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.play_arrow,
                            size: 28,
                            color: Colors.white,
                          ).animate(
                            onPlay: (controller) => controller.repeat(),
                          ).shimmer(
                            duration: 1.5.seconds,
                            delay: 500.ms,
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(
                  begin: 0.5, 
                  end: 0, 
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
                
                // Versione
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBubbleEffect(Size screenSize) {
    return Stack(
      children: List.generate(
        50,
        (index) {
          final random = math.Random();
          final size = random.nextDouble() * 20 + 5;
          final posX = random.nextDouble() * screenSize.width;
          final posY = random.nextDouble() * screenSize.height;
          final duration = (random.nextDouble() * 10 + 5).seconds;
          
          return Positioned(
            left: posX,
            top: posY,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(),
            ).moveY(
              begin: 0,
              end: -screenSize.height,
              duration: duration,
              curve: Curves.linear,
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildInstructionRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildDecoFish() {
    final random = math.Random();
    final screenSize = MediaQuery.of(context).size;
    
    return List.generate(
      6,
      (index) {
        final size = random.nextDouble() * 80 + 40;
        final posX = random.nextDouble() * screenSize.width;
        final posY = random.nextDouble() * screenSize.height;
        final duration = (random.nextDouble() * 20 + 10).seconds;
        final delay = (random.nextDouble() * 5).seconds;
        final imageIndex = random.nextInt(_fishImages.length);
        
        return Positioned(
          left: posX,
          top: posY,
          child: SizedBox(
            width: size,
            height: size * 0.6,
            child: CachedNetworkImage(
              imageUrl: _fishImages[imageIndex],
              placeholder: (context, url) => Container(),
              errorWidget: (context, url, error) => Container(),
            ),
          ).animate(
            onPlay: (controller) => controller.repeat(),
          ).moveX(
            begin: 0,
            end: screenSize.width * 0.8,
            duration: duration,
            delay: delay,
            curve: Curves.easeInOut,
          ).then().moveX(
            begin: screenSize.width * 0.8,
            end: -size,
            duration: duration,
            curve: Curves.easeInOut,
          ).then().moveX(
            begin: screenSize.width,
            end: 0,
            duration: duration,
            curve: Curves.easeInOut,
          ),
        );
      },
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
  bool _hoveringRetryButton = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titolo Game Over con animazione
            AnimatedTextKit(
              animatedTexts: [
                FlickerAnimatedText(
                  'GAME OVER',
                  textStyle: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black,
                        offset: Offset(3.0, 3.0),
                      ),
                    ],
                  ),
                  speed: const Duration(milliseconds: 1000),
                ),
              ],
              isRepeatingAnimation: true,
              repeatForever: true,
            ),
            const SizedBox(height: 30),
            
            // Punteggio con animazione di conteggio
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Punteggio: ',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AnimatedTextKit(
                  animatedTexts: [
                    ScaleAnimatedText(
                      '${widget.game.score}',
                      textStyle: const TextStyle(
                        fontSize: 28,
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                      ),
                      duration: const Duration(milliseconds: 1000),
                    ),
                  ],
                  totalRepeatCount: 1,
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            // Pulsante RIPROVA con effetto hover
            MouseRegion(
              onEnter: (_) => setState(() => _hoveringRetryButton = true),
              onExit: (_) => setState(() => _hoveringRetryButton = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: _hoveringRetryButton 
                  ? (Matrix4.identity()..scale(1.1))
                  : Matrix4.identity(),
                child: ElevatedButton(
                  onPressed: () {
                    // Impostiamo il flag di interazione utente
                    AudioManager.setUserInteracted();
                    
                    // Rimuoviamo l'overlay prima di resettare il gioco
                    // Questo evita la doppia rimozione che potrebbe causare problemi
                    widget.game.overlays.remove('gameOver');
                    
                    // Resettiamo il gioco dopo un breve ritardo per assicurarci
                    // che l'overlay sia stato completamente rimosso
                    Future.delayed(const Duration(milliseconds: 100), () {
                      // Reset game
                      widget.game.reset();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hoveringRetryButton 
                      ? Colors.green.shade400 
                      : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    elevation: _hoveringRetryButton ? 15 : 10,
                    shadowColor: Colors.black.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('RIPROVA'),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.refresh,
                        size: 24,
                        color: Colors.white,
                      ).animate(
                        onPlay: (controller) => controller.repeat(),
                      ).rotate(
                        duration: 1.5.seconds,
                        begin: 0,
                        end: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              duration: 500.ms,
              curve: Curves.elasticOut,
            ),
          ],
        ),
      ),
    );
  }
}
