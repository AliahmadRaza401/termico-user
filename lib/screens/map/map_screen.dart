import 'package:booking_system_flutter/component/back_widget.dart';
import 'package:booking_system_flutter/component/custom_map_marker.dart';
import 'package:booking_system_flutter/component/loader_widget.dart';
import 'package:booking_system_flutter/main.dart';
import 'package:booking_system_flutter/services/location_service.dart';
import 'package:booking_system_flutter/utils/colors.dart';
import 'package:booking_system_flutter/utils/common.dart';
import 'package:booking_system_flutter/utils/map_cluster_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../utils/constant.dart';

class MapScreen extends StatefulWidget {
  final double? latLong;
  final double? latitude;
  final List<MapLocation>? nearbyLocations; // Optional list for clustering

  MapScreen({this.latLong, this.latitude, this.nearbyLocations});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  late GoogleMapController mapController;

  String? mapStyle;

  String _currentAddress = '';
  LatLng? _selectedLatLng;
  final destinationAddressController = TextEditingController();
  final destinationAddressFocusNode = FocusNode();

  String _destinationAddress = '';

  Set<Marker> markers = {};
  
  // Clustering variables
  double _currentZoom = 13.0;
  bool _isUpdatingMarkers = false;
  List<MapCluster> _clusters = [];

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    if (appStore.isDarkMode) {
      DefaultAssetBundle.of(context)
          .loadString('assets/json/map_style_dark.json')
          .then((value) {
        mapStyle = value;
        setState(() {});
      }).catchError(onError);
    }
    afterBuildCreated(() {
      _getCurrentLocation();
    });
  }

  // Method for retrieving the current location
  void _getCurrentLocation() async {
    appStore.setLoading(true);
    await getUserLocationPosition().then((position) async {
      setAddress();

      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0),
        ),
      );

      await _updateMarkers(position);

      setState(() {});
    }).catchError((e) {
      toast(e.toString());
    });

    appStore.setLoading(false);
  }

  // Update markers with clustering supportn kk
  Future<void> _updateMarkers([Position? currentPosition]) async {
    if (_isUpdatingMarkers) return;
    _isUpdatingMarkers = true;

    markers.clear();

    // Add current location marker if available
    if (currentPosition != null) {
      BitmapDescriptor currentLocationMarker = await CustomMapMarker.createCircularImageMarker(
        imageUrl: '',
        size: 180,
        borderColor: Colors.white,
        backgroundColor: primaryColor,
      );
      
      markers.add(Marker(
        markerId: MarkerId('current_location'),
        position: LatLng(currentPosition.latitude, currentPosition.longitude),
        infoWindow: InfoWindow(
            title: 'Your Location', snippet: _currentAddress),
        icon: currentLocationMarker,
      ));
    }

    // Add clustered nearby locations if provided
    if (widget.nearbyLocations != null && widget.nearbyLocations!.isNotEmpty) {
      await _addClusteredMarkers();
    }

    _isUpdatingMarkers = false;
    if (mounted) setState(() {});
  }

  // Add clustered markers to the map
  Future<void> _addClusteredMarkers() async {
    print('🗺️ Clustering ${widget.nearbyLocations!.length} locations at zoom $_currentZoom');
    
    // Create clusters based on current zoom
    _clusters = MapClusterHelper.clusterLocations(
      widget.nearbyLocations!,
      _currentZoom,
    );

    print('✅ Created ${_clusters.length} clusters');

    // Create markers for each cluster
    for (var cluster in _clusters) {
      if (cluster.isCluster) {
        // Multiple locations - create cluster marker
        print('🎯 Cluster: ${cluster.count} items, Total: \$${cluster.totalPrice.toStringAsFixed(0)}');
        
        final clusterColor = Color(MapClusterHelper.getClusterColor(cluster.count));
        final clusterSize = MapClusterHelper.getClusterSize(cluster.count);
        
        final icon = await CustomMapMarker.createEnhancedClusterMarker(
          count: cluster.count,
          avgPrice: cluster.totalPrice.toStringAsFixed(0),
          currency: '\$',
          color: clusterColor,
          size: clusterSize,
        );
        
        // Create unique cluster ID
        String clusterKey = cluster.locations.map((l) => 
          '${l.position.latitude.toStringAsFixed(4)}_${l.position.longitude.toStringAsFixed(4)}'
        ).join('_');
        
        markers.add(Marker(
          markerId: MarkerId('cluster_$clusterKey'),
          position: cluster.center,
          icon: icon,
          onTap: () {
            // Zoom in to expand cluster
            if (_currentZoom < 18) {
              mapController.animateCamera(
                CameraUpdate.newLatLngZoom(cluster.center, _currentZoom + 2),
              );
            } else {
              // Show cluster details at max zoom
              _showClusterDetails(cluster);
            }
          },
        ));
      } else {
        // Single location - create individual marker
        final location = cluster.locations.first;
        
        print('📍 Single location at ${location.position}');
        
        final markerIcon = await CustomMapMarker.createCircularImageMarker(
          imageUrl: '',
          size: 120,
          borderColor: Colors.white,
          backgroundColor: primaryColor,
        );
        
        markers.add(Marker(
          markerId: MarkerId('location_${location.position.latitude}_${location.position.longitude}'),
          position: location.position,
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: 'Location',
            snippet: '\$${location.price.toStringAsFixed(0)}',
          ),
          onTap: () {
            _handleLocationTap(location);
          },
        ));
      }
    }

    print('🏁 Final marker count: ${markers.length}');
  }

  // Handle cluster detail display
  void _showClusterDetails(MapCluster cluster) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cluster Details',
              style: boldTextStyle(size: 18),
            ),
            16.height,
            Text('Total Locations: ${cluster.count}', style: primaryTextStyle()),
            8.height,
            Text('Total Price: \$${cluster.totalPrice.toStringAsFixed(2)}', style: primaryTextStyle()),
            8.height,
            Text('Average Price: \$${cluster.avgPrice.toStringAsFixed(2)}', style: primaryTextStyle()),
            16.height,
            AppButton(
              text: 'Close',
              color: primaryColor,
              textColor: Colors.white,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // Handle individual location tap
  void _handleLocationTap(MapLocation location) {
    print('Tapped location at ${location.position}');
    // You can add custom handling here
    _handleTap(location.position);
  }

  // Method for retrieving the address
  Future<void> setAddress() async {
    try {
      Position position = await getUserLocationPosition().catchError((e) {
        throw e;
      });

      _currentAddress = await buildFullAddressFromLatLong(
              position.latitude, position.longitude)
          .catchError((e) {
        log(e);
        throw e;
      });
      destinationAddressController.text = _currentAddress;
      _destinationAddress = _currentAddress;

      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  _handleTap(LatLng point) async {
    appStore.setLoading(true);

    // Clear only the selection marker, keep cluster markers
    markers.removeWhere((marker) => 
      marker.markerId.value == 'selected_location' ||
      marker.markerId.value == 'current_location'
    );
    
    // Create custom circular marker for selected location
    BitmapDescriptor customMarker = await CustomMapMarker.createCircularImageMarker(
      imageUrl: '', // No image URL, will use fallback
      size: 180, // Double size (was 90)
      borderColor: Colors.white,
      backgroundColor: primaryColor,
    );
    
    markers.add(Marker(
      markerId: MarkerId('selected_location'),
      position: point,
      infoWindow: InfoWindow(title: 'Selected Location'),
      icon: customMarker,
    ));

    destinationAddressController.text =
        await buildFullAddressFromLatLong(point.latitude, point.longitude)
            .catchError((e) {
      throw e;
    });

    _destinationAddress = destinationAddressController.text;
    _selectedLatLng = point;

    appStore.setLoading(false);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: appBarWidget(
        language.chooseYourLocation,
        backWidget: BackWidget(),
        color: primaryColor,
        elevation: 0,
        textColor: white,
        textSize: APP_BAR_TEXT_SIZE,
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            markers: Set<Marker>.from(markers),
            initialCameraPosition: _initialLocation,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            zoomGesturesEnabled: true,
            style: mapStyle,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) async {
              mapController = controller;
            },
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },
            onCameraIdle: () async {
              // Re-cluster when camera stops moving (only if we have nearby locations)
              if (widget.nearbyLocations != null && widget.nearbyLocations!.isNotEmpty) {
                await _updateMarkers();
              }
            },
            onTap: _handleTap,
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ClipOval(
                  child: Material(
                    color: context.primaryColor.withValues(alpha: 0.2),
                    child: InkWell(
                      splashColor: context.primaryColor.withValues(alpha: 0.8),
                      child: SizedBox(
                          width: 50, height: 50, child: Icon(Icons.add)),
                      onTap: () {
                        mapController.animateCamera(CameraUpdate.zoomIn());
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ClipOval(
                  child: Material(
                    color: context.primaryColor.withValues(alpha: 0.2),
                    child: InkWell(
                      splashColor: context.primaryColor.withValues(alpha: 0.8),
                      child: SizedBox(
                          width: 50, height: 50, child: Icon(Icons.remove)),
                      onTap: () {
                        mapController.animateCamera(CameraUpdate.zoomOut());
                      },
                    ),
                  ),
                ),
              ],
            ).paddingLeft(10),
          ),
          Positioned(
            right: 0,
            left: 0,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipOval(
                  child: Material(
                    color: context.primaryColor
                        .withValues(alpha: 0.2), // button color
                    child: Icon(Icons.my_location, size: 25).paddingAll(10),
                  ),
                ).paddingRight(8).onTap(() async {
                  appStore.setLoading(true);

                  await getUserLocationPosition().then((value) {
                    mapController.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                            target: LatLng(value.latitude, value.longitude),
                            zoom: 18.0),
                      ),
                    );

                    _handleTap(LatLng(value.latitude, value.longitude));
                  }).catchError(onError);

                  appStore.setLoading(false);
                }),
                8.height,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppTextField(
                      textFieldType: TextFieldType.MULTILINE,
                      controller: destinationAddressController,
                      focus: destinationAddressFocusNode,
                      textStyle: primaryTextStyle(
                          color: appStore.isDarkMode
                              ? Colors.white
                              : Colors.black),
                      decoration: inputDecoration(context,
                              labelText: language.hintAddress)
                          .copyWith(
                              fillColor: appStore.isDarkMode
                                  ? Colors.black54
                                  : Colors.white70),
                    ),
                  ],
                ),
                8.height,
                AppButton(
                  width: context.width(),
                  height: 16,
                  color: primaryColor.withValues(alpha: 0.8),
                  text: language.setAddress.toUpperCase(),
                  textStyle: boldTextStyle(color: white, size: 12),
                  onTap: () {
                    if (destinationAddressController.text.isNotEmpty &&
                        _selectedLatLng != null) {
                      // Save separately in appStore
                      appStore.latitude = double.parse(
                          _selectedLatLng!.latitude.toStringAsFixed(6));
                      appStore.longitude = double.parse(
                          _selectedLatLng!.longitude.toStringAsFixed(6));

                      // Old flow stays same → returns only address
                      finish(context, destinationAddressController.text);
                    } else {
                      toast(language.lblPickAddress);
                    }
                  },
                ),
                8.height,
              ],
            ).paddingAll(16),
          ),
          Observer(
              builder: (context) => LoaderWidget().visible(appStore.isLoading))
        ],
      ),
    );
  }
}
