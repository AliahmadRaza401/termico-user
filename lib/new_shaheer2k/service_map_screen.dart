import 'package:booking_system_flutter/component/back_widget.dart';
import 'package:booking_system_flutter/component/custom_map_marker.dart';
import 'package:booking_system_flutter/component/loader_widget.dart';
import 'package:booking_system_flutter/main.dart';
import 'package:booking_system_flutter/screens/filter/filter_screen.dart';
import 'package:booking_system_flutter/screens/service/component/service_component.dart';
import 'package:booking_system_flutter/services/location_service.dart';
import 'package:booking_system_flutter/utils/colors.dart';
import 'package:booking_system_flutter/utils/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../component/cached_image_widget.dart';
import '../../component/empty_error_state_widget.dart';
import '../../model/category_model.dart';
import '../../model/service_data_model.dart';
import '../../network/rest_apis.dart';
import '../../store/filter_store.dart';
import '../../utils/constant.dart';
import '../../utils/images.dart';

class ServicesMapScreen extends StatefulWidget {
  final double? latLong;
  final double? latitude;
  final List<ServiceData> serviceList;
  ServicesMapScreen({this.latLong, this.latitude, required this.serviceList});

  @override
  ServicesMapScreenState createState() => ServicesMapScreenState();
}

class ServicesMapScreenState extends State<ServicesMapScreen> {
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));

  PageController _pageController = PageController(viewportFraction: 0.85);
  late GoogleMapController mapController;
  Future<List<CategoryData>>? futureCategory;
  List<CategoryData> categoryList = [];

  Future<List<ServiceData>>? futureService;
  // List<ServiceData> serviceList = [];

  FocusNode myFocusNode = FocusNode();
  TextEditingController searchCont = TextEditingController();

  int? subCategory;

  int page = 1;
  bool isLastPage = false;
  String? mapStyle;
  int _currentIndex = 0;
  String _currentAddress = '';
  int? _selectedServiceIndex;

  int? categoryId;
  int? providerId;
  final destinationAddressController = TextEditingController();
  final destinationAddressFocusNode = FocusNode();

  String _destinationAddress = '';

  Set<Marker> markers = {};
  Set<Circle> circles = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    fetchAllServiceData();

    if (categoryId != null) {
      fetchCategoryList();
    }

    filterStore = FilterStore();
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

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    filterStore.clearFilters();
    myFocusNode.dispose();
    filterStore.setSelectedSubCategory(catId: 0);
    super.dispose();
  }

  void fetchCategoryList() async {
    futureCategory = getSubCategoryListAPI(
      catId: categoryId!,
    );
  }

  void fetchAllServiceData() async {
    futureService = searchServiceAPI(
      page: page,
      list: widget.serviceList,
      categoryId: categoryId != null
          ? categoryId.validate().toString()
          : filterStore.categoryId.join(','),
      subCategory: subCategory != null ? subCategory.validate().toString() : '',
      providerId: providerId != null
          ? providerId.toString()
          : filterStore.providerId.join(","),
      isPriceMin: filterStore.isPriceMin,
      isPriceMax: filterStore.isPriceMax,
      ratingId: filterStore.ratingId.join(','),
      search: searchCont.text,
      latitude:
          appStore.isCurrentLocation ? getDoubleAsync(LATITUDE).toString() : "",
      longitude: appStore.isCurrentLocation
          ? getDoubleAsync(LONGITUDE).toString()
          : "",
      lastPageCallBack: (p0) {
        isLastPage = p0;
      },
      isFeatured: "",
    );

    futureService!.then((newServices) async {
      print("Fetched ${newServices.length} services");

      await updateMarkers();
      setState(() {});

      appStore.setLoading(false);
    }).catchError((e) {
      appStore.setLoading(false);
      print("Error fetching services: $e");
    });
  }

  Widget subCategoryWidget() {
    return SnapHelperWidget<List<CategoryData>>(
      future: futureCategory,
      initialData: cachedSubcategoryList
          .firstWhere((element) => element?.$1 == categoryId.validate(),
              orElse: () => null)
          ?.$2,
      loadingWidget: Offstage(),
      onSuccess: (list) {
        if (list.length == 1) return Offstage();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            16.height,
            Text(language.lblSubcategories,
                    style: boldTextStyle(size: LABEL_TEXT_SIZE))
                .paddingLeft(16),
            HorizontalList(
              itemCount: list.validate().length,
              padding: EdgeInsets.only(left: 16, right: 16),
              runSpacing: 8,
              spacing: 12,
              itemBuilder: (_, index) {
                CategoryData data = list[index];

                return Observer(
                  builder: (_) {
                    bool isSelected =
                        filterStore.selectedSubCategoryId == index;

                    return GestureDetector(
                      onTap: () {
                        filterStore.setSelectedSubCategory(catId: index);

                        subCategory = data.id;
                        page = 1;

                        appStore.setLoading(true);
                        fetchAllServiceData();

                        setState(() {});
                      },
                      child: SizedBox(
                        width: context.width() / 4 - 20,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              children: [
                                16.height,
                                if (index == 0)
                                  Container(
                                    height: CATEGORY_ICON_SIZE,
                                    width: CATEGORY_ICON_SIZE,
                                    decoration: BoxDecoration(
                                        color: context.cardColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: grey)),
                                    alignment: Alignment.center,
                                    child: Text(data.name.validate(),
                                        style: boldTextStyle(size: 12)),
                                  ),
                                if (index != 0)
                                  data.categoryImage.validate().endsWith('.svg')
                                      ? Container(
                                          width: CATEGORY_ICON_SIZE,
                                          height: CATEGORY_ICON_SIZE,
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                              color: context.cardColor,
                                              shape: BoxShape.circle),
                                          child: SvgPicture.network(
                                            data.categoryImage.validate(),
                                            height: CATEGORY_ICON_SIZE,
                                            width: CATEGORY_ICON_SIZE,
                                            color: appStore.isDarkMode
                                                ? Colors.white
                                                : data.color
                                                    .validate(value: '000')
                                                    .toColor(),
                                            placeholderBuilder: (context) =>
                                                PlaceHolderWidget(
                                                    height: CATEGORY_ICON_SIZE,
                                                    width: CATEGORY_ICON_SIZE,
                                                    color: transparentColor),
                                          ),
                                        )
                                      : Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                              color: context.cardColor,
                                              shape: BoxShape.circle),
                                          child: CachedImageWidget(
                                            url: data.categoryImage.validate(),
                                            fit: BoxFit.fitWidth,
                                            width: SUBCATEGORY_ICON_SIZE,
                                            height: SUBCATEGORY_ICON_SIZE,
                                            circle: true,
                                          ),
                                        ),
                                4.height,
                                if (index == 0)
                                  Text(language.lblViewAll,
                                      style: boldTextStyle(size: 12),
                                      textAlign: TextAlign.center,
                                      maxLines: 1),
                                if (index != 0)
                                  Marquee(
                                      child: Text('${data.name.validate()}',
                                          style: boldTextStyle(size: 12),
                                          textAlign: TextAlign.center,
                                          maxLines: 1)),
                              ],
                            ),
                            Positioned(
                              top: 14,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: boxDecorationDefault(
                                    color: context.primaryColor),
                                child: Icon(Icons.done,
                                    size: 16, color: Colors.white),
                              ).visible(isSelected),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            16.height,
          ],
        );
      },
    );
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

      circles.clear();

      await updateMarkers();
      // Add a circle around the user's location
      circles.add(Circle(
        circleId: CircleId("current_location_radius"),
        center: LatLng(position.latitude, position.longitude),
        radius: 500, // Radius in meters (change as needed)
        strokeWidth: 1,
        strokeColor: Colors.blue,
        fillColor: Colors.blue.withAlpha(50),
      ));

      // Create custom circular marker for current location
      BitmapDescriptor currentLocationMarker = await CustomMapMarker.createCircularImageMarker(
        imageUrl: '', // No image, will show fallback icon
        size: 120, // Double size (was 60)
        borderColor: Colors.white,
        backgroundColor: Colors.red, // Red for current location
      );

      markers.add(Marker(
        markerId: MarkerId(_currentAddress),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: InfoWindow(
            title: 'Start $_currentAddress', snippet: _destinationAddress),
        icon: currentLocationMarker,
      ));

      setState(() {});
    }).catchError((e) {
      toast(e.toString());
    });

    appStore.setLoading(false);
  }

// To link markers to service indices
  Map<MarkerId, int> markerToServiceIndex = {}; // NEW
  
  // Cache for custom markers to avoid recreating them
  Map<String, BitmapDescriptor> markerCache = {};

  Future<void> updateMarkers() async {
    markers.clear();
    markerToServiceIndex.clear(); // Clear previous links

    for (var i = 0; i < widget.serviceList.length; i++) {
      var service = widget.serviceList[i];
      var serviceAddressMapping = service.serviceAddressMapping;

      if (serviceAddressMapping != null && serviceAddressMapping.isNotEmpty) {
        for (var addressMapping in serviceAddressMapping) {
          var providerAddressMapping = addressMapping.providerAddressMapping;

          if (providerAddressMapping != null) {
            var long = providerAddressMapping.longitude.toDouble();
            var lat = providerAddressMapping.latitude.toDouble();
            var markerId = MarkerId('${lat}_${long}');

            print('service_lat_long: ${lat}_${long}');

            // Get service image URL
            String imageUrl = '';
            if (service.attachments != null && service.attachments!.isNotEmpty) {
              imageUrl = service.attachments!.first;
            } else if (service.serviceAttachments != null && service.serviceAttachments!.isNotEmpty) {
              imageUrl = service.serviceAttachments!.first;
            } else if (service.attachmentsArray != null && service.attachmentsArray!.isNotEmpty) {
              imageUrl = service.attachmentsArray!.first.url ?? '';
            }

            // Create cache key
            String cacheKey = 'service_${service.id}_$imageUrl';

            // Get or create custom marker
            BitmapDescriptor customIcon;
            if (markerCache.containsKey(cacheKey)) {
              customIcon = markerCache[cacheKey]!;
            } else {
              // Create custom circular marker with service image and price
              customIcon = await CustomMapMarker.createServiceImageMarker(
                imageUrl: imageUrl,
                price: service.price?.toStringAsFixed(0) ?? '0',
                currency: appConfigurationStore.currencySymbol,
                size: 160, // Double size (was 80)
                priceBgColor: primaryColor,
              );
              markerCache[cacheKey] = customIcon;
            }

            markers.add(Marker(
              markerId: markerId,
              position: LatLng(lat, long),
              infoWindow: InfoWindow(title: service.name ?? 'Service Location'),
              icon: customIcon,
              onTap: () {
                setState(() {
                  _selectedServiceIndex = markerToServiceIndex[markerId];
                });
              },
            ));

            markerToServiceIndex[markerId] = i;
          }
        }
      }
    }
    
    setState(() {}); // Refresh UI with new markers
  }

  // Method for retrieving the address
  Future<void> setAddress() async {
    try {
      Position position = await getUserLocationPosition().catchError((e) {
        //
      });

      _currentAddress = await buildFullAddressFromLatLong(
              position.latitude, position.longitude)
          .catchError((e) {
        log(e);
      });
      destinationAddressController.text = _currentAddress;
      _destinationAddress = _currentAddress;

      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  void _moveMapToSelectedService() {
    if (widget.serviceList.isEmpty) return;

    print('_currentIndex: $_currentIndex');
    final service = widget.serviceList[_currentIndex];
    final addressList = service.serviceAddressMapping;

    if (addressList == null || addressList.isEmpty) return;

    // Ensure _currentIndex is within bounds, fallback to last item if out of range
    final validIndex = (_currentIndex < addressList.length)
        ? _currentIndex
        : addressList.length - 1;
    final address = addressList[validIndex].providerAddressMapping;

    if (address?.latitude != null && address?.longitude != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(LatLng(
            address!.latitude!.toDouble(), address.longitude!.toDouble())),
      );
    }
  }

  // _handleTap(LatLng point) async {
  //   appStore.setLoading(true);
  //
  //   markers.clear();
  //   markers.add(Marker(
  //     markerId: MarkerId(point.toString()),
  //     position: point,
  //     infoWindow: InfoWindow(),
  //     icon: BitmapDescriptor.defaultMarker,
  //   ));
  //
  //   destinationAddressController.text =
  //       await buildFullAddressFromLatLong(point.latitude, point.longitude)
  //           .catchError((e) {
  //     log(e);
  //   });
  //
  //   _destinationAddress = destinationAddressController.text;
  //
  //   appStore.setLoading(false);
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    List<Marker> markerList = markers.toList();

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: <Widget>[
          GoogleMap(
            onTap: (_) {
              setState(() {
                _selectedServiceIndex = null; // Hide card on map tap
              });
            },
            circles: circles,
            markers: Set<Marker>.from(markers),
            initialCameraPosition: CameraPosition(
              target: (widget.serviceList.isNotEmpty &&
                      widget.serviceList[_currentIndex].serviceAddressMapping !=
                          null &&
                      widget.serviceList[_currentIndex].serviceAddressMapping!
                          .isNotEmpty &&
                      widget.serviceList[_currentIndex].serviceAddressMapping!
                              .first.providerAddressMapping?.latitude !=
                          null &&
                      widget.serviceList[_currentIndex].serviceAddressMapping!
                              .first.providerAddressMapping?.longitude !=
                          null)
                  ? LatLng(
                      widget.serviceList[_currentIndex].serviceAddressMapping!
                          .first.providerAddressMapping!.latitude!
                          .toDouble(),
                      widget.serviceList[_currentIndex].serviceAddressMapping!
                          .first.providerAddressMapping!.longitude!
                          .toDouble(),
                    )
                  : LatLng(0, 0), // Default location if no valid service exists
              zoom: 12,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            zoomGesturesEnabled: true,
            style: mapStyle,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) async {
              mapController = controller;
            },
            // onTap: _handleTap,
          ),
          if (_selectedServiceIndex != null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: AnimatedScale(
                scale: 1.0,
                duration: Duration(milliseconds: 300),
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  child: ServiceComponent(
                    serviceData: widget.serviceList[_selectedServiceIndex!],
                    isFromViewAllService: true,
                  ),
                ),
              ),
            ),
          // Positioned(
          //   bottom: 20,
          //   left: 0,
          //   right: 0,
          //   height: 345,
          //   child: PageView.builder(
          //     controller: _pageController,
          //     itemCount: widget.serviceList.length,
          //     onPageChanged: (index) {
          //       setState(() {
          //         _currentIndex = index;
          //         _moveMapToSelectedService();
          //       });
          //     },
          //     itemBuilder: (_, index) {
          //       return AnimatedScale(
          //         scale: _currentIndex == index ? 1.0 : 0.9,
          //         duration: Duration(milliseconds: 300),
          //         child: Card(
          //           margin: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          //           child: ServiceComponent(
          //             serviceData: widget.serviceList[index],
          //             isFromViewAllService: true,
          //           ),
          //         ),
          //       );
          //     },
          //   ),
          // ),
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
                  }).catchError(onError);

                  appStore.setLoading(false);
                }),
              ],
            ).paddingAll(16),
          ),
          Positioned(
            right: 0,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration:
                        boxDecorationDefault(color: context.primaryColor),
                    child: CachedImageWidget(
                      url: ic_filter,
                      height: 26,
                      width: 26,
                      color: Colors.white,
                    ),
                  ).onTap(() {
                    hideKeyboard(context);

                    FilterScreen(isFromProvider: true, isFromCategory: false)
                        .launch(context)
                        .then((value) {
                      if (value != null) {
                        page = 1;
                        appStore.setLoading(true);

                        fetchAllServiceData();
                        setState(() {});
                      }
                    });
                  }, borderRadius: radius())
                ],
              ).paddingAll(16),
            ),
          ),
          Observer(
              builder: (context) => LoaderWidget().visible(appStore.isLoading))
        ],
      ),
    );
  }
}
