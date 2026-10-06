import 'dart:async';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

class FakeJustAudio extends JustAudioPlatform {
  final players = <String, FakeAudioPlayer>{};
  FakeAudioPlayer? last;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeAudioPlayer(request.id);
    players[request.id] = player;
    last = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    players.remove(request.id)?.close();
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    for (final player in players.values) {
      player.close();
    }
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

// mimics how mpv reports the playing entry: it follows the item, not the
// slot, and reports a little after the playlist changes
class FakeAudioPlayer extends AudioPlayerPlatform {
  FakeAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final _data = StreamController<PlayerDataMessage>.broadcast();

  List<AudioSourceMessage> items = [];
  AudioSourceMessage? current;
  bool playing = false;
  int loads = 0;
  int seeks = 0;
  LoopModeMessage loopMode = LoopModeMessage.off;

  int? get currentIndex {
    if (current == null) return null;
    final at = items.indexOf(current!);
    return at < 0 ? null : at;
  }

  List<String> get songIds => items.map(songIdOf).toList();

  static String songIdOf(AudioSourceMessage message) =>
      Uri.parse((message as UriAudioSourceMessage).uri).queryParameters['id'] ??
      '';

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => _data.stream;

  void emit({ProcessingStateMessage state = ProcessingStateMessage.ready}) {
    if (_events.isClosed) return;
    _events.add(
      PlaybackEventMessage(
        processingState: state,
        updateTime: DateTime.now(),
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: const Duration(seconds: 30),
        icyMetadata: null,
        currentIndex: currentIndex,
        androidAudioSessionId: null,
      ),
    );
  }

  void _emitLater() {
    Future<void>.delayed(const Duration(milliseconds: 5), emit);
  }

  void advance() {
    final at = currentIndex;
    if (at == null || at + 1 >= items.length) return;
    current = items[at + 1];
    emit();
  }

  void close() {
    _events.close();
    _data.close();
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    loads++;
    final source = request.audioSourceMessage;
    items = source is ConcatenatingAudioSourceMessage
        ? List.of(source.children)
        : [source];
    current = items.isEmpty
        ? null
        : items[(request.initialIndex ?? 0).clamp(0, items.length - 1)];
    emit();
    return LoadResponse(duration: const Duration(seconds: 30));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playing = true;
    emit();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    playing = false;
    emit();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    seeks++;
    final index = request.index;
    if (index != null && index >= 0 && index < items.length) {
      current = items[index];
    }
    emit();
    return SeekResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    items.insertAll(request.index, request.children);
    _emitLater();
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    final removed = items.sublist(request.startIndex, request.endIndex);
    if (current != null && removed.contains(current)) {
      current = request.endIndex < items.length
          ? items[request.endIndex]
          : (request.startIndex > 0 ? items[request.startIndex - 1] : null);
    }
    items.removeRange(request.startIndex, request.endIndex);
    _emitLater();
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async {
    items.insert(request.newIndex, items.removeAt(request.currentIndex));
    _emitLater();
    return ConcatenatingMoveResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    loopMode = request.loopMode;
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async => SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async => SetPreferredPeakBitRateResponse();

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async => SetAllowsExternalPlaybackResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    close();
    return DisposeResponse();
  }
}
