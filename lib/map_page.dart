// ignore: unused_import
import 'dart:math'; // For random offset
import 'dart:ui'; // For ImageFilter
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_profile.dart';
import 'widgets/glass_profile_drawer.dart';
import 'profile_page.dart';
import 'services/logger_service.dart';
import 'services/haptic_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/map_filter_widget.dart';
import 'notifications_page.dart';
import 'models/study_spot.dart'; // NEW
import 'widgets/study_spot_details_sheet.dart'; // NEW

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MaplibreMapController? mapController;
  final supabase = Supabase.instance.client;
  bool _isStudyMode = false;

  // bool _botsSpawned = false; // REMOVED

  Map<String, UserProfile> _peers = {};
  StreamSubscription? _peersSubscription;
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _locationSubscription;
  Timer? _broadcastTimer;
  LatLng? _currentLocation;

  final Set<String> _seenRequests = {}; // Track shown requests
  MapFilters _filters = MapFilters(); // NEW: Filter State

  // Optimization: Smart Broadcast
  LatLng? _lastBroadcastLocation;
  DateTime? _lastBroadcastTime;
  int _unreadCount = 0; // Unread notifications
  RealtimeChannel? _notificationsChannel;

  // Cyber/Dark Style - Using CartoDB Dark Matter (free, widely available, very dark/cyber)
  static const String _mapStyle =
      "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json";

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _checkLocationPermissions();
    _startLocationUpdates();
    _subscribeToPeers();
    _subscribeToRequests();
    _subscribeToNotifications();
    _fetchStudySpots(); // NEW
  }

  List<StudySpot> _studySpots = []; // NEW

  Future<void> _fetchStudySpots() async {
    try {
      final data = await supabase
          .from('study_spots')
          .select(); // Fetches all columns including lat/long

      final spots = (data as List).map((e) => StudySpot.fromJson(e)).toList();
      setState(() {
        _studySpots = spots;
      });
      _updateMapMarkers(); // Refresh map
    } catch (e) {
      logger.error("Error fetching study spots", error: e);
    }
  }

  Future<void> _subscribeToNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Initial fetch
    final count = await supabase
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', user.id)
        .eq('read', false);

    if (mounted) setState(() => _unreadCount = count);

    // Listen
    _notificationsChannel = supabase
        .channel('public:notifications:${user.id}') // Unique channel per user
        .onPostgresChanges(
            event: PostgresChangeEvent.all, // Insert or Update
            schema: 'public',
            table: 'notifications',
            // Reliance on RLS for primary filtering, plus client-side check
            callback: (payload) async {
              final newRecord = payload.newRecord;
              if (newRecord['user_id'] != user.id) return;

              logger.debug("🔔 Notification received: ${payload.eventType}");

              // Refresh count on any change
              final newCount = await supabase
                  .from('notifications')
                  .count(CountOption.exact)
                  .eq('user_id', user.id)
                  .eq('read', false);
              if (mounted) setState(() => _unreadCount = newCount);
            })
        .subscribe();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Settings: "Ghost Mode" (Toggle). True = Hidden.
    // Map: "_isStudyMode" (Toggle). True = Live/Visible.
    // So: _isStudyMode = !ghostMode.
    final ghostMode = prefs.getBool('ghost_mode') ?? false;

    setState(() {
      _isStudyMode = !ghostMode;
    });

    if (_isStudyMode) {
      _startBroadcast();
    } else {
      _stopBroadcast(); // Ensure timer is stopped
      // Ensure we are hidden on startup if Ghost Mode is active
      _goGhost();
    }
  }

  Timer? _simulationTimer;
  // SupabaseClient? _botClient; // UNUSED since switching to local bots

  @override
  void dispose() {
    _peersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _locationSubscription?.cancel();
    _notificationsChannel?.unsubscribe();
    _stopBroadcast();
    _stopSimulation();
    super.dispose();
  }

  // Credentials (re-declared for simulation client usage)
  // Credentials (re-declared for simulation client usage)
  // static const _supabaseUrl = 'https://zzdasdmceaykwjsozums.supabase.co'; // UNUSED
  // static const _supabaseKey =
  //    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // UNUSED

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
      // OPTIMIZATION: Use cached stream location immediately if available
      if (_currentLocation != null && mapController != null) {
        logger.debug("📍 Using cached location: $_currentLocation");
        await mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 15),
          duration: const Duration(milliseconds: 800),
        );
        return;
      }

      // Fallback: Try to get fresh location if stream hasn't fired yet
      try {
        final position = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 2));
        logger.debug("📍 Got fresh position: $position");
        if (mapController != null && mounted) {
          await mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              15,
            ),
            duration: const Duration(milliseconds: 800),
          );
        }
      } catch (e) {
        logger.warning("⚠️ Location check timed out or failed", error: e);
      }
    }
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
    controller.onCircleTapped.add(_onCircleTapped);

    // DELAY: Fix for Web "Unexpected null value" / style loading race condition
    Future.delayed(const Duration(seconds: 2), () {});
  }

  void _startLocationUpdates() {
    const settings =
        LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    logger.debug("📍 Subscribing to location stream");

    // 2. Listen to stream
    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings)
            .listen((Position? position) {
      logger.debug("📍 Position update: $position");
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _updateMapMarkers();

        // Auto-Spawn Bots Logic Removed
      }
    });
  }

  void _subscribeToPeers() {
    logger.debug("📡 Subscribing to profiles stream");
    _peersSubscription = supabase.from('profiles').stream(
        primaryKey: ['user_id']).listen((List<Map<String, dynamic>> data) {
      logger.debug("📡 Received ${data.length} profile(s)");
      final newPeers = <String, UserProfile>{};
      for (var item in data) {
        // print("  - Peer Data: $item"); // Uncomment to debug full payload
        final profile = UserProfile.fromJson(item);
        // ALLOW SELF: Show everyone including myself to verify visibility
        newPeers[profile.userId] = profile;
        logger.debug("Added peer: ${profile.userId}");
      }
      if (mounted) {
        setState(() {
          _peers = newPeers;
          // Check if "I" am in the peers list to update my FAB avatar
          final myId = supabase.auth.currentUser?.id;
          if (myId != null && _peers.containsKey(myId)) {
            logger.debug("👤 My avatar URL: ${_peers[myId]?.avatarUrl}");
            // Force rebuild ensures FAB gets updated
          }
        });
        _updateMapMarkers();
      }
    }, onError: (err) {
      logger.error("🔴 Profile stream error", error: err);
    });
  }

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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text("Collab Request", style: TextStyle(color: Colors.white)),
        content: Text(
          "$senderName wants to collaborate!",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              hapticService.lightImpact();
              Navigator.pop(context);
              _respondToRequest(request['id'], request['sender_id'], false);
            },
            child:
                const Text("Reject", style: TextStyle(color: Colors.redAccent)),
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

  void _updateMapMarkers() async {
    if (mapController == null) {
      logger.warning("⚠️ Map controller is null, cannot update markers");
      return;
    }

    if (!mounted) {
      logger.warning("⚠️ Widget not mounted, skipping marker update");
      return;
    }

    try {
      logger.debug("📍 Updating markers for ${_peers.length} peer(s)");
      try {
        await mapController?.clearCircles();
      } catch (e) {
        logger.debug("⚠️ clearCircles failed (ignoring)", error: e);
      }

      // 0. Draw Study Spots (Bottom Layer)
      for (var spot in _studySpots) {
        try {
          await mapController?.addCircle(
            CircleOptions(
              geometry: LatLng(spot.latitude, spot.longitude),
              circleColor: '#FFA500', // Orange
              circleRadius: 8,
              circleStrokeWidth: 2,
              circleStrokeColor: '#FFFFFF',
              circleOpacity: 0.9,
            ),
            {
              'is_study_spot': true,
              'spot_id': spot.id,
            },
          );
        } catch (e) {
          logger.warning("Failed to draw study spot ${spot.name}");
        }
      }

      for (var peer in _peers.values) {
        final geometry = peer.location;
        if (geometry == null) {
          // logger.debug("Peer ${peer.userId} has null location"); // Keep valid noise down
          continue;
        }

        // SKIP MYSELF: I am already drawn as the "Me" circle with pulse
        if (peer.userId == supabase.auth.currentUser?.id) {
          continue;
        }

        // --- FILTER LOGIC ---
        if (peer.isTutor && !_filters.showTutors) {
          logger.debug("Active Filtering: Skipping Tutor ${peer.fullName}");
          continue;
        }
        if (!peer.isTutor && !_filters.showStudents) {
          logger.debug("Active Filtering: Skipping Student ${peer.fullName}");
          continue;
        }

        if (_filters.selectedSubjects.isNotEmpty) {
          // Case insensitive check
          final peerClasses =
              peer.currentClasses.map((e) => e.toLowerCase()).toList();
          final hasSubject = _filters.selectedSubjects
              .any((s) => peerClasses.contains(s.toLowerCase()));
          if (!hasSubject) {
            logger.debug(
                "Active Filtering: Skipping Subject Match for ${peer.fullName}");
            continue;
          }
        }
        // --------------------

        try {
          // logger.debug("Drawing marker at $geometry"); // Reduced noise
          await mapController?.addCircle(
            CircleOptions(
              geometry: geometry, // Safe local variable
              circleColor: peer.isTutor ? '#FFD700' : '#00FFFF',
              circleRadius: 10,
              circleStrokeWidth: 2,
              circleStrokeColor: '#FFFFFF',
              circleBlur: 0.2,
            ),
            peer.toJson(),
          );
        } catch (e) {
          logger.warning("⚠️ Failed to add circle: ${e.toString()}", error: e);
        }
      }

      // 1. Draw "Me" (Local Loopback - Instant) - DRAW LAST (On Top)
      if (_currentLocation != null && mapController != null) {
        logger.debug("📍 Drawing my location at $_currentLocation");

        try {
          // Only show PULSE effect if "Study Mode" (Ghost Mode Disabled) is ON
          if (_isStudyMode) {
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
          }

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
      } else {
        logger.warning("⚠️ Current location is null, cannot draw");
      }
    } catch (e) {
      logger.error("❌ Error updating map markers", error: e);
    }
  }

  void _startBroadcast() {
    _broadcastTimer?.cancel();
    // Check more frequently (e.g. 5s) but only WRITE if threshold met
    _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // SAFETY CHECK: Stop this timer if we are in Ghost Mode or widget disposed
      if (!mounted || !_isStudyMode) {
        timer.cancel();
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final currentLatLng = LatLng(pos.latitude, pos.longitude);
      final now = DateTime.now();

      bool shouldUpdate = false;

      // 1. Time Check (Heartbeat every 60s)
      if (_lastBroadcastTime == null ||
          now.difference(_lastBroadcastTime!).inSeconds >= 60) {
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
            "📍 Broadcaster: Upserting location ${pos.latitude}, ${pos.longitude}");
        try {
          await supabase.from('profiles').upsert({
            'user_id': user.id,
            'lat': pos.latitude,
            'long': pos.longitude,
            'last_updated': DateTime.now().toIso8601String(),
          });
          _lastBroadcastLocation = currentLatLng;
          _lastBroadcastTime = now;
        } catch (e) {
          logger.error("❌ Broadcaster: Upsert failed", error: e);
        }
      }
    });
  }

  void _stopBroadcast() {
    logger.debug("🛑 Broadcaster: Stopped");
    _broadcastTimer?.cancel();
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
      barrierColor: Colors.black12,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) {
        // Convert the generic map data back to UserProfile
        // Keys in data come from UserProfile.toJson() which uses snake_case, so fromJson works.
        final profile = UserProfile.fromJson(data);
        return GlassProfileDrawer(profile: profile);
      },
    );
  }

  Future<void> _summonPeers() async {
    if (_currentLocation == null) return;

    setState(() {}); // Re-use loading flag logic if needed, or just plain.
    hapticService.mediumImpact();

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Get all other profiles (real users)
      // We can't filter by email effectively without Admin, so we just grab everyone who isn't me.
      final response = await supabase
          .from('profiles')
          .select('user_id')
          .neq('user_id', user.id);

      final List<dynamic> others = response as List<dynamic>;

      logger.info("🪄 Summoning ${others.length} peers to your location...");

      final random = Random();
      int movedCount = 0;

      for (var other in others) {
        final uid = other['user_id'] as String;

        // Random offset within ~300m (approx 0.003 degrees)
        final double latOffset = (random.nextDouble() * 0.006) - 0.003;
        final double lngOffset = (random.nextDouble() * 0.006) - 0.003;

        final newLat = _currentLocation!.latitude + latOffset;
        final newLng = _currentLocation!.longitude + lngOffset;

        await supabase.from('profiles').update({
          'lat': newLat,
          'long': newLng,
          'last_updated': DateTime.now().toIso8601String(),
        }).eq('user_id', uid);

        movedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Summoned $movedCount peers to your vicinity!"),
            backgroundColor: Colors.purpleAccent,
          ),
        );
      }
    } catch (e) {
      logger.error("Summon failed", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Summon failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _summonStudySpots() async {
    if (_currentLocation == null) return;

    hapticService.mediumImpact();

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Get all study spots
      final response = await supabase.from('study_spots').select();
      final List<dynamic> spots = response as List<dynamic>;

      logger.info("🪄 Transporting ${spots.length} study spots to you...");

      final random = Random();
      int movedCount = 0;

      for (var spot in spots) {
        final spotId = spot['id'] as String;

        // Random offset within ~500m (approx 0.005 degrees)
        final double latOffset = (random.nextDouble() * 0.008) - 0.004;
        final double lngOffset = (random.nextDouble() * 0.008) - 0.004;

        final newLat = _currentLocation!.latitude + latOffset;
        final newLng = _currentLocation!.longitude + lngOffset;

        // Update with both separate columns and PostGIS geometry
        await supabase.from('study_spots').update({
          'lat': newLat,
          'long': newLng,
          // 'location': ... generated column updates automatically?
          // WAIT: Created as "generated always stored". We cannot update it directly.
          // Correct, we just update lat/long and the DB handles 'location'.
        }).eq('id', spotId);

        movedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Transported $movedCount Study Spots! ☕"),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchStudySpots(); // Refresh local list
      }
    } catch (e) {
      logger.error("Summon Spots failed", error: e);
    }
  }

  // Bot simulation logic removed

  void _stopSimulation() {
    _simulationTimer?.cancel();
    // _botClient?.dispose();
    // _botClient = null;
  }

  Future<void> _goGhost() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      logger.debug("👻 Going Ghost: Clearing location from DB...");
      await supabase.from('profiles').update({
        'lat': null,
        'long': null,
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('user_id', user.id);
    } catch (e) {
      logger.error("Failed to go ghost", error: e);
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
            color: Colors.black.withOpacity(0.1),
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
                .withOpacity(0.7),
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

    return Scaffold(
      body: Stack(
        children: [
          // ... MapLibreMap ...
          MaplibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(40.7128, -74.0060),
              zoom: 14,
            ),
            styleString: _mapStyle,
            myLocationEnabled: false,
            trackCameraPosition: true,
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
                    ).then((_) => _loadSettings());
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
                                      : NetworkImage(
                                          _peers[supabase.auth.currentUser!.id]!
                                              .avatarUrl!),
                              radius: 18,
                            )
                          : Icon(Icons.person,
                              color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 12),
                // Summon Button (Testing)
                _buildGlassControl(
                  isMini: true,
                  onPressed: _summonPeers,
                  activeColor: Colors.purple.withOpacity(0.5),
                  child: const Icon(Icons.group_add, color: Colors.white),
                  tooltip: "Summon Peers (Test)",
                ),
                const SizedBox(height: 12),
                // Summon Spots Button (Testing)
                _buildGlassControl(
                  isMini: true,
                  onPressed: _summonStudySpots,
                  activeColor: Colors.orange.withOpacity(0.5),
                  child: const Icon(Icons.coffee, color: Colors.white),
                  tooltip: "Summon Study Spots (Test)",
                ),
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
                    if (_unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
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
                setState(() {
                  _isStudyMode = !_isStudyMode;
                });
                hapticService.mediumImpact();
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setBool('ghost_mode', !_isStudyMode);
                });

                if (_isStudyMode) {
                  _startBroadcast();
                } else {
                  _stopBroadcast();
                  _goGhost();
                }
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
                          .withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
