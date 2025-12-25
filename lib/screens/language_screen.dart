import 'package:booking_system_flutter/component/base_scaffold_widget.dart';
import 'package:booking_system_flutter/screens/dashboard/dashboard_screen.dart';
import 'package:booking_system_flutter/utils/colors.dart';
import 'package:booking_system_flutter/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import '../main.dart';

class LanguagesScreen extends StatefulWidget {
  final bool isFromWalkthrough;

  const LanguagesScreen({this.isFromWalkthrough = false});

  @override
  LanguagesScreenState createState() => LanguagesScreenState();
}

class LanguagesScreenState extends State<LanguagesScreen> {
  String? selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    selectedLanguageCode = appStore.selectedLanguageCode;
  }

  Future<void> init() async {
    //
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void onSave() async {
    if (selectedLanguageCode != null) {
      await appStore.setLanguage(selectedLanguageCode!);
      setState(() {});
    }

    if (widget.isFromWalkthrough) {
      await setValue(IS_FIRST_TIME, false);
      // Use navigatorKey to ensure navigation works even if context becomes invalid
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(),
          settings: RouteSettings(name: '/dashboard'),
        ),
        (route) => false,
      );
    } else {
      finish(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: language.language,
      child: Stack(
        children: [
          LanguageListWidget(
        widgetType: WidgetType.LIST,
            onLanguageChange: (v) async {
              selectedLanguageCode = v.languageCode;
              // Update UI immediately for visual feedback
              await appStore.setLanguage(v.languageCode!);
          setState(() {});
            },
          ).paddingBottom(80),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: AppButton(
              text: language.btnSave,
              color: primaryColor,
              textStyle: boldTextStyle(color: white),
              width: context.width(),
              onTap: onSave,
            ),
          ),
        ],
      ),
    );
  }
}
