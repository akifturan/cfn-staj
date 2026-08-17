import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../widgets/user_avatar.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  bool _holding = false;
  int _elapsedMs = 0;
  Timer? _timer;
  DateTime? _startTime;

  bool _isNewRecord = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() {
      _holding = true;
      _elapsedMs = 0;
      _isNewRecord = false;
      _startTime = DateTime.now();
    });
    _pulseController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_startTime == null) return;
      setState(() {
        _elapsedMs = DateTime.now().difference(_startTime!).inMilliseconds;
      });
    });
  }

  void _onTapUp(TapUpDetails _) => _stopHolding();
  void _onTapCancel() => _stopHolding();

  Future<void> _stopHolding() async {
    if (!_holding) return;
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    final finalMs = _startTime != null
        ? DateTime.now().difference(_startTime!).inMilliseconds
        : _elapsedMs;

    setState(() {
      _holding = false;
      _elapsedMs = finalMs;
    });

    // Check and save record
    final myUid = context.read<AuthProvider>().currentUser!.uid;
    final friendsProvider = context.read<FriendsProvider>();
    final me = await friendsProvider.watchUser(myUid).first;

    final currentBest = me.breathHoldBestMs ?? 0;
    if (finalMs > currentBest) {
      await friendsProvider.updateBreathHoldRecord(myUid, finalMs);
      if (mounted) {
        setState(() => _isNewRecord = true);
      }
    }
  }

  String _formatMs(int ms) {
    final seconds = ms / 1000.0;
    return seconds.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final myUid = context.watch<AuthProvider>().currentUser!.uid;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _holding
                ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)]
                : [cs.surface, cs.surface],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Nefes Tutma Yarışı',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _holding ? Colors.white : cs.onSurface,
                  ),
                ),
              ),
              // Game area
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timer display
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: _holding ? 64 : 48,
                          fontWeight: FontWeight.w700,
                          color: _holding ? Colors.white : cs.onSurface,
                        ),
                        child: Text('${_formatMs(_elapsedMs)}s'),
                      ),
                      const SizedBox(height: 8),
                      if (_isNewRecord && !_holding)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events,
                                  color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Yeni Rekor!',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                      // Hold button
                      GestureDetector(
                        onTapDown: _onTapDown,
                        onTapUp: _onTapUp,
                        onTapCancel: _onTapCancel,
                        child: ScaleTransition(
                          scale: _holding ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _holding
                                    ? [
                                        const Color(0xFF42A5F5),
                                        const Color(0xFF1565C0),
                                      ]
                                    : [
                                        cs.primary,
                                        cs.tertiary,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_holding
                                          ? const Color(0xFF42A5F5)
                                          : cs.primary)
                                      .withValues(alpha: 0.4),
                                  blurRadius: _holding ? 40 : 20,
                                  spreadRadius: _holding ? 4 : 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _holding ? Icons.air : Icons.touch_app,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _holding ? 'Tutuyorsun!' : 'Basılı Tut',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _holding
                            ? 'Nefesini tutmaya devam et...'
                            : 'Butona basılı tutarak başla',
                        style: TextStyle(
                          color: _holding
                              ? Colors.white70
                              : cs.outline,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Leaderboard
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: BackdropFilter(
                    filter: _holding
                        ? ImageFilter.blur(sigmaX: 8, sigmaY: 8)
                        : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _holding
                            ? Colors.white.withValues(alpha: 0.1)
                            : cs.surfaceContainerLow,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              children: [
                                Icon(Icons.leaderboard,
                                    size: 20,
                                    color: _holding
                                        ? Colors.white70
                                        : cs.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Liderlik Tablosu',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _holding
                                        ? Colors.white
                                        : cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<AppUser>(
                              stream: context
                                  .read<FriendsProvider>()
                                  .watchUser(myUid),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                final me = snapshot.data!;
                                return FutureBuilder<List<AppUser>>(
                                  future: context
                                      .read<FriendsProvider>()
                                      .getFriends(me.friends),
                                  builder: (context, friendsSnapshot) {
                                    final friends =
                                        friendsSnapshot.data ?? const [];
                                    final allPlayers = [me, ...friends];

                                    // Sort: highest score first, nulls last
                                    allPlayers.sort((a, b) {
                                      final aMs = a.breathHoldBestMs;
                                      final bMs = b.breathHoldBestMs;
                                      if (aMs == null && bMs == null) return 0;
                                      if (aMs == null) return 1;
                                      if (bMs == null) return -1;
                                      return bMs.compareTo(aMs);
                                    });

                                    return ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      itemCount: allPlayers.length,
                                      itemBuilder: (context, index) {
                                        final player = allPlayers[index];
                                        final isMe = player.uid == myUid;
                                        final bestMs =
                                            player.breathHoldBestMs;
                                        final rank = index + 1;

                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? (_holding
                                                    ? Colors.white
                                                        .withValues(alpha: 0.1)
                                                    : cs.primaryContainer
                                                        .withValues(alpha: 0.3))
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            visualDensity:
                                                VisualDensity.compact,
                                            leading: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 24,
                                                  child: Text(
                                                    rank <= 3
                                                        ? ['🥇', '🥈', '🥉'][
                                                            rank - 1]
                                                        : '$rank',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize:
                                                          rank <= 3 ? 18 : 14,
                                                      color: _holding
                                                          ? Colors.white70
                                                          : cs.outline,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                UserAvatar(
                                                  photoBase64:
                                                      player.photoBase64,
                                                  username: player.username,
                                                  radius: 16,
                                                ),
                                              ],
                                            ),
                                            title: Text(
                                              isMe
                                                  ? '${player.username} (Sen)'
                                                  : player.username,
                                              style: TextStyle(
                                                fontWeight: isMe
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: _holding
                                                    ? Colors.white
                                                    : cs.onSurface,
                                              ),
                                            ),
                                            trailing: Text(
                                              bestMs != null
                                                  ? '${_formatMs(bestMs)}s'
                                                  : 'Henüz oynamadı',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: bestMs != null
                                                    ? (_holding
                                                        ? Colors.white
                                                        : cs.primary)
                                                    : (_holding
                                                        ? Colors.white38
                                                        : cs.outline),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
