import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

/// Represents a cluster of map markers
class MapCluster {
  final LatLng center;
  final List<MapLocation> locations;
  final int count;
  final double totalPrice;
  final bool isCluster;

  MapCluster({
    required this.center,
    required this.locations,
    required this.count,
    required this.totalPrice,
    required this.isCluster,
  });

  /// Average price of all items in the cluster
  double get avgPrice => count > 0 ? totalPrice / count : 0;
}

/// Generic location data that can be clustered
class MapLocation {
  final LatLng position;
  final double price;
  final dynamic data; // Can store any data type (ServiceData, PostJobData, etc.)

  MapLocation({
    required this.position,
    required this.price,
    this.data,
  });
}

/// Helper class for clustering map markers
class MapClusterHelper {
  /// Clusters locations based on zoom level
  static List<MapCluster> clusterLocations(
    List<MapLocation> locations,
    double zoom,
  ) {
    if (locations.isEmpty) return [];

    // Don't cluster at high zoom levels (close up) - Changed to 16 for more clustering
    if (zoom >= 16) {
      return locations.map((loc) => MapCluster(
        center: loc.position,
        locations: [loc],
        count: 1,
        totalPrice: loc.price,
        isCluster: false,
      )).toList();
    }

    // Group locations into grid cells
    final gridSize = _getGridSize(zoom);
    final Map<String, List<MapLocation>> grid = {};

    for (var location in locations) {
      final gridKey = _getGridKey(location.position, gridSize);
      grid.putIfAbsent(gridKey, () => []).add(location);
    }

    // Create clusters from grid cells
    final List<MapCluster> clusters = [];
    
    grid.forEach((key, cellLocations) {
      if (cellLocations.isEmpty) return;

      // Calculate center point and total price
      double totalLat = 0;
      double totalLng = 0;
      double totalPrice = 0;

      for (var loc in cellLocations) {
        totalLat += loc.position.latitude;
        totalLng += loc.position.longitude;
        totalPrice += loc.price;
      }

      final center = LatLng(
        totalLat / cellLocations.length,
        totalLng / cellLocations.length,
      );

      clusters.add(MapCluster(
        center: center,
        locations: cellLocations,
        count: cellLocations.length,
        totalPrice: totalPrice,
        isCluster: cellLocations.length > 1,
      ));
    });

    return clusters;
  }

  /// Clusters PostJobData based on zoom level (wrapper for clusterLocations)
  static List<MapCluster> clusterJobs(
    List<dynamic> jobs,
    double zoom,
  ) {
    // Convert jobs to MapLocation
    List<MapLocation> locations = jobs
        .where((job) => 
            job.latitude != null && 
            job.longitude != null &&
            job.price != null)
        .map((job) => MapLocation(
          position: LatLng(
            (job.latitude is double) ? job.latitude : job.latitude.toDouble(),
            (job.longitude is double) ? job.longitude : job.longitude.toDouble(),
          ),
          price: (job.price is double) ? job.price : job.price.toDouble(),
          data: job,
        ))
        .toList();

    return clusterLocations(locations, zoom);
  }

  /// Determines grid size based on zoom level
  static double _getGridSize(double zoom) {
    if (zoom < 8) return 3.0;   // Very large clusters (more aggressive)
    if (zoom < 10) return 1.5;  // Large clusters
    if (zoom < 12) return 0.8;  // Medium clusters
    if (zoom < 14) return 0.4;  // Small clusters
    if (zoom < 16) return 0.15; // Very small clusters
    return 0.05;                 // Minimal clustering
  }

  /// Generates a grid key for a location
  static String _getGridKey(LatLng position, double gridSize) {
    final latKey = (position.latitude / gridSize).floor();
    final lngKey = (position.longitude / gridSize).floor();
    return '$latKey,$lngKey';
  }

  /// Calculates distance between two points in kilometers
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km

    final lat1 = point1.latitude * math.pi / 180;
    final lat2 = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Gets cluster color based on count
  static int getClusterColor(int count) {
    if (count < 5) return 0xFF4CAF50;   // Green
    if (count < 10) return 0xFF2196F3;  // Blue
    if (count < 20) return 0xFFFF9800;  // Orange
    return 0xFFF44336;                   // Red
  }

  /// Gets cluster size based on count - Increased sizes
  static double getClusterSize(int count) {
    if (count < 5) return 90;
    if (count < 10) return 110;
    if (count < 20) return 130;
    if (count < 50) return 150;
    return 170;
  }
}

