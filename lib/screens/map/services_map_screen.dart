import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:booking_system_flutter/component/custom_map_marker.dart';
import 'package:booking_system_flutter/main.dart';
import 'package:booking_system_flutter/utils/map_cluster_helper.dart';
import 'package:nb_utils/nb_utils.dart';

/// Services Map Screen with Clustering
/// 
/// Features:
/// - Zoom threshold: 16 (clusters below, individuals at 16+)
/// - Cluster sizes: 90-170px based on count
/// - Individual marker size: 150px
/// - Dynamic re-clustering on zoom
class ServicesMapScreen extends StatefulWidget {
  final List<dynamic> services; // Can be PostJobData or any service model
  final Function()? onFilterApplied;
  
  const ServicesMapScreen({
    super.key,
    required this.services,
    this.onFilterApplied,
  });

  @override
  State<ServicesMapScreen> createState() => _ServicesMapScreenState();
}

class _ServicesMapScreenState extends State<ServicesMapScreen> {
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  double _currentZoom = 12.0;
  bool _isUpdatingMarkers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setMarkers();
    });
  }

  @override
  void didUpdateWidget(ServicesMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update markers if services list changed
    if (widget.services != oldWidget.services) {
      _setMarkers();
    }
  }

  Future<void> _setMarkers() async {
    // Prevent concurrent marker updates
    if (_isUpdatingMarkers) {
      print('⏳ Already updating markers, skipping...');
      return;
    }
    
    _isUpdatingMarkers = true;
    
    print('🗺️ Setting up clustering for ${widget.services.length} services at zoom $_currentZoom...');
    
    // Clear all existing markers first
    _markers.clear();
    
    // Filter valid services with coordinates
    List<dynamic> validServices = widget.services
        .where((service) => 
            _getLatitude(service) != null && 
            _getLongitude(service) != null)
        .toList();
    
    if (validServices.isEmpty) {
      _isUpdatingMarkers = false;
      if (mounted) setState(() {});
      return;
    }
    
    // Create clusters using the helper
    List<MapCluster> clusters = MapClusterHelper.clusterJobs(validServices, _currentZoom);
    
    print('✅ Created ${clusters.length} clusters from ${validServices.length} services');
    
    // Track processed service IDs to ensure no duplicates
    Set<String> processedIds = {};
    
    // Create markers for each cluster
    for (var cluster in clusters) {
      if (cluster.isCluster) {
        // Multiple services - create cluster marker
        print('🎯 Cluster: ${cluster.count} items, Total: \$${cluster.totalPrice.toStringAsFixed(0)}');
        
        // Mark all services in this cluster as processed
        for (var loc in cluster.locations) {
          final id = _getServiceId(loc.data);
          if (id != null) processedIds.add(id);
        }
        
        // Get dynamic cluster size based on count
        final clusterSize = MapClusterHelper.getClusterSize(cluster.count);
        final clusterColor = Color(MapClusterHelper.getClusterColor(cluster.count));
        
        final icon = await CustomMapMarker.createEnhancedClusterMarker(
          count: cluster.count,
          avgPrice: cluster.totalPrice.toStringAsFixed(0),
          currency: '\$',
          color: clusterColor,
          size: clusterSize,
        );
        
        // Use unique cluster ID based on location IDs
        String clusterKey = cluster.locations
            .map((l) => _getServiceId(l.data) ?? '${l.position.latitude}_${l.position.longitude}')
            .join('_');
        
        _markers.add(Marker(
          markerId: MarkerId('cluster_$clusterKey'),
          position: cluster.center,
          icon: icon,
          onTap: () {
            // Zoom to next level to expand cluster
            if (_currentZoom < 18) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(cluster.center, _currentZoom + 2),
              );
            } else {
              // At max zoom, show cluster details
              _showClusterDetails(cluster);
            }
          },
        ));
      } else {
        // Single service - create individual marker
        final location = cluster.locations.first;
        final service = location.data;
        
        final serviceId = _getServiceId(service);
        
        // Check if this service was already processed
        if (serviceId != null && processedIds.contains(serviceId)) {
          print('⚠️ Service #$serviceId already processed, skipping...');
          continue;
        }
        if (serviceId != null) processedIds.add(serviceId);
        
        String imageUrl = _getServiceImage(service);
        
        print('📍 Single: Service #$serviceId');
        
        // Larger individual marker size - 150px
        final markerIcon = await CustomMapMarker.createServiceImageMarker(
          imageUrl: imageUrl,
          price: location.price.toStringAsFixed(0),
          currency: '\$',
          size: 150,
          borderColor: Colors.white,
          priceBgColor: context.primaryColor,
        );
        
        _markers.add(Marker(
          markerId: MarkerId('service_${serviceId ?? location.position.toString()}'),
          position: location.position,
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: _getServiceTitle(service),
            snippet: '\$${location.price.toStringAsFixed(0)}',
          ),
          onTap: () {
            _handleServiceTap(service);
          },
        ));
      }
    }

    print('🏁 Final marker count: ${_markers.length}');
    
    _isUpdatingMarkers = false;
    if (mounted) setState(() {});
  }

  /// Show cluster details in bottom sheet
  void _showClusterDetails(MapCluster cluster) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: context.primaryColor, size: 28),
                12.width,
                Text('Cluster Details', style: boldTextStyle(size: 20)),
              ],
            ),
            16.height,
            Divider(),
            16.height,
            _buildDetailRow(Icons.pin_drop, 'Total Services', '${cluster.count}'),
            12.height,
            _buildDetailRow(Icons.attach_money, 'Total Price', '\$${cluster.totalPrice.toStringAsFixed(2)}'),
            12.height,
            _buildDetailRow(Icons.calculate, 'Average Price', '\$${cluster.avgPrice.toStringAsFixed(2)}'),
            24.height,
            AppButton(
              text: 'Zoom In to Explore',
              color: context.primaryColor,
              textColor: Colors.white,
              width: context.width(),
              onTap: () {
                Navigator.pop(context);
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(cluster.center, 16),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.iconColor),
        12.width,
        Text(label, style: secondaryTextStyle()),
        Spacer(),
        Text(value, style: boldTextStyle()),
      ],
    );
  }

  /// Handle individual service tap - override this method based on your needs
  void _handleServiceTap(dynamic service) {
    print('Tapped service: ${_getServiceTitle(service)}');
    // Add your navigation logic here
    // Example: JobPostDetailScreen(postJobData: service).launch(context);
  }

  // Helper methods to extract data from different service model structures
  
  double? _getLatitude(dynamic service) {
    try {
      if (service == null) return null;
      
      // Try direct property access
      if (service.latitude != null) {
        return (service.latitude is double) 
            ? service.latitude 
            : service.latitude.toDouble();
      }
      
      // Try as Map
      if (service is Map) {
        final lat = service['latitude'] ?? service['lat'];
        return lat?.toDouble();
      }
    } catch (e) {
      print('Error getting latitude: $e');
    }
    return null;
  }
  
  double? _getLongitude(dynamic service) {
    try {
      if (service == null) return null;
      
      // Try direct property access
      if (service.longitude != null) {
        return (service.longitude is double) 
            ? service.longitude 
            : service.longitude.toDouble();
      }
      
      // Try as Map
      if (service is Map) {
        final lng = service['longitude'] ?? service['lng'] ?? service['long'];
        return lng?.toDouble();
      }
    } catch (e) {
      print('Error getting longitude: $e');
    }
    return null;
  }
  
  String? _getServiceId(dynamic service) {
    try {
      if (service == null) return null;
      
      // Try direct property access
      if (service.id != null) return service.id.toString();
      
      // Try as Map
      if (service is Map) {
        return service['id']?.toString();
      }
    } catch (e) {
      print('Error getting service ID: $e');
    }
    return null;
  }
  
  String _getServiceTitle(dynamic service) {
    try {
      if (service == null) return 'Service';
      
      // Try direct property access
      if (service.title != null) return service.title;
      if (service.name != null) return service.name;
      
      // Try as Map
      if (service is Map) {
        return service['title'] ?? service['name'] ?? 'Service';
      }
    } catch (e) {
      print('Error getting service title: $e');
    }
    return 'Service';
  }
  
  String _getServiceImage(dynamic service) {
    try {
      if (service == null) return '';
      
      // Try various image properties
      if (service.imageAttachments != null && service.imageAttachments.isNotEmpty) {
        return service.imageAttachments.first ?? '';
      }
      if (service.image != null) return service.image;
      if (service.profileImage != null) return service.profileImage;
      
      // Try as Map
      if (service is Map) {
        return service['image'] ?? service['imageUrl'] ?? service['profileImage'] ?? '';
      }
    } catch (e) {
      print('Error getting service image: $e');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.grey),
            16.height,
            Text('No services to display', style: boldTextStyle(size: 18)),
            8.height,
            Text('Try adjusting your filters', style: secondaryTextStyle()),
          ],
        ),
      );
    }

    // Get initial position from first valid service
    LatLng? initialPosition;
    for (var service in widget.services) {
      final lat = _getLatitude(service);
      final lng = _getLongitude(service);
      if (lat != null && lng != null) {
        initialPosition = LatLng(lat, lng);
        break;
      }
    }

    if (initialPosition == null) {
      return Center(child: Text('No valid coordinates found'));
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialPosition,
            zoom: _currentZoom,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
          },
          onCameraMove: (position) {
            _currentZoom = position.zoom;
          },
          onCameraIdle: () {
            // Re-cluster when camera stops moving
            _setMarkers();
          },
        ),
        
        // Zoom level indicator (optional - for debugging)
        if (appStore.isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.all(8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    12.width,
                    Text(
                      'Updating markers...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

