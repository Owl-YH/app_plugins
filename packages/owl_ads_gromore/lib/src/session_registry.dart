import 'package:owl_ads/owl_ads.dart';

final class AdSessionSnapshot {
  const AdSessionSnapshot({
    required this.placement,
    required this.adType,
    required this.generation,
    required this.readiness,
  });

  final AdPlacement placement;
  final AdType adType;
  final int generation;
  final AdReadiness readiness;
}

final class _AdSession {
  _AdSession({required this.placement, required this.adType});

  final AdPlacement placement;
  final AdType adType;
  int generation = 0;
  AdReadiness readiness = AdReadiness.idle;
  bool rewardAccepted = false;
  bool revenueAccepted = false;

  AdSessionSnapshot get snapshot => AdSessionSnapshot(
    placement: placement,
    adType: adType,
    generation: generation,
    readiness: readiness,
  );
}

/// Deterministic one-shot state machine. It does not execute or simulate an ad
/// SDK and is intentionally tested without a fake advertising provider.
final class AdSessionRegistry {
  final Map<String, _AdSession> _sessions = <String, _AdSession>{};

  int? beginLoad(AdPlacement placement, AdType type) {
    final session = _session(placement, type);
    switch (session.readiness) {
      case AdReadiness.loading:
        throw AdsException(
          AdErrorCode.alreadyLoading,
          '${placement.name} is already loading.',
        );
      case AdReadiness.ready:
        return null;
      case AdReadiness.showing:
        throw AdsException(
          AdErrorCode.invalidState,
          '${placement.name} is currently showing.',
        );
      case AdReadiness.blocked:
      case AdReadiness.idle:
        session.generation += 1;
        session.readiness = AdReadiness.loading;
        session.rewardAccepted = false;
        session.revenueAccepted = false;
        return session.generation;
    }
  }

  bool markReady(AdPlacement placement, AdType type, int generation) {
    final session = _session(placement, type);
    if (!_matches(session, generation) ||
        session.readiness != AdReadiness.loading) {
      return false;
    }
    session.readiness = AdReadiness.ready;
    return true;
  }

  void beginShow(AdPlacement placement, AdType type, int generation) {
    final session = _session(placement, type);
    if (!_matches(session, generation) ||
        session.readiness != AdReadiness.ready) {
      throw AdsException(
        AdErrorCode.notReady,
        '${placement.name} does not have a ready ${type.name} ad.',
      );
    }
    session.readiness = AdReadiness.showing;
  }

  bool accepts(
    AdPlacement placement,
    AdType type,
    int generation,
    AdEventKind kind,
  ) {
    final session = _session(placement, type);
    if (!_matches(session, generation)) {
      return false;
    }
    switch (kind) {
      case AdEventKind.loaded:
        return session.readiness == AdReadiness.loading ||
            session.readiness == AdReadiness.ready;
      case AdEventKind.shown:
      case AdEventKind.clicked:
      case AdEventKind.closed:
        return session.readiness == AdReadiness.showing;
      case AdEventKind.rewarded:
        if (session.readiness != AdReadiness.showing ||
            session.rewardAccepted) {
          return false;
        }
        session.rewardAccepted = true;
        return true;
      case AdEventKind.revenue:
        if (session.readiness != AdReadiness.showing ||
            session.revenueAccepted) {
          return false;
        }
        session.revenueAccepted = true;
        return true;
      case AdEventKind.failed:
        return session.readiness == AdReadiness.loading ||
            session.readiness == AdReadiness.ready ||
            session.readiness == AdReadiness.showing;
    }
  }

  bool finish(AdPlacement placement, AdType type, int generation) {
    final session = _session(placement, type);
    if (!_matches(session, generation)) {
      return false;
    }
    session.readiness = AdReadiness.idle;
    return true;
  }

  int currentGeneration(AdPlacement placement, AdType type) =>
      _session(placement, type).generation;

  AdReadiness readiness(AdPlacement placement, AdType type) =>
      _session(placement, type).readiness;

  List<AdSessionSnapshot> invalidateAll({required bool blocked}) {
    final active = _sessions.values
        .where((session) => session.readiness != AdReadiness.idle)
        .map((session) => session.snapshot)
        .toList(growable: false);
    for (final session in _sessions.values) {
      session.generation += 1;
      session.readiness = blocked ? AdReadiness.blocked : AdReadiness.idle;
    }
    return active;
  }

  _AdSession _session(AdPlacement placement, AdType type) =>
      _sessions.putIfAbsent(
        '${type.name}:${placement.name}',
        () => _AdSession(placement: placement, adType: type),
      );

  bool _matches(_AdSession session, int generation) =>
      session.generation == generation;
}
