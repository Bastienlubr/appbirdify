import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class SimpleAudioPlayer extends StatefulWidget {
  final String audioPath;

  const SimpleAudioPlayer({
    super.key,
    required this.audioPath,
  });

  @override
  State<SimpleAudioPlayer> createState() => _SimpleAudioPlayerState();
}

class _SimpleAudioPlayerState extends State<SimpleAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      // Vérifier si c'est une URL HTTP ou un fichier local
      if (widget.audioPath.startsWith('http')) {
        await _audioPlayer.setUrl(widget.audioPath);
      } else {
        await _audioPlayer.setAsset(widget.audioPath);
      }
      // Lecture automatique au chargement
      await _audioPlayer.play();
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement audio: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFF6A994E),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _togglePlayPause,
        icon: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          size: 32,
          color: const Color(0xFF6A994E),
        ),
      ),
    );
  }
}
