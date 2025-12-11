import 'package:booking_system_flutter/main.dart';
import 'package:booking_system_flutter/model/dashboard_model.dart';
import 'package:booking_system_flutter/network/rest_apis.dart';
import 'package:booking_system_flutter/screens/dashboard/component/category_component.dart';
import 'package:booking_system_flutter/screens/dashboard/component/featured_service_list_component.dart';
import 'package:booking_system_flutter/screens/dashboard/component/service_list_component.dart';
import 'package:booking_system_flutter/screens/dashboard/component/slider_and_location_component.dart';
import 'package:booking_system_flutter/screens/dashboard/shimmer/dashboard_shimmer.dart';
import 'package:booking_system_flutter/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../component/empty_error_state_widget.dart';
import '../../../component/loader_widget.dart';
import '../../../utils/common.dart';
import '../component/booking_confirmed_component.dart';
import '../component/new_job_request_component.dart';
import '../component/promotional_banner_slider_component.dart';

class DashboardFragment extends StatefulWidget {
  @override
  _DashboardFragmentState createState() => _DashboardFragmentState();
}

class _DashboardFragmentState extends State<DashboardFragment> {
  Future<DashboardResponse>? future;

  @override
  void initState() {
    super.initState();
    afterBuildCreated(
      () {
        location(context, onRefresh: () {
          init();
          setState(() {});
        });
      },
    );

    setStatusBarColorChange();

    LiveStream().on(LIVESTREAM_UPDATE_DASHBOARD, (p0) {
      init();
      appStore.setLoading(true);

      setState(() {});
    });
  }

  void init() async {
    log("+-+-+-+-+-+-+-+- init()");
    future = userDashboard(
        isCurrentLocation: appStore.isCurrentLocation,
        lat: getDoubleAsync(LATITUDE),
        long: getDoubleAsync(LONGITUDE));
    setStatusBarColorChange();
    setState(() {});
  }

  Future<void> setStatusBarColorChange() async {
    setStatusBarColor(
      statusBarIconBrightness: appStore.isDarkMode
          ? Brightness.light
          : await isNetworkAvailable()
              ? Brightness.light
              : Brightness.dark,
      transparentColor,
      delayInMilliSeconds: 800,
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
    LiveStream().dispose(LIVESTREAM_UPDATE_DASHBOARD);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Observer(builder: (context) {
            return AbsorbPointer(
              absorbing: appStore.isLoading,
              child: SnapHelperWidget<DashboardResponse>(
                initialData: cachedDashboardResponse,
                future: future,
                errorBuilder: (error) {
                  return NoDataWidget(
                    title: error,
                    imageWidget: ErrorStateWidget(),
                    retryText: language.reload,
                    onRetry: () {
                      appStore.setLoading(true);
                      init();
                      setState(() {});
                    },
                  );
                },
                loadingWidget: DashboardShimmer(),
                onSuccess: (snap) {
                  return AnimatedScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    listAnimationType: ListAnimationType.FadeIn,
                    fadeInConfiguration:
                        FadeInConfiguration(duration: 2.seconds),
                    onSwipeRefresh: () async {
                      appStore.setLoading(true);

                      setValue(LAST_APP_CONFIGURATION_SYNCED_TIME, 0);
                      init();
                      setState(() {});

                      return await 2.seconds.delay;
                    },
                    children: [
                      SliderLocationComponent(
                        sliderList: snap.slider.validate(),
                        featuredList: snap.featuredServices.validate(),
                        callback: () async {
                          appStore.setLoading(true);

                          init();
                          setState(() {});
                        },
                      ),
                      30.height,
                      PendingBookingComponent(
                          upcomingConfirmedBooking: snap.upcomingData),
                      CategoryComponent(categoryList: snap.category.validate()),
                      // if (snap.promotionalBanner.validate().isNotEmpty &&
                      //     appConfigurationStore.isPromotionalBanner)
                      //   PromotionalBannerSliderComponent(
                      //     promotionalBannerList:
                      //         snap.promotionalBanner.validate(),
                      //   ).paddingTop(16),
                      16.height,
                      Builder(
                        builder: (context) {
                          final jobRequestEnabled = appConfigurationStore.jobRequestStatus;
                          final postJobListEnabled =  true;
                          // rolesAndPermissionStore.postJobList;
                          
                          log('🔍 [Dashboard] NewJobRequestComponent visibility check:');
                          log('🔍 [Dashboard] jobRequestStatus: $jobRequestEnabled');
                          log('🔍 [Dashboard] postJobList: $postJobListEnabled');
                          log('🔍 [Dashboard] Component will show: ${jobRequestEnabled && postJobListEnabled}');
                          
                          if (jobRequestEnabled && postJobListEnabled) {
                            return Column(
                              children: [
                                10.height,
                                NewJobRequestComponent(),
                                10.height,
                              ],
                            );
                          } else {
                            return SizedBox.shrink();
                          }
                        },
                      ),
                      FeaturedServiceListComponent(
                          serviceList: snap.featuredServices.validate()),
                      ServiceListComponent(
                          serviceList: snap.service.validate()),
                      16.height,
                    ],
                  );
                },
              ),
            );
          }),

          /// 🔒 Loader Overlay and Interaction Block
          Observer(
            builder: (context) {
              return appStore.isLoading ? LoaderWidget().center() : SizedBox();
            },
          ),
        ],
      ),
    );
  }
}
