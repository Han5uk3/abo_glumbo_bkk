import 'dart:developer';
import 'dart:io';

import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class CachedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final bool autoPlay;
  final bool looping;
  final bool showControls;

  const CachedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = true,
  });

  @override
  State<CachedVideoPlayer> createState() => _CachedVideoPlayerState();
}

class _CachedVideoPlayerState extends State<CachedVideoPlayer> {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      await initializeVideoFromCache(widget.videoUrl);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load video: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> initializeVideoFromCache(String url) async {
    final cachedPath = await downloadVideo(url);
    if (cachedPath != null) {
      _videoController = VideoPlayerController.file(File(cachedPath))
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });

                _videoController!.setLooping(widget.looping);

                if (widget.autoPlay) {
                  _videoController!.play();
                }
              }
            })
            .catchError((error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = 'Failed to initialize video: $error';
                  _isLoading = false;
                });
              }
            });
    } else {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load cached video.';
          _isLoading = false;
        });
      }
      log('Failed to load cached video.');
    }
  }

  Future<String?> downloadVideo(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = url.split('/').last.split('?').first;
      final filePath = '${dir.path}/cached_$fileName';

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      final response = await Dio().download(url, filePath);
      if (response.statusCode == 200) {
        return filePath;
      }
    } catch (e) {
      log('Error downloading video: $e');
    }
    return null;
  }

  void _togglePlayPause() {
    if (_videoController != null) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      setState(() {});
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: widget.width,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildVideoContent(colorScheme),
      ),
    );
  }

  Widget _buildVideoContent(ColorScheme colorScheme) {
    if (_isLoading) {
      return _buildLoadingWidget(colorScheme);
    }

    if (_hasError) {
      return _buildErrorWidget(colorScheme);
    }

    if (_videoController == null || !_videoController!.value.isInitialized) {
      return _buildLoadingWidget(colorScheme);
    }

    return GestureDetector(
      onTap: widget.showControls ? _toggleControls : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),

          // Controls Overlay
          if (widget.showControls && _showControls)
            _buildControlsOverlay(colorScheme),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget(ColorScheme colorScheme) {
    return Container(
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Loader(size: 16, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingVideo,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.failedToLoadVideo,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Failed to load video',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeVideo,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(ColorScheme colorScheme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time Display
                Text(
                  '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),

                // Control Buttons
                Row(
                  children: [
                    IconButton(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final currentPosition =
                            _videoController!.value.position;
                        final newPosition =
                            currentPosition + const Duration(seconds: 5);
                        _videoController!.seekTo(newPosition);
                      },
                      icon: const Icon(Icons.forward_5, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            // Progress Bar
            VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.secondary,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),

            // Control Buttons Row
          ],
        ),
      ),
    );
  }
}
