// ignore: unused_import

import 'dart:ui'; // For ImageFilter
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this
import 'models/user_profile.dart';
import 'widgets/glass_profile_drawer.dart';
import 'profile_page.dart';
import 'services/logger_service.dart';
import 'services/haptic_service.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

import 'widgets/map_filter_widget.dart';
import 'notifications_page.dart';
import 'conversations_page.dart'; // NEW
import 'models/study_spot.dart'; // NEW
import 'providers/user_profile_provider.dart'; // NEW
import 'providers/university_provider.dart'; // NEW
import 'widgets/study_spot_details_sheet.dart'; // NEW

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerd_herd/providers/map_provider.dart';
import 'providers/ghost_mode_provider.dart';
import 'providers/chat_provider.dart';

// Services

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  MaplibreMapController? mapController;
  final supabase = Supabase.instance.client;

  // Ah, lines 188 uses `placesService`. It is likely a global or imported from `services/places_service.dart`.
  // Wait, `places_service.dart` usually exposes a singleton or simple class.
  // Let's assume we can create it.

  // bool _botsSpawned = false; // REMOVED

  // Getter for Study Mode (Visible) derived from Ghost Mode (Invisible)
  // Default to true (Visible) if loading, to ensure we broadcast if we have location.
  // If we turn out to be Ghost, the listener will correct it immediately.
  bool get _isStudyMode => !(ref.read(ghostModeProvider).value ?? false);

  Map<String, UserProfile> _peers = {};
  StreamSubscription? _requestsSubscription;
  LatLng? _currentLocation;

  final Set<String> _seenRequests = {}; // Track shown requests
  MapFilters _filters = MapFilters(); // NEW: Filter State

  // Optimization: Reactive Broadcast State
  LatLng? _lastBroadcastLocation;
  DateTime? _lastBroadcastTime;
  int _unreadSystemCount = 0; // Unread system notifications
  // int _unreadChatCount = 0; // REPLACED BY RIVERPOD
  bool _isUpdatingMarkers = false;
  RealtimeChannel? _notificationsChannel;
  // RealtimeChannel? _messagesChannel; // REPLACED BY RIVERPOD
  RealtimeChannel? _presenceChannel;
  Set<String> _onlineUserIds = {};

  // Map Styles
  static const String _darkMapStyle =
      "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json";
  static const String _lightMapStyle =
      "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json";

  CameraPosition? _initialPosition;

  // Search Area Logic
  bool _isFetchingSpots = false;
  bool _showSearchThisArea = false;
  LatLng? _lastFetchLocation;
  LatLng? _cameraTarget; // Track camera center
  bool _initialSpotsFetched = false; // Simulation: auto-fetch on login

  @override
  void initState() {
    super.initState();
    // Initialize Services - REMOVED (Handled by Riverpod)
    // _placesService = ...
    // _mapService = ...

    // _mapService = ...

    // _loadSettings(); // REMOVED: Managed by ghostModeProvider
    _loadInitialLocation(); // Fast load

    _checkLocationPermissions();
    // _startLocationUpdates(); // REMOVED (Riverpod)
    // ... rest of init
    // _subscribeToPeers(); // REMOVED (Riverpod)
    _subscribeToRequests();
    _subscribeToNotifications();
    // _subscribeToMessages(); // REPLACED BY RIVERPOD
    _setupPresence();
    // _fetchStudySpots(); // REMOVED (Riverpod controls)
    _checkForAnnouncements();

    _checkForAnnouncements();
  }

  Future<void> _checkForAnnouncements() async {
    try {
      final response = await supabase
          .from('announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        // Show banner
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            content: Text(
              '📢 ${response['title']}: ${response['message']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.amberAccent,
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text('DISMISS'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // sticky error ignored for announcements
    }
  }

  Future<void> _loadInitialLocation() async {
    try {
      // getLastKnownPosition is not supported on Web
      // We skip this check on web to avoid the PlatformException
      Position? position;
      if (!kIsWeb) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        setState(() {
          _initialPosition = CameraPosition(
            target: LatLng(position!.latitude, position.longitude),
            zoom: 15,
          );
        });
      } else {
        // Fallback to NYC if absolutely no location found
        setState(() {
          _initialPosition = const CameraPosition(
            target: LatLng(40.7128, -74.0060),
            zoom: 14,
          );
        });
      }
    } catch (e) {
      setState(() {
        _initialPosition = const CameraPosition(
          target: LatLng(40.7128, -74.0060),
          zoom: 14,
        );
      });
    }
  }

  List<StudySpot> _studySpots = []; // NEW

  Future<void> _fetchStudySpots(
      {bool userTriggered = false, double radius = 2000}) async {
    if (_isFetchingSpots) return;

    // Determine target location: Camera Center (if manual) or Current Location (auto)
    final LatLng? target = userTriggered ? _cameraTarget : _currentLocation;
    if (target == null) return;

    setState(() {
      _isFetchingSpots = true;
      if (userTriggered) _showSearchThisArea = false;
    });

    try {
      // Use Provider
      await ref
          .read(studySpotsProvider.notifier)
          .search(target, radius: radius);

      // Local state update handled by ref.listen in build()
      if (mounted) {
        setState(() {
          _lastFetchLocation = target;
          _isFetchingSpots = false;
        });
      }

      _updateMapMarkers(); // Trigger redraw
    } catch (e) {
      logger.error("Error fetching study spots", error: e);
      if (mounted) setState(() => _isFetchingSpots = false);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _cameraTarget = position.target;
  }

  void _onCameraIdle() {
    if (_lastFetchLocation == null || _cameraTarget == null) return;

    // Calculate distance from last fetch
    final dist = Geolocator.distanceBetween(
      _lastFetchLocation!.latitude,
      _lastFetchLocation!.longitude,
      _cameraTarget!.latitude,
      _cameraTarget!.longitude,
    );

    // If moved > 1km, show "Search Area" button
    if (dist > 1000) {
      if (!_showSearchThisArea) {
        setState(() => _showSearchThisArea = true);
      }
    }
  }

  // Helper for Verified vs General styling
  CircleOptions _getSpotStyle(StudySpot spot, {required bool isDark}) {
    if (spot.isVerified) {
      return CircleOptions(
        geometry: LatLng(spot.latitude, spot.longitude),
        circleColor: '#FFA500', // Gold/Orange (Visible on both)
        circleRadius: 12,
        circleStrokeWidth: 2,
        circleStrokeColor: isDark ? '#FFFFFF' : '#000000',
        circleOpacity: 1.0,
      );
    } else {
      // General spots: White in Dark Mode, Deep Purple in Light Mode
      final color = isDark ? '#FFFFFF' : '#6200EE';
      return CircleOptions(
        geometry: LatLng(spot.latitude, spot.longitude),
        circleColor: color,
        circleRadius: 6,
        circleStrokeWidth: 1,
        circleStrokeColor: '#888888',
        circleOpacity: 0.8,
      );
    }
  }

  Future<void> _subscribeToNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Initial fetch for SYSTEM notifications (excluding messages)
    // We assume 'type' != 'message' and 'chat_message'
    final count = await supabase
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', user.id)
        .eq('read', false)
        .neq('type', 'message')
        .neq('type', 'chat_message');

    if (mounted) setState(() => _unreadSystemCount = count);

    // Listen
    _notificationsChannel = supabase
        .channel('public:notifications:${user.id}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) async {
              // newRecord might be empty on DELETE, handled by count fetch below

              // Refresh count on any change
              final newCount = await supabase
                  .from('notifications')
                  .count(CountOption.exact)
                  .eq('user_id', user.id)
                  .eq('read', false)
                  .neq('type', 'message')
                  .neq('type', 'chat_message');
              if (mounted) setState(() => _unreadSystemCount = newCount);
            })
        .subscribe();
  }

  // _subscribeToMessages REMOVED - using totalUnreadMessagesProvider

  // SupabaseClient? _botClient; // UNUSED since switching to local bots

  @override
  void dispose() {
    // _peersSubscription?.cancel(); // Riverpod handles this
    _requestsSubscription?.cancel();
    // _locationSubscription?.cancel(); // Riverpod handles this
    _notificationsChannel?.unsubscribe();
    // _messagesChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();

    super.dispose();
  }

  // Credentials (re-declared for simulation client usage)
  // Credentials (re-declared for simulation client usage)
  // static const _supabaseUrl = 'https://zzdasdmceaykwjsozums.supabase.co'; // UNUSED
  // static const _supabaseKey =
  //    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // UNUSED

  void _updateOwnLocation(LatLng pos) {
    if (!mounted) return;
    if (_currentLocation != pos) {
      setState(() => _currentLocation = pos);
      _updateMapMarkers();

      // Simulation: Auto-fetch spots within 500m on first valid location
      if (!_initialSpotsFetched && mounted) {
        _initialSpotsFetched = true;
        _fetchStudySpots(radius: 500);
      }

      // Reactive Broadcast
      if (_isStudyMode) {
        _broadcastLocationThrottle(pos);
      }
    }
  }

  Future<void> _broadcastLocationThrottle(LatLng pos) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    bool shouldUpdate = false;

    // 1. Time Check (Heartbeat every 30s - User requested)
    if (_lastBroadcastTime == null ||
        now.difference(_lastBroadcastTime!).inSeconds >= 30) {
      shouldUpdate = true;
    }

    // 2. Distance Check (Move > 10m)
    if (!shouldUpdate && _lastBroadcastLocation != null) {
      final dist = Geolocator.distanceBetween(
        _lastBroadcastLocation!.latitude,
        _lastBroadcastLocation!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist > 10) {
        shouldUpdate = true;
      }
    } else if (_lastBroadcastLocation == null) {
      shouldUpdate = true; // First update
    }

    if (shouldUpdate) {
      logger.debug(
          "📍 Broadcaster (Reactive): Upserting location ${pos.latitude}, ${pos.longitude}");
      try {
        final service = ref.read(mapServiceProvider);
        await service.updateLocation(user.id, pos.latitude, pos.longitude);
        _lastBroadcastLocation = pos;
        _lastBroadcastTime = now;
      } catch (e) {
        // Logged in Service
      }
    }
  }

  Future<void> _checkLocationPermissions() async {
    hapticService.lightImpact();
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    logger.debug("📍 Permission status: $permission");
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // 1. Zoom to cached location immediately for responsiveness
      if (_currentLocation != null && mapController != null) {
        logger.debug("📍 Recentering to cached location: $_currentLocation");
        await mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 15),
          duration: const Duration(milliseconds: 800),
        );
      }

      // 2. ALWAYS try to get a fresh location to ensure accuracy
      try {
        logger.debug("📍 Fetching fresh position...");
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10));

        final freshLatLng = LatLng(position.latitude, position.longitude);
        logger.debug("📍 Got fresh position: $freshLatLng");

        _updateOwnLocation(freshLatLng);

        if (mapController != null && mounted) {
          await mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(freshLatLng, 15),
            duration: const Duration(milliseconds: 800),
          );
        }
      } catch (e) {
        // Just a timeout/fail, we will rely on the stream. Not a critical warning.
        logger.debug(
            "ℹ️ Location check timed out (expected on some devices), waiting for stream...",
            error: e);
        // Fallback to last known position
        try {
          // getLastKnownPosition is not supported on Web
          if (!kIsWeb) {
            final position = await Geolocator.getLastKnownPosition();
            if (position != null && mapController != null && mounted) {
              logger.debug("📍 Using last known position: $position");
              await mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(position.latitude, position.longitude),
                  15,
                ),
                duration: const Duration(milliseconds: 800),
              );
            }
          }
        } catch (e2) {
          logger.error("❌ Could not get any location", error: e2);
        }
      }
    }
  }

  bool _isStyleLoaded = false; // Guard for Annotation Manager

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
    controller.onCircleTapped.add(_onCircleTapped);

    // DELAY: Fix for Web "Unexpected null value" / style loading race condition
    // We wait for the style to load before allowing marker updates
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isStyleLoaded = true;
        });
        _updateMapMarkers(); // Draw initial markers
      }
    });
  }

  // _startLocationUpdates REMOVED - using userLocationProvider in build()

  // _subscribeToPeers REMOVED - using peersProvider in build()

  void _subscribeToRequests() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    logger.debug("📨 Subscribing to incoming requests");
    _requestsSubscription = supabase
        .from('collab_requests')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', user.id)
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          for (var request in data) {
            if (request['status'] == 'pending') {
              // Deduplicate using ID
              if (!_seenRequests.contains(request['id'])) {
                _seenRequests.add(request['id']);
                if (mounted) _showRequestDialog(request);
              }
            }
          }
        });
  }

  Future<void> _showRequestDialog(Map<String, dynamic> request) async {
    // Fetch sender profile for better UX
    final senderId = request['sender_id'];
    Map<String, dynamic>? senderProfile;
    try {
      senderProfile = await supabase
          .from('profiles')
          .select()
          .eq('user_id', senderId)
          .maybeSingle();
    } catch (e) {
      logger.error("Error fetching sender profile", error: e);
    }

    final senderName = senderProfile != null
        ? (senderProfile['intent_tag'] ?? 'A Peer')
        : 'A Peer';
    final isTutor = senderProfile?['is_tutor'] ?? false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text("Collab Request", style: theme.textTheme.titleLarge),
          content: Text(
            "$senderName wants to collaborate!",
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                hapticService.lightImpact();
                Navigator.pop(context);
                _respondToRequest(request['id'], request['sender_id'], false);
              },
              child: const Text("Reject",
                  style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () {
                hapticService.mediumImpact();
                Navigator.pop(context);
                _respondToRequest(request['id'], request['sender_id'], true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isTutor ? Colors.amber : Colors.cyanAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text("Accept"),
            ),
          ],
        );
      },
    );
  }

  void _setupPresence() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _presenceChannel = supabase.channel('map-presence');

    _presenceChannel?.onPresenceSync((payload) {
      if (!mounted) return;

      try {
        final dynamic rawState = _presenceChannel?.presenceState();

        final onlineIds = <String>{};

        // Handle Map<String, List<Presence>> (Standard)
        if (rawState is Map) {
          for (var entry in rawState.entries) {
            // entry.value is usually List<Presence>
            if (entry.value is List) {
              final list = entry.value as List;
              for (var item in list) {
                // item is Presence
                if (item is Presence) {
                  if (item.payload['user_id'] != null) {
                    onlineIds.add(item.payload['user_id'].toString());
                  }
                } else if (item is Map) {
                  // Fallback if it's a raw Map
                  if (item['user_id'] != null) {
                    onlineIds.add(item['user_id'].toString());
                  }
                }
              }
            }
          }
        }
        // Handle List<Presence> (Edge case or specific library version)
        else if (rawState is List) {
          for (var item in rawState) {
            // Access dynamically to support SinglePresenceState structure
            final dItem = item as dynamic;
            try {
              // SinglePresenceState has 'presences' list
              // Check if it has 'presences' property
              var presences = <dynamic>[];
              try {
                presences = dItem.presences as List? ?? [];
              } catch (_) {
                // May actually be a list of Presence directly?
                if (item is Presence) presences.add(item);
              }

              for (var p in presences) {
                final pDyn = p as dynamic;
                final payload = pDyn.payload;
                if (payload != null && payload['user_id'] != null) {
                  onlineIds.add(payload['user_id'].toString());
                }
              }
            } catch (e2) {
              // ignore
            }
          }
        }

        setState(() => _onlineUserIds = onlineIds);
        _updateMapMarkers();
      } catch (e) {
        logger.warning("Error parsing presence state", error: e);
      }
    });

    _presenceChannel?.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _updatePresenceTracking();
      }
    });
  }

  void _updatePresenceTracking() {
    final user = supabase.auth.currentUser;
    if (user == null || _presenceChannel == null) return;

    if (_isStudyMode) {
      _presenceChannel?.track({'user_id': user.id});
    } else {
      _presenceChannel?.untrack();
    }
  }

  Future<void> _respondToRequest(
      String requestId, String senderId, bool accept) async {
    try {
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;

      if (accept) {
        // Create the connection
        await supabase.from('connections').insert({
          'user_id_1': senderId,
          'user_id_2': myId, // Me
        });

        // Remove the request as it is now an active connection
        await supabase.from('collab_requests').delete().eq('id', requestId);
      } else {
        // Rejecting: Set status to rejected (or delete if you prefer)
        await supabase.from('collab_requests').update({
          'status': 'rejected',
        }).eq('id', requestId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                accept ? "Request Accepted & Connected!" : "Request Rejected"),
            backgroundColor: accept ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      logger.error("Error responding to request", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateMapMarkers() async {
    if (!mounted || mapController == null || !_isStyleLoaded) return;
    if (_isUpdatingMarkers) return; // Prevent overlapping updates

    _isUpdatingMarkers = true;

    // Get latest profile snapshot (or watch it in build)
    final myProfile = ref.read(myProfileProvider).value;

    try {
      logger.debug(
          "📍 Updating markers for ${_peers.length} peer(s) and ${_studySpots.length} spots");
      try {
        await mapController?.clearCircles();
      } catch (e) {
        logger.debug("⚠️ clearCircles failed (ignoring)", error: e);
      }

      // 0. Draw Study Spots (Bottom Layer)
      // Determine theme for marker colors
      final isDark = Theme.of(context).brightness == Brightness.dark;

      for (var spot in _studySpots) {
        try {
          await mapController?.addCircle(
            _getSpotStyle(spot, isDark: isDark),
            {
              'is_study_spot': true,
              'spot_id': spot.id,
              'is_verified': spot.isVerified,
            },
          );
        } catch (e) {
          logger.warning("Failed to draw study spot ${spot.name}", error: e);
        }
      }

      for (var peer in _peers.values) {
        final geometry = peer.location;
        if (geometry == null) {
          continue;
        }

        // SKIP MYSELF: I am already drawn as the "Me" circle with pulse
        if (peer.userId == supabase.auth.currentUser?.id) {
          continue;
        }

        // --- VISIBILITY & LIVE STATUS ---
        // Logic:
        // 1. Online OR Recent (<10m) -> Visible
        // 2. Stale (>10m) -> HIDDEN (Strict)

        bool isOnline = _onlineUserIds.contains(peer.userId);
        bool isRecent = false;
        int minutesAgo = 9999;

        if (peer.lastUpdated != null) {
          final nowUtc = DateTime.now().toUtc();
          final lastUpdateUtc = peer.lastUpdated!.isUtc
              ? peer.lastUpdated!
              : peer.lastUpdated!.toUtc();

          final diff = nowUtc.difference(lastUpdateUtc);
          minutesAgo = diff.inMinutes.abs();

          if (minutesAgo <= 10) {
            isRecent = true;
          }
        }

        // STRICT FILTER: If not online and not recent, hide them.
        if (!isOnline && !isRecent) {
          continue;
        }

        // Only skip if NO LOCATION at all
        if (peer.location == null) continue;

        // Opacity is always 1.0 since we only show active users
        double opacity = 1.0;

        // --- FILTERS ---
        // 1. Tutors
        if (peer.isTutor && !_filters.showTutors) continue;
        // 2. Students
        if (!peer.isTutor && !_filters.showStudents) continue;

        // 3. Classmates (New)
        if (_filters.showClassmates) {
          if (myProfile == null) {
            continue; // Can't filter if we don't know who I am
          }

          final myClasses = myProfile.currentClasses;
          final peerClasses = peer.currentClasses;

          // Check intersection
          final common = myClasses.toSet().intersection(peerClasses.toSet());
          if (common.isEmpty) continue;
        }

        // 4. Subjects
        if (_filters.selectedSubjects.isNotEmpty) {
          // ... (existing logic)
          // If peer has no classes that match selected subjects?
          // Or if peer "intent" matches?
          // For now, let's assume we check against currentClasses or Intent
          // Simple check:
          bool matchesSubject = false;
          for (var subject in _filters.selectedSubjects) {
            // Check classes
            if (peer.currentClasses
                .any((c) => c.toLowerCase().contains(subject.toLowerCase()))) {
              matchesSubject = true;
              break;
            }
            // Check intent
            if (peer.intentTag != null &&
                peer.intentTag!.toLowerCase().contains(subject.toLowerCase())) {
              matchesSubject = true;
              break;
            }
          }
          if (!matchesSubject) continue;
        }

        // 5. Min Rating
        if (peer.isTutor &&
            peer.averageRating != null &&
            peer.averageRating! < _filters.minRating) {
          continue;
        }

        try {
          if (!mounted) break; // STOP if the widget is disposed
          await mapController?.addCircle(
            CircleOptions(
              geometry: geometry, // Safe local variable
              circleColor: peer.isTutor
                  ? '#FFD700'
                  : '#00FFFF', // Gold for Tutors, Cyan for Students
              circleRadius: 8,
              circleStrokeWidth: 2,
              circleStrokeColor: '#FFFFFF',
              circleBlur: 0.2,
              circleOpacity: opacity, // Use calculated opacity
            ),
            peer.toJson(),
          );
        } catch (e) {
          logger.warning("⚠️ Failed to add circle: ${e.toString()}", error: e);
        }
      }

      // 1. Draw "Me" (Local Loopback - Instant) - DRAW LAST (On Top)
      // ONLY draw if "Study Mode" (Ghost Mode Disabled) is ON
      if (_isStudyMode && _currentLocation != null && mapController != null) {
        logger.debug("📍 Drawing my location at $_currentLocation");

        try {
          await mapController?.addCircle(
            CircleOptions(
              geometry: _currentLocation!,
              circleColor: '#00FF00',
              circleOpacity: 0.3,
              circleRadius: 22,
              circleStrokeWidth: 2,
              circleStrokeColor: '#00FF00',
              circleBlur: 0.6,
            ),
            {'is_me': true},
          );

          // Core Dot (Always Visible)
          await mapController?.addCircle(
            CircleOptions(
              geometry: _currentLocation!,
              circleColor: '#00FF00',
              circleRadius: 7,
              circleStrokeWidth: 2,
              circleStrokeColor: '#FFFFFF',
            ),
            {'is_me': true},
          );
        } catch (e) {
          logger.warning("⚠️ Failed to draw my location", error: e);
        }
      } else if (_currentLocation == null) {
        // Normal during startup, no need to warn
        logger.debug("⏳ Waiting for location to draw 'Me' circle...");
      }
    } catch (e) {
      logger.error("❌ Error updating map markers", error: e);
    } finally {
      _isUpdatingMarkers = false;
    }
  }

  void _onCircleTapped(Circle circle) {
    hapticService.selectionClick();
    if (circle.data != null) {
      final data = Map<String, dynamic>.from(circle.data as Map);

      // Check for Study Spot
      if (data['is_study_spot'] == true) {
        final spotId = data['spot_id'];
        final spot = _studySpots.firstWhere((s) => s.id == spotId,
            orElse: () => _studySpots.first); // fallback safe
        _showStudySpotDetails(spot);
        return;
      }

      if (data['is_me'] == true) {
        final myId = supabase.auth.currentUser?.id;
        if (myId != null && _peers.containsKey(myId)) {
          _showProfileDrawer(_peers[myId]!.toJson());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Syncing profile... please wait.")),
          );
        }
        return;
      }
      _showProfileDrawer(data);
    }
  }

  void _showStudySpotDetails(StudySpot spot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StudySpotDetailsSheet(spot: spot),
    );
  }

  void _showProfileDrawer(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final profile = UserProfile.fromJson(data);
        return GlassProfileDrawer(profile: profile);
      },
    );
  }

  Future<void> _goGhost() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _updatePresenceTracking(); // UNTRACK instantly

    try {
      final service = ref.read(mapServiceProvider);
      await service.goGhost(user.id);

      // Reset broadcast state so next broadcast is immediate when resumed
      _lastBroadcastLocation = null;
      _lastBroadcastTime = null;
    } catch (e) {
      // Logged in Service
    }
  }

  Widget _buildGlassControl({
    required VoidCallback onPressed,
    required Widget child,
    String? tooltip,
    bool isMini = false,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = isMini ? 44.0 : 56.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: (activeColor ?? (isDark ? Colors.black : Colors.white))
                .withValues(alpha: 0.7),
            child: InkWell(
              onTap: onPressed,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch unread count
    final unreadChatCount = ref.watch(totalUnreadMessagesProvider).value ?? 0;

    // RIVERPOD LISTENERS
    // 1. Location
    ref.listen(userLocationProvider, (previous, next) {
      next.whenData((pos) {
        _updateOwnLocation(pos);
      });
    });

    // Watch Ghost Mode to ensure rebuilds
    ref.watch(ghostModeProvider);

    // 2. Peers
    ref.listen(peersProvider, (previous, next) {
      next.whenData((data) {
        // logger.debug("📍 Peers update received: ${data.length} profiles");
        final newPeers = <String, UserProfile>{};
        for (var profile in data) {
          newPeers[profile.userId] = profile;
          // Log specific user details to check for null locations
          if (profile.userId != supabase.auth.currentUser?.id) {
            logger.debug(
                "   > Peer ${profile.userId} | Loc: ${profile.location} | Updated: ${profile.lastUpdated}");
          }
        }
        setState(() => _peers = newPeers);
        _updateMapMarkers();
      });
    });

    // 3. Study Spots
    ref.listen(studySpotsProvider, (previous, next) {
      next.whenData((spots) {
        setState(() => _studySpots = spots);
        _updateMapMarkers();
      });
    });

    final availableSubjectsAsync = ref.watch(availableSubjectsProvider);

    // Listen to Ghost Mode changes
    ref.listen<AsyncValue<bool>>(ghostModeProvider, (prev, next) {
      final wasGhost = prev?.value ?? false; // Default false (Visible)
      final isGhost = next.value ?? false;

      // Check for transition
      if (wasGhost != isGhost) {
        if (isGhost) {
          logger.debug("👻 Ghost Mode Enabled: Clearing location and presence");

          // Execute with error handling
          _goGhost().catchError((e) {
            logger.error("Failed to go ghost, reverting UI", error: e);
            // Revert user-visible state
            ref.read(ghostModeProvider.notifier).setGhostMode(false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Failed to enable Ghost Mode: $e"),
                    backgroundColor: Colors.red),
              );
            }
          });

          _updatePresenceTracking();
        } else {
          logger.debug("👻 Ghost Mode Disabled: Broadcasting location");
          // Becoming visible
          if (_currentLocation != null) {
            // FORCE Update immediately (bypass throttle)
            _lastBroadcastLocation = null;
            _broadcastLocationThrottle(_currentLocation!);
          }
          _updatePresenceTracking();
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ... MapLibreMap ...
          if (_initialPosition != null)
            MaplibreMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: _initialPosition!,
              styleString: isDark ? _darkMapStyle : _lightMapStyle,
              myLocationEnabled: false,
              trackCameraPosition: true,
              onCameraIdle: _onCameraIdle,
              onCameraMove: _onCameraMove,
            )
          else
            const Center(child: CircularProgressIndicator()),

          // "Search Area" Button (Top Center, below Dynamic Island)
          if (_showSearchThisArea)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    hapticService.mediumImpact();
                    _fetchStudySpots(userTriggered: true);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.5 : 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search,
                            color: theme.colorScheme.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          "Search This Area",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Loading Pill (Top Center)
          if (_isFetchingSpots)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Loading spots...",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // "Recenter" Button (Bottom Right)
          Positioned(
            bottom: 40,
            right: 20,
            child: _buildGlassControl(
              onPressed: _checkLocationPermissions,
              child: Icon(Icons.my_location,
                  color: isDark ? Colors.white : Colors.black87),
              tooltip: "Recenter",
            ),
          ),

          // "Simulate Bot" Button (Top Left - DEV ONLY)
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              children: [
                _buildGlassControl(
                  isMini: true,
                  onPressed: () {
                    hapticService.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    ).then((_) {
                      // Settings handled by provider
                    });
                  },
                  child:
                      (_peers[supabase.auth.currentUser?.id]?.avatarUrl != null)
                          ? CircleAvatar(
                              backgroundImage:
                                  _peers[supabase.auth.currentUser!.id]!
                                          .avatarUrl!
                                          .startsWith('assets/')
                                      ? AssetImage(
                                          _peers[supabase.auth.currentUser!.id]!
                                              .avatarUrl!) as ImageProvider
                                      : CachedNetworkImageProvider(
                                          _peers[supabase.auth.currentUser!.id]!
                                              .avatarUrl!),
                              radius: 18,
                            )
                          : Icon(Icons.person,
                              color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 12),
                // Chat Button (NEW)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildGlassControl(
                      isMini: true,
                      onPressed: () {
                        hapticService.lightImpact();
                        Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ConversationsPage()))
                            .then((_) {
                          // Refresh message count on return - Handled by Riverpod subscription
                          ref.invalidate(totalUnreadMessagesProvider);
                        });
                      },
                      child: Icon(Icons.chat_bubble_outline,
                          color: isDark ? Colors.white : Colors.black87),
                    ),
                    if (unreadChatCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$unreadChatCount',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 12),
                // Notifications Bell
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildGlassControl(
                      isMini: true,
                      onPressed: () {
                        hapticService.lightImpact();
                        Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const NotificationsPage()))
                            .then((_) {
                          // Refresh count on return
                          _subscribeToNotifications();
                        });
                      },
                      child: Icon(Icons.notifications,
                          color: isDark ? Colors.white : Colors.black87),
                    ),
                    if (_unreadSystemCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$_unreadSystemCount',
                            style: TextStyle(
                              color: theme.colorScheme.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Floating "Study Mode" Toggle (Top Right)
          Positioned(
            top: 60,
            right: 20,
            child: GestureDetector(
              onTap: () {
                final currentGhost = ref.read(ghostModeProvider).value ?? false;
                final newGhost = !currentGhost;

                hapticService.mediumImpact();
                ref.read(ghostModeProvider.notifier).setGhostMode(newGhost);

                // Note: Logic for broadcast/goGhost is handled by ref.listen in build.
                // UI update specific to mode is handled by ref.watch triggering rebuild.
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: (_isStudyMode
                              ? theme.primaryColor
                              : (isDark ? Colors.black : Colors.white))
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isStudyMode
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: _isStudyMode
                              ? Colors.white
                              : (isDark ? Colors.white60 : Colors.black54),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isStudyMode ? "LIVE" : "GHOST",
                          style: TextStyle(
                            color: _isStudyMode
                                ? Colors.white
                                : (isDark ? Colors.white60 : Colors.black54),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Filter Widget
          Positioned(
            top: 130,
            right: 20,
            child: MapFilterWidget(
              currentFilters: _filters,
              availableSubjects: availableSubjectsAsync.value ?? [],
              onFilterChanged: (newFilters) {
                setState(() => _filters = newFilters);
                hapticService.mediumImpact();
                _updateMapMarkers();
              },
            ),
          ),
        ],
      ),
    );
  }
}
