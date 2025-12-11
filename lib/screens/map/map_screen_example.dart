import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:booking_system_flutter/screens/map/map_screen.dart';
import 'package:booking_system_flutter/utils/map_cluster_helper.dart';

/// Example usage of MapScreen with clustering
class MapScreenExample {
  
  /// Example 1: Basic location picker (no clustering)
  static void openLocationPicker(BuildContext context) {
    MapScreen().launch(context);
  }
  
  /// Example 2: Map with nearby locations (with clustering)
  static void openMapWithLocations(BuildContext context) {
    // Sample locations - replace with your actual data
    List<MapLocation> nearbyLocations = [
      MapLocation(
        position: LatLng(37.7749, -122.4194), // San Francisco
        price: 150.0,
        data: {'name': 'Service 1', 'rating': 4.5},
      ),
      MapLocation(
        position: LatLng(37.7849, -122.4094),
        price: 200.0,
        data: {'name': 'Service 2', 'rating': 4.8},
      ),
      MapLocation(
        position: LatLng(37.7649, -122.4294),
        price: 180.0,
        data: {'name': 'Service 3', 'rating': 4.2},
      ),
      MapLocation(
        position: LatLng(37.7849, -122.4194),
        price: 220.0,
        data: {'name': 'Service 4', 'rating': 4.7},
      ),
      MapLocation(
        position: LatLng(37.7749, -122.4094),
        price: 190.0,
        data: {'name': 'Service 5', 'rating': 4.6},
      ),
    ];
    
    MapScreen(
      nearbyLocations: nearbyLocations,
    ).launch(context);
  }
  
  /// Example 3: Convert service data to MapLocation
  static List<MapLocation> convertServicesToLocations(List<dynamic> services) {
    return services
        .where((service) {
          // Filter services with valid coordinates
          final lat = _getLatitude(service);
          final lng = _getLongitude(service);
          return lat != null && lng != null;
        })
        .map((service) {
          final lat = _getLatitude(service)!;
          final lng = _getLongitude(service)!;
          final price = _getPrice(service);
          
          return MapLocation(
            position: LatLng(lat, lng),
            price: price,
            data: service, // Store original service object
          );
        })
        .toList();
  }
  
  /// Example 4: Open map with filtered services
  static void openMapWithServices(
    BuildContext context, 
    List<dynamic> services,
  ) {
    final locations = convertServicesToLocations(services);
    
    print('📍 Displaying ${locations.length} services on map');
    
    MapScreen(
      nearbyLocations: locations,
    ).launch(context);
  }
  
  /// Example 5: Generate demo locations around a center point
  static List<MapLocation> generateDemoLocations({
    required LatLng center,
    int count = 20,
    double radiusKm = 5.0,
  }) {
    final List<MapLocation> locations = [];
    
    for (int i = 0; i < count; i++) {
      // Generate random offset within radius
      final angle = (i * 137.5) % 360; // Golden angle for distribution
      final distance = (radiusKm / 111.0) * ((i % 5) + 1) / 5; // km to degrees
      
      final angleRad = angle * math.pi / 180;
      final centerLatRad = center.latitude * math.pi / 180;
      
      final lat = center.latitude + distance * math.cos(angleRad);
      final lng = center.longitude + distance * math.sin(angleRad) / math.cos(centerLatRad);
      
      locations.add(MapLocation(
        position: LatLng(lat, lng),
        price: 50.0 + (i * 25.0),
        data: {
          'id': i,
          'name': 'Demo Service $i',
          'category': ['Plumbing', 'Electrical', 'Cleaning', 'Painting'][i % 4],
        },
      ));
    }
    
    return locations;
  }
  
  /// Example 6: Open map with demo data
  static void openMapWithDemoData(BuildContext context) {
    // Generate 50 demo locations around San Francisco
    final demoLocations = generateDemoLocations(
      center: LatLng(37.7749, -122.4194),
      count: 50,
      radiusKm: 10.0,
    );
    
    MapScreen(
      nearbyLocations: demoLocations,
    ).launch(context);
  }
  
  // Helper methods to extract data from different service model structures
  
  static double? _getLatitude(dynamic service) {
    if (service is Map) {
      return service['latitude']?.toDouble() ?? 
             service['lat']?.toDouble();
    }
    // Add your service model property access here
    // e.g., if service has a latitude property:
    // return service.latitude?.toDouble();
    return null;
  }
  
  static double? _getLongitude(dynamic service) {
    if (service is Map) {
      return service['longitude']?.toDouble() ?? 
             service['lng']?.toDouble() ??
             service['long']?.toDouble();
    }
    // Add your service model property access here
    return null;
  }
  
  static double _getPrice(dynamic service) {
    if (service is Map) {
      return service['price']?.toDouble() ?? 0.0;
    }
    // Add your service model property access here
    return 0.0;
  }
}

/// Example widget showing how to use the map in your UI
class MapScreenExampleWidget extends StatelessWidget {
  const MapScreenExampleWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Map Clustering Examples')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () => MapScreenExample.openLocationPicker(context),
            child: Text('Example 1: Basic Location Picker'),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => MapScreenExample.openMapWithLocations(context),
            child: Text('Example 2: Map with Sample Locations'),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => MapScreenExample.openMapWithDemoData(context),
            child: Text('Example 3: Map with 50 Demo Locations'),
          ),
          SizedBox(height: 32),
          Text(
            'Clustering Features:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          _buildFeatureItem('🎯', 'Automatic clustering at low zoom levels'),
          _buildFeatureItem('📊', 'Shows count + total price per cluster'),
          _buildFeatureItem('🎨', 'Color-coded by marker count'),
          _buildFeatureItem('🔍', 'Tap to zoom in and expand clusters'),
          _buildFeatureItem('📍', 'Individual markers at high zoom'),
          _buildFeatureItem('💰', 'Price aggregation and display'),
        ],
      ),
    );
  }
  
  Widget _buildFeatureItem(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 20)),
          SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// Extension to make navigation easier
extension WidgetNavigation on Widget {
  void launch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => this),
    );
  }
}

