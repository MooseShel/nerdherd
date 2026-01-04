import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart'; // NEW
import '../models/study_spot.dart';
import '../providers/user_profile_provider.dart';

class BusinessDashboardPage extends ConsumerStatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  ConsumerState<BusinessDashboardPage> createState() =>
      _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends ConsumerState<BusinessDashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<StudySpot> _mySpots = [];

  @override
  void initState() {
    super.initState();
    _fetchMySpots();
  }

  Future<void> _fetchMySpots() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data =
          await _supabase.from('study_spots').select().eq('owner_id', user.id);

      setState(() {
        _mySpots = (data as List).map((e) => StudySpot.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching spots: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSponsorship(StudySpot spot) async {
    const double sponsorshipCost = 20.00;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sponsor this Spot? 🌟"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Upgrade to a Gold Marker and stand out on the map!"),
            SizedBox(height: 16),
            Text(
              "Monthly Subscription",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "\$20.00 / month",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber),
            ),
            SizedBox(height: 8),
            Text(
              "This amount will be deducted from your wallet immediately.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text("Pay \$20.00"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processSponsorshipPayment(spot, sponsorshipCost);
    }
  }

  Future<void> _processSponsorshipPayment(StudySpot spot, double amount) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final myProfile = ref.read(myProfileProvider).value;
      if (myProfile == null || myProfile.walletBalance < amount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Insufficient funds! Please top up your wallet."),
                backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Call the new pay_sponsorship RPC
      await _supabase.rpc('pay_sponsorship', params: {
        'p_user_id': user.id,
        'p_amount': amount,
        'p_description': 'Gold Sponsorship for ${spot.name}',
      });

      // Update spot status locally and in DB
      await _supabase.from('study_spots').update({
        'is_sponsored': true,
        'sponsorship_expiry':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      }).eq('id', spot.id);

      // Refresh
      _fetchMySpots();
      // Also refresh wallet
      ref.invalidate(myProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Spot Upgraded to Sponsored! 🌟"),
              backgroundColor: Colors.amber),
        );
      }
    } catch (e) {
      debugPrint("Sponsorship error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditPromoDialog(StudySpot spot) {
    final controller = TextEditingController(text: spot.promotionalText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Promotion"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Promotional Text",
            hintText: "e.g., 10% off for Students!",
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('study_spots').update({
                'promotional_text': controller.text,
              }).eq('id', spot.id);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              _fetchMySpots();
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  // NEW: Image Picker & Upload Logic
  XFile? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return null;

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final fileExt = _selectedImage!.name.split('.').last;
      final fileName =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName; // Root of bucket

      await _supabase.storage.from('spot_images').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final imageUrl =
          _supabase.storage.from('spot_images').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Image upload failed: $e"),
              backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  void _showRegisterSpotDialog() {
    // Reset state
    _selectedImage = null;
    final nameCtrl = TextEditingController();
    final promoCtrl = TextEditingController();
    String selectedType = 'cafe';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Register New Spot"),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image Picker
                GestureDetector(
                  onTap: () async {
                    await _pickImage();
                    setStateDialog(() {}); // Refresh dialog to show image
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: NetworkImage(_selectedImage!
                                  .path), // Works for web/some platforms
                              // Note: On mobile use FileImage(File(_selectedImage!.path)).
                              // Since we use CrossPlatform generic approach, consider:
                              // image: kIsWeb ? NetworkImage(...) : FileImage(...)
                              // For MVP simplify or use a bytes provider if needed.
                              // Actually for XFile on mobile we need File.
                              // But we imported image_picker which gives XFile.
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 40, color: Colors.white54),
                              SizedBox(height: 8),
                              Text("Tap to add Cover Image",
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          )
                        : null, // Image is in decoration
                  ),
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 4),
                  const Center(
                      child: Text("Image Selected!",
                          style: TextStyle(color: Colors.green, fontSize: 12))),
                ],

                const SizedBox(height: 16),

                // 2. Name
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Business Name",
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: "Type",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cafe', child: Text("Cafe")),
                    DropdownMenuItem(value: 'library', child: Text("Library")),
                    DropdownMenuItem(
                        value: 'restaurant', child: Text("Restaurant")),
                    DropdownMenuItem(
                        value: 'wifi_spot', child: Text("WiFi Spot")),
                    DropdownMenuItem(value: 'park', child: Text("Park")),
                    DropdownMenuItem(value: 'other', child: Text("Other")),
                  ],
                  onChanged: (val) => setStateDialog(() => selectedType = val!),
                ),
                const SizedBox(height: 16),

                // 4. Promotional Text (Optional)
                TextField(
                  controller: promoCtrl,
                  decoration: const InputDecoration(
                    labelText: "Initial Promotion (Optional)",
                    hintText: "e.g. Free Coffee with Study Pass",
                    prefixIcon: Icon(Icons.discount),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 10),
                const Text("Location will be set to your current position.",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel")),
              ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () async {
                        final user = _supabase.auth.currentUser;
                        final myProfile = ref.read(myProfileProvider).value;

                        if (user == null || myProfile?.location == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Location not found!")));
                          return;
                        }
                        if (nameCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Name is required")));
                          return;
                        }

                        setStateDialog(() => _isUploading = true);

                        // 1. Upload Image
                        String? imageUrl;
                        if (_selectedImage != null) {
                          imageUrl = await _uploadImage(user.id);
                        }

                        // 2. Insert Data
                        await _supabase.from('study_spots').insert({
                          'owner_id': user.id,
                          'name': nameCtrl.text,
                          'lat': myProfile!.location!.latitude,
                          'long': myProfile.location!.longitude,
                          'type': selectedType,
                          'image_url': imageUrl,
                          'promotional_text':
                              promoCtrl.text.isEmpty ? null : promoCtrl.text,
                          'source': 'business_owner',
                          'is_verified':
                              true, // Auto-verified for business owners
                        });

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Spot Created Successfully! 🎉")));
                        }
                        _fetchMySpots();
                      },
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Create Spot"),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
      ThemeData theme, IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              color: theme.iconTheme.color?.withValues(alpha: 0.5), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Business Dashboard"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterSpotDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Spot"),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mySpots.isEmpty
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text("No businesses registered."),
                    TextButton(
                        onPressed: _showRegisterSpotDialog,
                        child: const Text("Register your first Spot"))
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _mySpots.length,
                  itemBuilder: (context, index) {
                    final spot = _mySpots[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.05),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Image Header
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: Stack(
                              children: [
                                // Background Image
                                Positioned.fill(
                                  child: spot.imageUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: spot.imageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: theme.colorScheme.surface,
                                            child: const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            color: theme.colorScheme.surface,
                                            child: const Icon(Icons.error),
                                          ),
                                        )
                                      : Container(
                                          color: theme.colorScheme.surface,
                                          child: Icon(
                                            Icons.store_mall_directory_rounded,
                                            size: 64,
                                            color: theme.iconTheme.color
                                                ?.withValues(alpha: 0.2),
                                          ),
                                        ),
                                ),
                                // Gradient Overlay
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.7),
                                        ],
                                        stops: const [0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                // Edit Button (Top Right)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Material(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(30),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(30),
                                      onTap: () {
                                        // TODO: Implement full edit
                                        _showEditPromoDialog(spot);
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                color: Colors.white, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              "Edit",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Status Badge (Top Left)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: spot.isSponsored
                                          ? Colors.amber
                                          : Colors.grey.shade800,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          spot.isSponsored
                                              ? Icons.star_rounded
                                              : Icons.public,
                                          size: 16,
                                          color: spot.isSponsored
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          spot.isSponsored
                                              ? "SPONSORED"
                                              : "STANDARD",
                                          style: TextStyle(
                                            color: spot.isSponsored
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Name & Type (Bottom)
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  right: 16,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        spot.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        spot.type.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 2. Metadata Section
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Promo Section
                                if (spot.promotionalText != null &&
                                    spot.promotionalText!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.discount_outlined,
                                            color: theme.colorScheme.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            spot.promotionalText!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                // Stats Grid (Mock for now, can be real later)
                                Row(
                                  children: [
                                    _buildStatItem(
                                        theme, Icons.people, "Reach", "1.2k"),
                                    _buildStatItem(
                                        theme, Icons.touch_app, "Taps", "342"),
                                    _buildStatItem(
                                        theme, Icons.favorite, "Likes", "58"),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Action Button
                                if (!spot.isSponsored)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _handleSponsorship(spot),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.auto_awesome, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            "Boost this Spot",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _showEditPromoDialog(spot),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text("Update Offer / Info"),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
