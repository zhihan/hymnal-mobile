import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:dart_midi_pro/dart_midi_pro.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service for playing MIDI files with transposition support
class MidiPlayerService {
  final MidiPro _midiPro = MidiPro();
  bool _isInitialized = false;
  bool _isPlaying = false;
  MidiFile? _currentMidiFile;
  int _currentTransposeOffset = 0;
  Timer? _playbackTimer;
  int _currentEventIndex = 0;
  List<_TimedMidiEvent>? _timedEvents;
  final Set<String> _activeNotes = {}; // Track active notes as "channel:note"
  int _soundfontId = 0; // Soundfont ID returned by loadSoundfont
  bool _isProcessingEvents = false; // Prevent concurrent event processing
  DateTime? _playbackStartTime;

  /// Check if currently playing
  bool get isPlaying => _isPlaying;

  /// Initialize the MIDI player with a soundfont
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('=== MIDI Player: Loading soundfont ===');

      // Manually load the soundfont from assets and write to temp file
      // This approach works better on iOS
      final ByteData data = await rootBundle.load('assets/soundfont.sf2');
      print('=== MIDI Player: Asset loaded, size: ${data.lengthInBytes} bytes ===');

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/soundfont.sf2');

      print('=== MIDI Player: Writing to temp file: ${tempFile.path} ===');
      await tempFile.writeAsBytes(data.buffer.asUint8List());
      print('=== MIDI Player: Temp file written successfully ===');

      // Load from the temp file
      _soundfontId = await _midiPro.loadSoundfontFile(
        filePath: tempFile.path,
      );
      print('=== MIDI Player: Soundfont loaded successfully with ID: $_soundfontId ===');

      // Select Acoustic Grand Piano (program 0) for all MIDI channels
      print('=== MIDI Player: Selecting piano for all channels ===');
      for (int channel = 0; channel < 16; channel++) {
        await _midiPro.selectInstrument(
          sfId: _soundfontId,
          channel: channel,
          bank: 0,
          program: 0, // 0 = Acoustic Grand Piano in General MIDI
        );
      }
      print('=== MIDI Player: Piano selected, initialization complete ===');

      _isInitialized = true;
    } catch (e, stackTrace) {
      print('=== MIDI Player ERROR: Failed to initialize ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to initialize MIDI player: $e');
    }
  }

  /// Load and prepare a MIDI file for playback
  Future<void> load(String midiUrl, {int transposeOffset = 0}) async {
    try {
      // Initialize if not already done
      if (!_isInitialized) {
        await initialize();
      }

      _currentTransposeOffset = transposeOffset;

      // Download MIDI file
      final response = await http.get(Uri.parse(midiUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download MIDI file: ${response.statusCode}');
      }

      // Parse MIDI file
      final parser = MidiParser();
      _currentMidiFile = parser.parseMidiFromBuffer(response.bodyBytes);

      // Pre-process MIDI events with timing
      _preprocessMidiEvents();
    } catch (e) {
      print('Failed to load MIDI file: $e');
      throw Exception('Failed to load MIDI file: $e');
    }
  }

  /// Preprocess MIDI events to create a timeline
  void _preprocessMidiEvents() {
    if (_currentMidiFile == null) return;

    _timedEvents = [];
    final ticksPerBeat = _currentMidiFile!.header.ticksPerBeat ?? 480;
    double currentTime = 0;
    int tempo = 500000; // Default tempo (120 BPM)

    // Process all tracks
    for (final track in _currentMidiFile!.tracks) {
      currentTime = 0;

      for (final event in track) {
        // Update current time based on delta time
        final deltaTimeMs = (event.deltaTime * tempo) / (ticksPerBeat * 1000);
        currentTime += deltaTimeMs;

        // Handle tempo changes
        if (event is SetTempoEvent) {
          tempo = event.microsecondsPerBeat;
        }

        // Skip program change events - we want to use piano only
        if (event is ProgramChangeMidiEvent) {
          continue;
        }

        // Add note events to timeline - properly cast events
        if (event is NoteOnEvent) {
          final noteEvent = event;
          if (noteEvent.velocity > 0) {
            _timedEvents!.add(_TimedMidiEvent(
              timeMs: currentTime,
              noteNumber: noteEvent.noteNumber + _currentTransposeOffset,
              velocity: noteEvent.velocity,
              channel: noteEvent.channel,
              isNoteOn: true,
            ));
          } else {
            // Note on with velocity 0 is equivalent to note off
            _timedEvents!.add(_TimedMidiEvent(
              timeMs: currentTime,
              noteNumber: noteEvent.noteNumber + _currentTransposeOffset,
              velocity: 0,
              channel: noteEvent.channel,
              isNoteOn: false,
            ));
          }
        } else if (event is NoteOffEvent) {
          final noteEvent = event;
          _timedEvents!.add(_TimedMidiEvent(
            timeMs: currentTime,
            noteNumber: noteEvent.noteNumber + _currentTransposeOffset,
            velocity: 0,
            channel: noteEvent.channel,
            isNoteOn: false,
          ));
        }
      }
    }

    // Sort events by time
    _timedEvents!.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  }

  /// Play the loaded MIDI file
  Future<void> play() async {
    if (_timedEvents == null || _timedEvents!.isEmpty) {
      print('No MIDI events to play');
      return;
    }

    // Re-select piano for all channels before playing
    print('=== MIDI Player: Re-selecting piano before playback (SF ID: $_soundfontId) ===');
    for (int channel = 0; channel < 16; channel++) {
      await _midiPro.selectInstrument(
        sfId: _soundfontId,
        channel: channel,
        bank: 0,
        program: 0, // Acoustic Grand Piano
      );
    }
    print('=== MIDI Player: Piano re-selected, starting playback ===');

    _isPlaying = true;
    _currentEventIndex = 0;
    _playbackStartTime = DateTime.now();

    // Use 20ms timer interval (reduced overhead for sparse events)
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      // Skip this tick if still processing events from previous tick
      if (_isProcessingEvents) {
        return;
      }

      // Process events asynchronously with await for proper sequencing
      _processEvents();
    });
  }

  /// Process MIDI events with proper sequencing
  Future<void> _processEvents() async {
    if (_isProcessingEvents || _playbackStartTime == null) return;

    _isProcessingEvents = true;

    try {
      final elapsedMs = DateTime.now().difference(_playbackStartTime!).inMilliseconds.toDouble();

      // Process events that should have occurred by now
      // Limit to 10 events per batch to prevent any potential bursts
      int eventsProcessed = 0;
      const maxEventsPerBatch = 10;

      while (_currentEventIndex < _timedEvents!.length &&
             _timedEvents![_currentEventIndex].timeMs <= elapsedMs &&
             eventsProcessed < maxEventsPerBatch) {
        final event = _timedEvents![_currentEventIndex];

        final noteKey = '${event.channel}:${event.noteNumber}';

        try {
          if (event.isNoteOn) {
            // Await to ensure proper sequencing
            await _midiPro.playNote(
              channel: event.channel,
              key: event.noteNumber,
              velocity: event.velocity,
              sfId: _soundfontId,
            );
            _activeNotes.add(noteKey);
          } else {
            // Await to ensure proper sequencing
            await _midiPro.stopNote(
              channel: event.channel,
              key: event.noteNumber,
              sfId: _soundfontId,
            );
            _activeNotes.remove(noteKey);
          }
        } catch (e) {
          print('=== MIDI Player: Error playing event: $e ===');
        }

        _currentEventIndex++;
        eventsProcessed++;
      }

      // Stop when all events have been played
      if (_currentEventIndex >= _timedEvents!.length) {
        _playbackTimer?.cancel();
        await stop();
      }
    } finally {
      _isProcessingEvents = false;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    _playbackTimer?.cancel();
    _isPlaying = false;
    _isProcessingEvents = false;

    // Stop all notes using the stopAllNotes method (only if initialized)
    if (_isInitialized && _soundfontId > 0) {
      try {
        await _midiPro.stopAllNotes(sfId: _soundfontId);
      } catch (e) {
        print('=== MIDI Player: Error stopping notes: $e ===');
      }
    }
    _activeNotes.clear();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Stop playback and reset position
  Future<void> stop() async {
    _playbackTimer?.cancel();
    _isPlaying = false;
    _isProcessingEvents = false;
    _currentEventIndex = 0;
    _playbackStartTime = null;

    // Stop all notes using the stopAllNotes method (only if initialized)
    if (_isInitialized && _soundfontId > 0) {
      try {
        await _midiPro.stopAllNotes(sfId: _soundfontId);
      } catch (e) {
        print('=== MIDI Player: Error stopping notes: $e ===');
      }
    }
    _activeNotes.clear();
  }

  /// Update the transposition
  Future<void> updateTransposition(int transposeOffset) async {
    if (_currentTransposeOffset == transposeOffset) return;

    final wasPlaying = _isPlaying;
    if (wasPlaying) {
      await stop();
    }

    _currentTransposeOffset = transposeOffset;

    // Reprocess events with new transposition
    _preprocessMidiEvents();

    if (wasPlaying) {
      await play();
    }
  }

  /// Dispose the player and free resources
  void dispose() {
    stop();
    _playbackTimer?.cancel();
  }
}

/// Helper class to store timed MIDI events
class _TimedMidiEvent {
  final double timeMs;
  final int noteNumber;
  final int velocity;
  final int channel;
  final bool isNoteOn;

  _TimedMidiEvent({
    required this.timeMs,
    required this.noteNumber,
    required this.velocity,
    required this.channel,
    required this.isNoteOn,
  });
}
