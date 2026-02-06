import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/catch_goose_game.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catch Goose',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB83B2E)),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final CatchGooseGame _game;

  @override
  void initState() {
    super.initState();
    _game = CatchGooseGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'result': (context, game) => _ResultOverlay(game: game as CatchGooseGame),
        },
      ),
    );
  }
}

class _ResultOverlay extends StatefulWidget {
  const _ResultOverlay({required this.game});

  final CatchGooseGame game;

  @override
  State<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<_ResultOverlay> {
  static const int _autoSeconds = 3;
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _autoSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining -= 1;
      });
      if (_remaining <= 0) {
        timer.cancel();
        _triggerAuto();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _triggerAuto() {
    final game = widget.game;
    if (game.isWin) {
      game.nextLevel();
    } else {
      game.restartLevel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isWin = game.isWin;
    final title = isWin ? '通关成功' : '闯关失败';
    final message = game.resultMessage;
    return Material(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE2B8), Color(0xFFFFF4DE)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0572E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6A4A2D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_remaining}s 后自动${isWin ? '进入下一关' : '重玩'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B6A4B),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1C15B),
                      foregroundColor: const Color(0xFF6A4A2D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => game.restartLevel(),
                    child: const Text('重玩'),
                  ),
                  if (isWin)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0572E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => game.nextLevel(),
                      child: Text(game.hasNextLevel ? '下一关' : '重新开始'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
