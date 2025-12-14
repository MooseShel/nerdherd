import 'dart:math';
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

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MaplibreMapController? mapController;
  final supabase = Supabase.instance.client;
  bool _isStudyMode = false;
  bool _botsSpawned = false; // Track if we've auto-spawned bots

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
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isStudyMode = prefs.getBool('ghost_mode') ?? false;
    });
    // If we loaded as TRUE (Study Mode ON => Hidden), we actually need to decide if "Study Mode" means VISIBLE or HIDDEN.
    // In previous code: _isStudyMode ON ("LIVE") => VISIBLE (startBroadcast). OFF => HIDDEN.
    // In settings: "Ghost Mode" ON => HIDDEN.
    // SO: _isStudyMode = !_ghostMode.
    // Wait, let's align names. "Ghost Mode" = Hidden. "Study Mode" = Visible/Live.
    // So if GhostMode is TRUE, StudyMode should be FALSE.
    if (prefs.getBool('ghost_mode') == true) {
      _isStudyMode = false;
    } else {
      // Default logic: start as ghost? or start as previous?
      // Let's assume default is OFF (Ghost Mode OFF -> Visible).
      // Actually, default safely should be Hidden.
    }

    // CORRECTION:
    // Settings: "Ghost Mode" (Toggle). True = Hidden.
    // Map: "_isStudyMode" (Toggle). True = Live/Visible.
    // So: _isStudyMode = !ghostMode.
    final ghostMode = prefs.getBool('ghost_mode') ??
        false; // Default false (Visible) ? OR Default true (Hidden)?
    // User requested "Default Ghost Mode toggle" in plan.

    _isStudyMode = !ghostMode;

    if (_isStudyMode) {
      _startBroadcast();
    }
  }

  Timer? _simulationTimer;
  // SupabaseClient? _botClient; // UNUSED since switching to local bots

  @override
  void dispose() {
    _peersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _locationSubscription?.cancel();
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

        // Auto-Spawn Bots (Once)
        if (!_botsSpawned) {
          _botsSpawned = true;
          _simulateBot(LatLng(position.latitude, position.longitude));
        }
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

      for (var peer in _peers.values) {
        if (peer.location == null) {
          logger.debug("Peer ${peer.userId} has null location");
          continue;
        }

        // SKIP MYSELF: I am already drawn as the "Me" circle with pulse
        if (peer.userId == supabase.auth.currentUser?.id) {
          continue;
        }

        // --- FILTER LOGIC ---
        if (peer.isTutor && !_filters.showTutors) continue;
        if (!peer.isTutor && !_filters.showStudents) continue;

        if (_filters.selectedSubjects.isNotEmpty) {
          // Case insensitive check
          final peerClasses =
              peer.currentClasses.map((e) => e.toLowerCase()).toList();
          final hasSubject = _filters.selectedSubjects
              .any((s) => peerClasses.contains(s.toLowerCase()));
          if (!hasSubject) continue;
        }
        // --------------------

        try {
          logger.debug("Drawing marker at ${peer.location}");
          await mapController?.addCircle(
            CircleOptions(
              geometry: peer.location!,
              circleColor: peer.isTutor ? '#FFD700' : '#00FFFF',
              circleRadius: 10,
              circleStrokeWidth: 2,
              circleStrokeColor: '#FFFFFF',
              circleBlur: 0.2,
            ),
            peer.toJson(),
          );
        } catch (e) {
          logger.warning("⚠️ Failed to add circle for peer ${peer.userId}",
              error: e);
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
    _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
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
        logger.debug("📍 Broadcasting location update (Smart)");
        await supabase.from('profiles').upsert({
          'user_id': user.id,
          'lat': pos.latitude,
          'long': pos.longitude,
          'last_updated': DateTime.now().toIso8601String(),
        });
        _lastBroadcastLocation = currentLatLng;
        _lastBroadcastTime = now;
      }
    });
  }

  void _stopBroadcast() {
    _broadcastTimer?.cancel();
  }

  void _onCircleTapped(Circle circle) {
    hapticService.selectionClick();
    if (circle.data != null) {
      final data = Map<String, dynamic>.from(circle.data as Map);
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

  // Bot Simulation Logic
  void _simulateBot(LatLng userPos) async {
    logger.info(
        "🤖 Spawning 4 bots around ${userPos.latitude}, ${userPos.longitude}");

    try {
      final random = Random();
      final newBots = <String, UserProfile>{};

      // Helper to get random offset within ~50 meters to ~500 meters
      // 500 meters ≈ 0.0045 degrees latitude
      double getRandomOffset() {
        const minOffset = 0.0005; // ~50m (avoid stacking on user)
        const maxOffset = 0.0045; // ~500m
        const range = maxOffset - minOffset;
        final offset = minOffset + (random.nextDouble() * range);
        // Randomly make it positive or negative
        return random.nextBool() ? offset : -offset;
      }

      // UPSERT Tutors to Database
      for (int i = 0; i < 2; i++) {
        // Deterministic UUIDs for Tutors (starts with 1 or 2)
        // Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        final id = "00000000-0000-4000-a000-00000000000${i + 1}";
        final offsetLat = getRandomOffset();
        final offsetLong = getRandomOffset();

        final botProfile = UserProfile(
          userId: id,
          isTutor: true,
          intentTag: 'Tutor Bot ${i + 1}',
          fullName: 'Tutor ${String.fromCharCode(65 + i)}.',
          currentClasses: ['Calculus', 'Physics'],
          avatarUrl: 'assets/images/bot.jpg',
          location: LatLng(
              userPos.latitude + offsetLat, userPos.longitude + offsetLong),
        );

        newBots[id] = botProfile;

        await supabase.from('profiles').upsert({
          'user_id': id,
          'is_tutor': true,
          'intent_tag': 'Tutor Bot ${i + 1}',
          'full_name': 'Tutor ${String.fromCharCode(65 + i)}.',
          'current_classes': ['Calculus', 'Physics'],
          'lat': botProfile.location!.latitude,
          'long': botProfile.location!.longitude,
          'avatar_url': 'assets/images/bot.jpg',
          'last_updated': DateTime.now().toIso8601String(),
        });
      }

      // UPSERT Students to Database
      for (int i = 0; i < 2; i++) {
        // Deterministic UUIDs for Students (starts with 3 or 4)
        final id = "00000000-0000-4000-b000-00000000000${i + 1}";
        final offsetLat = getRandomOffset();
        final offsetLong = getRandomOffset();

        final botProfile = UserProfile(
          userId: id,
          isTutor: false,
          intentTag: 'Student Bot ${i + 1}',
          fullName: 'Student ${i + 1}',
          currentClasses: ['History', 'Art'],
          avatarUrl: 'assets/images/bot.jpg',
          location: LatLng(
              userPos.latitude + offsetLat, userPos.longitude + offsetLong),
        );

        newBots[id] = botProfile;

        await supabase.from('profiles').upsert({
          'user_id': id,
          'is_tutor': false,
          'intent_tag': 'Student Bot ${i + 1}',
          'full_name': 'Student ${i + 1}',
          'current_classes': ['History', 'Art'],
          'lat': botProfile.location!.latitude,
          'long': botProfile.location!.longitude,
          'avatar_url': 'assets/images/bot.jpg',
          'last_updated': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        setState(() {
          _peers.addAll(newBots);
        });
        _updateMapMarkers(); // Force draw
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Spawned 4 Bots (DB & Local)!"),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      logger.error("⚠️ Simulation error", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sim Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    // _botClient?.dispose();
    // _botClient = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ... MapLibreMap ...
          MaplibreMap(
            // ... existing config ...
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(40.7128, -74.0060),
              zoom: 14,
            ),
            styleString: _mapStyle,
            myLocationEnabled: false,
          ),

          // "Recenter" Button (Bottom Right)
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              heroTag: "recenter",
              onPressed: _checkLocationPermissions,
              backgroundColor: Colors.black87,
              foregroundColor: Colors.cyanAccent,
              child: const Icon(Icons.my_location),
            ),
          ),

          // "Simulate Bot" Button (Top Left - DEV ONLY)
          Positioned(
            top: 50,
            left: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "profile",
                  mini: true,
                  onPressed: () {
                    hapticService.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    ).then((_) => _loadSettings());
                  },
                  backgroundColor: const Color(0xFF0F111A),
                  foregroundColor: Colors.white,
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
                              radius: 20, // Matches mini FAB size (40x40)
                            )
                          : const Icon(Icons.person),
                ),
              ],
            ),
          ),

          // Floating "Study Mode" Toggle (Top Right)
          // ...
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: "studymode",
              onPressed: () {
                setState(() {
                  _isStudyMode = !_isStudyMode;
                });
                hapticService.mediumImpact();
                // Save "Ghost Mode" preference (Inverse of Study Mode)
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setBool('ghost_mode', !_isStudyMode);
                });

                if (_isStudyMode) {
                  _startBroadcast();
                } else {
                  _stopBroadcast();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isStudyMode
                        ? "Study Mode ON: You are visible"
                        : "Study Mode OFF: You are hidden"),
                    backgroundColor: _isStudyMode ? Colors.cyan : Colors.grey,
                  ),
                );
              },
              label: Text(_isStudyMode ? "LIVE" : "GHOST"),
              icon:
                  Icon(_isStudyMode ? Icons.visibility : Icons.visibility_off),
              backgroundColor:
                  _isStudyMode ? Colors.cyanAccent : Colors.grey[800],
              foregroundColor: _isStudyMode ? Colors.black : Colors.white,
            ),
          ),
          // Filter Widget
          Positioned(
            top: 120,
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
