// ignore: unused_import

import 'dart:ui' as ui; // For ImageFilter and Canvas
import 'dart:async';
// import 'dart:typed_data'; // Unnecessary
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
import 'services/simulation_service.dart'; // NEW

import 'widgets/map_filter_widget.dart';
import 'notifications_page.dart';
import 'conversations_page.dart'; // NEW
import 'models/study_spot.dart'; // NEW
import 'providers/user_profile_provider.dart'; // NEW
import 'widgets/study_spot_details_sheet.dart'; // NEW
import 'pages/serendipity/struggle_status_widget.dart'; // Serendipity Engine

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerd_herd/providers/map_provider.dart';
import 'providers/ghost_mode_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/serendipity_provider.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

// Services

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  MapLibreMapController? mapController;
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
  MapFilters _filters = MapFilters();
  bool _isFilterExpanded = false; // NEW: Controlled state for filter

  // Optimization: Reactive Broadcast State
  LatLng? _lastBroadcastLocation;
  DateTime? _lastBroadcastTime;
  int _unreadSystemCount = 0; // Unread system notifications
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

  final SimulationService _simulationService = SimulationService();
  List<StudySpot> _studySpots = []; // NEW
  Map<String, UserProfile> _simulatedPeers = {}; // NEW

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

  // Pre-load market icons
  Future<void> _loadCustomMarkers() async {
    if (mapController == null) return;

    final markers = {
      'marker_student': (Icons.school, const Color(0xFF00E676)), // Green
      'marker_tutor': (
        Icons.workspace_premium,
        const Color(0xFFD500F9)
      ), // Purple
      'marker_cafe': (Icons.coffee, const Color(0xFF546E7A)), // Charcoal
      'marker_library': (
        Icons.library_books,
        const Color(0xFF5C6BC0)
      ), // Indigo
      'marker_restaurant': (Icons.restaurant, const Color(0xFFEF5350)), // Red
      'marker_other_spot': (Icons.place, const Color(0xFF78909C)), // Blue Grey
      'marker_sponsored': (Icons.auto_awesome, const Color(0xFFFFD600)), // Gold
      'marker_me': (
        Icons.person_pin,
        const Color(0xFF00E5FF)
      ), // Cyan (distinct from green students)
    };

    for (var entry in markers.entries) {
      try {
        final bytes = await _createMarkerImage(entry.value.$1, entry.value.$2);
        await mapController!.addImage(entry.key, bytes);
        logger.debug("✅ Registered marker: ${entry.key}");
      } catch (e) {
        logger.error("❌ Failed to register marker: ${entry.key}", error: e);
      }
    }
  }

  // Helper for responsive marker scale
  double _getMarkerScale() {
    // Target Sizes:
    // Web: ~45px (Standard cursor interaction)
    // Mobile: ~70px (Finger accessible)
    // Base Size: 250px
    if (kIsWeb) {
      return 0.18; // 250 * 0.18 = 45px
    } else {
      return 0.28; // 250 * 0.28 = 70px
    }
  }

  Future<Uint8List> _createMarkerImage(IconData icon, Color? color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // INCREASED RESOLUTION: 100 -> 250 for crispness on high DPI screens
    const size = 250.0;

    // Proportional padding/sizing
    const padding = size * 0.1; // 10% padding (25px)
    const innerSize = size - (padding * 2);

    // DEFENSIVE: Fallback if color is theoretically null (fixes reported crash)
    final safeColor = color ?? Colors.white;

    // 1. Draw Background (Matte Frosted Circle)
    final paint = Paint()
      ..color =
          safeColor.withValues(alpha: 0.9) // Higher opacity for matte look
      ..style = PaintingStyle.fill;

    // Subtle shadow for 3D effect (diffused)
    // Scaled blur and offset for larger size
    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 5), // +5 offset
      innerSize / 2,
      Paint()
        ..color = Colors.blue.withValues(alpha: 0.3)
        ..maskFilter =
            const ui.MaskFilter.blur(BlurStyle.normal, 10), // 10 blur
    );

    canvas.drawCircle(const Offset(size / 2, size / 2), innerSize / 2, paint);

    // 2. Draw Matte Border (Semi-transparent white)
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.04; // 4% stroke (10px)
    canvas.drawCircle(
        const Offset(size / 2, size / 2), innerSize / 2, borderPaint);

    // 3. Draw Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: innerSize * 0.55,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
          size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2),
    );

    final image = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Helper for verified vs general styling
  SymbolOptions _getSpotSymbolStyle(StudySpot spot) {
    String iconImage = 'marker_other_spot';

    if (spot.isSponsored) {
      iconImage = 'marker_sponsored';
    } else {
      switch (spot.type.toLowerCase()) {
        case 'cafe':
          iconImage = 'marker_cafe';
          break;
        case 'library':
          iconImage = 'marker_library';
          break;
        case 'restaurant':
        case 'bar':
          iconImage = 'marker_restaurant';
          break;
      }
    }

    return SymbolOptions(
      geometry: LatLng(spot.latitude, spot.longitude),
      iconImage: iconImage,
      iconSize: _getMarkerScale(), // USE DYNAMIC SCALE
      iconOpacity: 1.0,
    );
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

      // Simulation & Initial Fetch: Auto-fetch spots and bots on first valid location
      if (!_initialSpotsFetched && mounted) {
        _initialSpotsFetched = true;

        // 1. Fetch Spots
        _fetchStudySpots(radius: 2000);

        // 2. Spawn Bots
        _generateSimulation(pos);
      } else {
        // Respawn bots if we move far (e.g. > 1km) from their center
        // For simplicity, we can just respawn them occasionally or keep them static for now.
        // User requested: "if the user moves... they should re-appear close"
        // Let's check distance from first bot center?
        // Or simpler: just respawn if we moved > 500m from last generation.
        if (_lastSimulationCenter != null) {
          final dist = Geolocator.distanceBetween(
              _lastSimulationCenter!.latitude,
              _lastSimulationCenter!.longitude,
              pos.latitude,
              pos.longitude);
          if (dist > 1000) {
            // 1km
            _generateSimulation(pos);
          }
        }
      }

      // Reactive Broadcast
      if (_isStudyMode) {
        _broadcastLocationThrottle(pos);
      }
    }
  }

  LatLng? _lastSimulationCenter;

  void _generateSimulation(LatLng center) {
    logger.info("🤖 Generating simulation around $center");
    final bots = _simulationService.generateBots(
      center: center,
      studentCount: 3,
      tutorCount: 3,
    );

    setState(() {
      _lastSimulationCenter = center;
      _simulatedPeers = {for (var b in bots) b.userId: b};
    });

    _updateMapMarkers();
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

  void _onMapCreated(MapLibreMapController controller) async {
    mapController = controller;
    controller.onCircleTapped.add(_onCircleTapped);
    controller.onSymbolTapped.add(_onSymbolTapped);

    // RESET flag for new controller instance
    setState(() {
      _isStyleLoaded = false;
    });
  }

  void _onStyleLoaded() async {
    if (!mounted) return;

    logger.debug("🗺️ Map Style Loaded - Initializing Markers");

    // Load custom markers FIRST
    await _loadCustomMarkers();

    if (mounted) {
      setState(() {
        _isStyleLoaded = true;
      });
      _updateMapMarkers(); // Draw initial markers
    }
  }

  // ... (lines 498-761 logic omitted, jumping to updateMapMarkers)

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

    ref.read(isModalOpenProvider.notifier).state = true;
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return PointerInterceptor(
          child: AlertDialog(
            backgroundColor: theme.dialogTheme.backgroundColor,
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
          ),
        );
      },
    ).then((_) {
      if (mounted) ref.read(isModalOpenProvider.notifier).state = false;
    });
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
        await mapController?.clearSymbols();
      } catch (e) {
        logger.debug("⚠️ clearCircles/Symbols failed (ignoring)", error: e);
      }

      // 0. Draw Study Spots (Bottom Layer)
      // Determine theme for marker colors
      if (!mounted) return;

      // Sort: Sponsored LAST to render on top
      final sortedSpots = List<StudySpot>.from(_studySpots);
      sortedSpots.sort((a, b) {
        if (a.isSponsored && !b.isSponsored) return 1;
        if (!a.isSponsored && b.isSponsored) return -1;
        return 0;
      });

      for (var spot in sortedSpots) {
        // FILTER: Check Sponsored / Regular
        if (spot.isSponsored && !_filters.showSponsoredSpots) continue;
        if (!spot.isSponsored && !_filters.showRegularSpots) continue;

        // COLLISION AVOIDANCE: If spot is under me, DO NOT DRAW IT.
        // This ensures the "Me" marker (drawn later) has no competition.
        if (_currentLocation != null) {
          final dist = Geolocator.distanceBetween(_currentLocation!.latitude,
              _currentLocation!.longitude, spot.latitude, spot.longitude);
          if (dist < 20) {
            // 20 meters radius
            logger.debug(
                "👻 Hiding spot ${spot.name} due to User Overlap (${dist.toStringAsFixed(1)}m)");
            continue;
          }
        }

        try {
          await mapController?.addSymbol(
            _getSpotSymbolStyle(spot),
            {
              'is_study_spot': true,
              'spot_id': spot.id,
              'is_verified': spot.isVerified,
              'is_sponsored': spot.isSponsored,
            },
          );
        } catch (e) {
          logger.warning("Failed to draw study spot ${spot.name}", error: e);
        }
      }

      for (var peer in {..._peers, ..._simulatedPeers}.values) {
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

        // 5. Min Rating
        if (peer.isTutor &&
            peer.averageRating != null &&
            peer.averageRating! < _filters.minRating) {
          continue;
        }

        try {
          if (!mounted) break; // STOP if the widget is disposed
          await mapController?.addSymbol(
            SymbolOptions(
              geometry: geometry,
              iconImage: peer.isTutor ? 'marker_tutor' : 'marker_student',
              iconSize: _getMarkerScale() *
                  0.85, // Peers slightly smaller than spots? Actually let's keep them consistent or just slightly smaller.
              // Let's explicitly try to make them "Normal" size.
              // If spots are 1.0 scale, peers at 0.85 scale seems okay distinction wise.
              // 70px * 0.85 = ~60px.
              iconOpacity: opacity,
              // symbolSortKey: 10, // Not supported in this version
            ),
            peer.toJson(),
          );
        } catch (e) {
          logger.warning("⚠️ Failed to add symbol: ${e.toString()}", error: e);
        }
      }

      // 1. Draw "Me" (Local Loopback - Instant) - DRAW LAST (On Top)
      if (_currentLocation != null && mapController != null) {
        // Pulse: ONLY draw if "Study Mode" (Ghost Mode Disabled) is ON
        if (_isStudyMode) {
          try {
            await mapController?.addCircle(
              CircleOptions(
                geometry: _currentLocation!,
                circleColor: '#00FF00',
                circleOpacity: 0.3,
                circleRadius: kIsWeb ? 28 : 45, // Larger pulse for mobile
                circleStrokeWidth: 2,
                circleStrokeColor: '#00FF00',
                circleBlur: 0.6,
              ),
              {'is_me': true, 'is_pulse': true},
            );
          } catch (e) {
            logger.warning("⚠️ Failed to draw my pulse", error: e);
          }
        }

        // Core Dot (Always Visible) - Using addSymbol for reliability
        try {
          String myIcon = 'marker_student';
          if (myProfile != null) {
            if (myProfile.isBusinessOwner) {
              myIcon = 'marker_sponsored';
            } else if (myProfile.isTutor) {
              myIcon = 'marker_tutor';
            }
          }

          await mapController?.addSymbol(
            SymbolOptions(
              geometry: _currentLocation!,
              iconImage: myIcon,
              iconSize: _getMarkerScale(),
              iconOpacity: 1.0,
              // Note: We can't force 'icon-allow-overlap' in addSymbol easily,
              // but we cleared nearby spots so it should be fine.
            ),
            {'is_me': true},
          );
        } catch (e) {
          logger.warning("⚠️ Failed to draw 'Me' symbol", error: e);
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
    if (circle.data != null) {
      _handleMarkerTap(Map<String, dynamic>.from(circle.data as Map));
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    if (symbol.data != null) {
      _handleMarkerTap(Map<String, dynamic>.from(symbol.data as Map));
    }
  }

  void _handleMarkerTap(Map<String, dynamic> data) {
    hapticService.selectionClick();

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

  void _showStudySpotDetails(StudySpot spot) {
    ref.read(isModalOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PointerInterceptor(
        child: StudySpotDetailsSheet(spot: spot),
      ),
    ).then((_) {
      if (mounted) ref.read(isModalOpenProvider.notifier).state = false;
    });
  }

  void _showProfileDrawer(Map<String, dynamic> data) {
    ref.read(isModalOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final profile = UserProfile.fromJson(data);
        return PointerInterceptor(
          child: GlassProfileDrawer(profile: profile),
        );
      },
    ).then((_) {
      if (mounted) ref.read(isModalOpenProvider.notifier).state = false;
    });
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
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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

    // 4. Trigger marker update when Profile loads (Fix for "Me" icon delay)
    ref.listen(myProfileProvider, (previous, next) {
      if (next.hasValue && previous?.hasValue != true) {
        _updateMapMarkers();
      }
    });

    // Listen to Ghost Mode changes
    ref.listen<AsyncValue<bool>>(ghostModeProvider, (prev, next) async {
      final wasGhost = prev?.value ?? false; // Default false (Visible)
      final isGhost = next.value ?? false;

      // Check for transition
      if (wasGhost != isGhost) {
        if (isGhost) {
          logger.debug("👻 Ghost Mode Enabled: Clearing location and presence");
          final messenger = ScaffoldMessenger.of(context);

          try {
            await _goGhost();
            if (mounted) _updatePresenceTracking();
          } catch (e) {
            logger.error("Failed to go ghost, reverting UI", error: e);
            // Revert user-visible state
            if (mounted) {
              ref.read(ghostModeProvider.notifier).setGhostMode(false);
              messenger.showSnackBar(
                SnackBar(
                    content: Text("Failed to enable Ghost Mode: $e"),
                    backgroundColor: Colors.red),
              );
            }
          }
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

    final isModalOpen = ref.watch(isModalOpenProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ... MapLibreMap ...
          if (_initialPosition != null)
            Stack(
              children: [
                IgnorePointer(
                  ignoring: isModalOpen,
                  child: MapLibreMap(
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    initialCameraPosition: _initialPosition!,
                    styleString: isDark ? _darkMapStyle : _lightMapStyle,
                    myLocationEnabled: false,
                    trackCameraPosition: true,
                    onCameraIdle: _onCameraIdle,
                    onCameraMove: _onCameraMove,
                    // NUCLEAR OPTION: Disable at the source
                    scrollGesturesEnabled: !isModalOpen,
                    zoomGesturesEnabled: !isModalOpen,
                    tiltGesturesEnabled: !isModalOpen,
                    rotateGesturesEnabled: !isModalOpen,
                    doubleClickZoomEnabled: !isModalOpen,
                    onMapClick: (point, latlng) {
                      // Removed click-to-dismiss as per user request
                    },
                  ),
                ),
                // Redundant blocker for Web/PlatformView gesture issues
                if (isModalOpen)
                  PointerInterceptor(
                    child: Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) {},
                        onPointerMove: (_) {},
                        onPointerUp: (_) {},
                        onPointerCancel: (_) {},
                        onPointerSignal: (_) {}, // Block scroll wheel
                        child: GestureDetector(
                          onScaleUpdate: (_) {},
                          onTap: () {},
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                              color: Colors.black.withValues(alpha: 0.01)),
                        ),
                      ),
                    ),
                  ),
              ],
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

          // Serendipity SOS Button (Bottom Left)
          // Always visible - Serendipity is now a core feature
          Positioned(
            bottom: 40,
            left: 20,
            child: PointerInterceptor(
              child: StruggleStatusWidget(
                  currentLocation: ref.watch(userLocationProvider).value ??
                      _currentLocation),
            ),
          ),

          // "Simulate Bot" Button (Top Left - DEV ONLY)
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 12),
                // Live/Ghost Mode Toggle
                _buildGlassControl(
                  isMini: true,
                  activeColor: _isStudyMode ? theme.primaryColor : null,
                  onPressed: () {
                    final currentGhost =
                        ref.read(ghostModeProvider).value ?? false;
                    final newGhost = !currentGhost;
                    hapticService.mediumImpact();
                    ref.read(ghostModeProvider.notifier).setGhostMode(newGhost);
                  },
                  child: Icon(
                    _isStudyMode ? Icons.visibility : Icons.visibility_off,
                    color: _isStudyMode
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                  tooltip: _isStudyMode ? "LIVE Mode" : "GHOST Mode",
                ),

                const SizedBox(height: 12),

                // Map Filter Widget (Moved here for equal spacing)
                PointerInterceptor(
                  child: MapFilterWidget(
                    currentFilters: _filters,
                    isExpanded: _isFilterExpanded,
                    onToggle: () {
                      hapticService.selectionClick();
                      setState(() => _isFilterExpanded = !_isFilterExpanded);
                    },
                    onFilterChanged: (newFilters) {
                      setState(() => _filters = newFilters);
                      hapticService.mediumImpact();
                      _updateMapMarkers();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
