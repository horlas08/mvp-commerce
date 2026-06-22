import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/address_controller.dart';

class MapPickerScreen extends StatefulWidget {
  final String addressId;
  final String addressLabel;
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    required this.addressId,
    required this.addressLabel,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with OSMMixinObserver {
  // Default to Riyadh
  static const double _defaultLat = 24.7136;
  static const double _defaultLng = 46.6753;

  late MapController _mapController;
  GeoPoint _markerPosition = GeoPoint(
    latitude: _defaultLat,
    longitude: _defaultLng,
  );
  bool _isConfirming = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();

    final initLat = widget.initialLat ?? _defaultLat;
    final initLng = widget.initialLng ?? _defaultLng;
    _markerPosition = GeoPoint(latitude: initLat, longitude: initLng);

    _mapController = MapController.withPosition(
      initPosition: _markerPosition,
    );
    _mapController.addObserver(this);
  }

  // ── OSMMixinObserver ───────────────────────────────────────────────────────

  @override
  void onSingleTap(GeoPoint position) {
    super.onSingleTap(position);
    _placeMarker(position);
    setState(() => _markerPosition = position);
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (!isReady) return;
    setState(() => _mapReady = true);

    // Place the initial marker
    await _placeMarker(_markerPosition);

    // If no initial position supplied → jump to device location
    if (widget.initialLat == null || widget.initialLng == null) {
      await _fetchCurrentLocation();
    }
  }

  @override
  Future<void> mapRestored() async {
    super.mapRestored();
    if (_mapReady) {
      await _placeMarker(_markerPosition);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _placeMarker(GeoPoint point) async {
    try {
      // Remove previous marker (ignore errors if none exists yet)
      await _mapController.removeMarker(_markerPosition);
    } catch (_) {}
    await _mapController.addMarker(
      point,
      markerIcon: const MarkerIcon(
        icon: Icon(Icons.location_on, color: AppColors.primary, size: 48),
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newPoint = GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _placeMarker(newPoint);
      await _mapController.moveTo(newPoint, animate: true);
      setState(() => _markerPosition = newPoint);
    } catch (_) {
      // Silently ignore – map already shows default position
    }
  }

  Future<void> _confirmLocation() async {
    setState(() => _isConfirming = true);
    final controller = Get.find<AddressController>();
    final success = await controller.linkLocation(
      widget.addressId,
      _markerPosition.latitude,
      _markerPosition.longitude,
    );
    setState(() => _isConfirming = false);
    if (success) {
      Get.back();
      Get.snackbar(
        'success'.tr(),
        'location_saved'.tr(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } else {
      Get.snackbar(
        'error'.tr(),
        'error_occurred'.tr(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── OSM Map ────────────────────────────────────────────────────────
          OSMFlutter(
            controller: _mapController,
            osmOption: OSMOption(
              zoomOption: const ZoomOption(
                initZoom: 15,
                minZoomLevel: 3,
                maxZoomLevel: 19,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.my_location,
                    color: AppColors.secondary,
                    size: 42,
                  ),
                ),
                directionArrowMarker: const MarkerIcon(
                  icon: Icon(Icons.navigation, size: 42),
                ),
              ),
            ),
            mapIsLoading: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            onGeoPointClicked: (point) async {
              // Tapping the existing marker also repositions it
              await _placeMarker(point);
              setState(() => _markerPosition = point);
            },
          ),

          // ── Top bar ────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                          ),
                          onPressed: () => Get.back(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.addressLabel,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'drag_marker'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2),
                ],
              ),
            ),
          ),

          // ── Current-location FAB ───────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _fetchCurrentLocation,
              child: const Icon(
                Icons.my_location,
                color: AppColors.primary,
              ),
            ),
          ),

          // ── Confirm button ─────────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _isConfirming ? null : _confirmLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isConfirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'confirm_location'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
