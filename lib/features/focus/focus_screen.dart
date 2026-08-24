import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/focus_queue_store.dart';
import '../../data/notification_store.dart';
import '../../data/song_store.dart';
import '../../data/task_store.dart';
import '../../models/task_item.dart';
import '../../widgets/cards/task_card.dart';
import '../../widgets/common/app_top_bar.dart';
import '../shop/shop_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  bool pomodoro = true;
  bool isPlaying = false;
  bool _timerRunning = false;
  bool _isBreak = false;
  double volume = 0.6;
  double _customMinutes = 45;
  Song? _currentSong;
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _sessionDuration = const Duration(minutes: 25);
  Duration _remaining = const Duration(minutes: 25);
  DateTime? _endsAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SongStore.instance.initialize();
    _player.setReleaseMode(ReleaseMode.stop);
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        isPlaying = state == PlayerState.playing;
      });
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _position = Duration.zero;
        isPlaying = false;
      });
    });
    _player.setVolume(volume);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(NotificationStore.instance.cancelFocusNotification());
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _timerRunning) {
      _updateRemaining();
    }
  }

  Future<void> _toggleTimer() async {
    if (_timerRunning) {
      _pauseTimer();
      return;
    }

    if (_remaining <= Duration.zero) {
      _resetTimer();
    }
    _endsAt = DateTime.now().add(_remaining);
    setState(() => _timerRunning = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
    await NotificationStore.instance.scheduleFocusComplete(_remaining);
  }

  void _pauseTimer() {
    _updateRemaining();
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    if (mounted) setState(() => _timerRunning = false);
    unawaited(NotificationStore.instance.cancelFocusNotification());
  }

  void _updateRemaining() {
    final end = _endsAt;
    if (!_timerRunning || end == null) return;
    final difference = end.difference(DateTime.now());
    if (difference > Duration.zero) {
      if (mounted) setState(() => _remaining = difference);
      return;
    }
    _finishTimer();
  }

  void _finishTimer() {
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    final completedBreak = _isBreak;
    setState(() {
      _timerRunning = false;
      _isBreak = !completedBreak;
      _sessionDuration = completedBreak
          ? _focusDuration
          : const Duration(minutes: 5);
      _remaining = _sessionDuration;
    });
    unawaited(NotificationStore.instance.completeFocusNotification());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          completedBreak
              ? 'Break finished. Ready for another focus round?'
              : 'Focus round complete. Time for a 5-minute break.',
        ),
      ),
    );
  }

  Duration get _focusDuration =>
      Duration(minutes: pomodoro ? 25 : _customMinutes.round());

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    setState(() {
      _timerRunning = false;
      _isBreak = false;
      _sessionDuration = _focusDuration;
      _remaining = _sessionDuration;
    });
    unawaited(NotificationStore.instance.cancelFocusNotification());
  }

  void _skipBreak() {
    if (!_isBreak) return;
    _resetTimer();
  }

  void _setTimerMode(bool usePomodoro) {
    if (pomodoro == usePomodoro) return;
    setState(() => pomodoro = usePomodoro);
    _resetTimer();
  }

  Future<void> _playSong(Song song) async {
    setState(() => _currentSong = song);
    await _player.stop();
    if (song.kind == SongSourceKind.asset) {
      final assetPath = song.source.startsWith('assets/')
          ? song.source.substring('assets/'.length)
          : song.source;
      await _player.play(AssetSource(assetPath));
    } else {
      await _player.play(DeviceFileSource(song.source));
    }
  }

  Future<void> _togglePlayPause() async {
    if (_currentSong == null) {
      await _openSongPicker();
      return;
    }
    if (isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _openSongPicker() async {
    final picked = await showModalBottomSheet<Song>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return _SongPickerSheet(scrollController: scrollController);
          },
        );
      },
    );
    if (picked != null) {
      await _playSong(picked);
    }
  }

  Future<void> _importSong() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;
    await SongStore.instance.addImportedSong(filePath: path, title: file.name);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Imported "${file.name}".')));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _timerLabel {
    final totalSeconds = _remaining.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: AppTopBar(
            title: 'Focus',
            onShopTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: _sessionDuration.inMilliseconds == 0
                                ? 0
                                : (_remaining.inMilliseconds /
                                          _sessionDuration.inMilliseconds)
                                      .clamp(0.0, 1.0),
                            strokeWidth: 10,
                            backgroundColor: AppColors.divider,
                            color: AppColors.burntOrange,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              _timerLabel,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isBreak ? 'Break' : 'Focus',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _toggleTimer,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.burntOrange,
                          foregroundColor: AppColors.white,
                        ),
                        child: Text(
                          _timerRunning
                              ? 'Pause'
                              : _remaining == _sessionDuration
                              ? 'Start'
                              : 'Resume',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resetTimer,
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isBreak ? _skipBreak : null,
                            child: const Text('Skip Break'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            selected: pomodoro,
                            label: const Center(child: Text('Pomodoro')),
                            onSelected: (_) => _setTimerMode(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            selected: !pomodoro,
                            label: const Center(child: Text('Custom')),
                            onSelected: (_) => _setTimerMode(false),
                          ),
                        ),
                      ],
                    ),
                    if (!pomodoro) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Focus length',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text('${_customMinutes.round()} min'),
                        ],
                      ),
                      Slider(
                        value: _customMinutes,
                        min: 5,
                        max: 90,
                        divisions: 17,
                        label: '${_customMinutes.round()} minutes',
                        onChanged: _timerRunning
                            ? null
                            : (value) {
                                setState(() {
                                  _customMinutes = value;
                                  _sessionDuration = _focusDuration;
                                  _remaining = _sessionDuration;
                                });
                              },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Music Player',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Import song',
                          onPressed: _importSong,
                          icon: const Icon(Icons.file_upload_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _openSongPicker,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF3E8), Color(0xFFFFE2C8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardStroke),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.burntOrange.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: AppColors.burntOrange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentSong?.title ??
                                        'Tap to choose a song',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currentSong == null
                                        ? 'Pick from bundled or imported tracks'
                                        : (_currentSong!.kind ==
                                                  SongSourceKind.asset
                                              ? 'Bundled'
                                              : 'Imported'),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.expand_more_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentSong != null)
                      Row(
                        children: [
                          Text(
                            _fmt(_position),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Expanded(
                            child: Slider(
                              value: _duration.inMilliseconds == 0
                                  ? 0
                                  : _position.inMilliseconds
                                        .clamp(0, _duration.inMilliseconds)
                                        .toDouble(),
                              max: _duration.inMilliseconds == 0
                                  ? 1
                                  : _duration.inMilliseconds.toDouble(),
                              onChanged: (value) async {
                                await _player.seek(
                                  Duration(milliseconds: value.round()),
                                );
                              },
                              activeColor: AppColors.burntOrange,
                            ),
                          ),
                          Text(
                            _fmt(_duration),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _currentSong == null
                              ? null
                              : () async {
                                  await _player.seek(Duration.zero);
                                },
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: _togglePlayPause,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: AppColors.burntOrange,
                            foregroundColor: AppColors.white,
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: _openSongPicker,
                          icon: const Icon(Icons.queue_music_rounded),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.volume_down_rounded, size: 18),
                        Expanded(
                          child: Slider(
                            value: volume,
                            onChanged: (value) async {
                              setState(() => volume = value);
                              await _player.setVolume(value);
                            },
                            activeColor: AppColors.burntOrange,
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FocusQueueCard(
                onToggleComplete: (task, done) async {
                  if (task.hasProject && task.projectId != null) {
                    await TaskStore.instance.setProjectTaskCompletion(
                      projectId: task.projectId!,
                      taskId: task.id,
                      done: done,
                    );
                  } else {
                    await TaskStore.instance.setCompletion(task.id, done);
                  }
                  FocusQueueStore.instance.markTaskCompletion(task.id, done);
                },
                onRemove: (id) {
                  FocusQueueStore.instance.remove(id);
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SongPickerSheet extends StatelessWidget {
  const _SongPickerSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Song>>(
      valueListenable: SongStore.instance.songs,
      builder: (context, songs, _) {
        final bundled = songs
            .where((s) => s.kind == SongSourceKind.asset)
            .toList();
        final imported = songs
            .where((s) => s.kind == SongSourceKind.file)
            .toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Choose a song',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.audio,
                        allowMultiple: false,
                      );
                      if (result == null || result.files.isEmpty) return;
                      final file = result.files.single;
                      final path = file.path;
                      if (path == null) return;
                      await SongStore.instance.addImportedSong(
                        filePath: path,
                        title: file.name,
                      );
                    },
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: songs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No songs yet. Drop audio files into assets/songs/ '
                            'and rebuild, or tap Import to add a song from your device.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        children: [
                          if (bundled.isNotEmpty) ...[
                            _SectionTitle(text: 'Bundled (${bundled.length})'),
                            for (final song in bundled)
                              _SongTile(
                                song: song,
                                onTap: () => Navigator.of(context).pop(song),
                              ),
                            const SizedBox(height: 8),
                          ],
                          if (imported.isNotEmpty) ...[
                            _SectionTitle(
                              text: 'Imported (${imported.length})',
                            ),
                            for (final song in imported)
                              _SongTile(
                                song: song,
                                onTap: () => Navigator.of(context).pop(song),
                                onRemove: () =>
                                    SongStore.instance.removeSong(song.id),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.onTap, this.onRemove});

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.burntOrange.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          song.kind == SongSourceKind.asset
              ? Icons.album_rounded
              : Icons.music_note_rounded,
          color: AppColors.burntOrange,
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.kind == SongSourceKind.asset ? 'Bundled' : _filename(song.source),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
      onTap: onTap,
    );
  }

  String _filename(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }
}

class _FocusQueueCard extends StatelessWidget {
  const _FocusQueueCard({
    required this.onToggleComplete,
    required this.onRemove,
  });

  final Future<void> Function(TaskItem task, bool done) onToggleComplete;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ValueListenableBuilder<List<TaskItem>>(
        valueListenable: FocusQueueStore.instance.queue,
        builder: (context, queue, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Queue',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep working here without leaving Focus mode.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (queue.isEmpty)
                Text(
                  'No queued tasks yet. Add tasks from the Tasks page.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                for (final task in queue)
                  Dismissible(
                    key: ValueKey('focus-${task.id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => onRemove(task.id),
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: AppColors.tomatoRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.white,
                      ),
                    ),
                    child: TaskCard(
                      task: task,
                      onToggleComplete: (done) => onToggleComplete(task, done),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
