import 'package:booking_system_flutter/component/image_border_component.dart';
import 'package:booking_system_flutter/model/notification_model.dart';
import 'package:booking_system_flutter/utils/images.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../utils/common.dart';

class NotificationWidget extends StatelessWidget {
  final NotificationData data;
  final VoidCallback? onTap;

  NotificationWidget({required this.data, this.onTap});

  Color _getBGColor(BuildContext context) {
    if (data.readAt != null) {
      return context.scaffoldBackgroundColor;
    } else {
      return context.cardColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    
    // Build card content
    // Widget buildCardContent() {
    //   return Container(
    //     width: context.width(),
    //     padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    //     decoration: boxDecorationDefault(
    //       color: _getBGColor(context),
    //       borderRadius: radius(0),
    //     ),
    //     child: Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         // Profile Image
    //         data.profileImage.validate().isNotEmpty
    //             ? ImageBorder(
    //                 src: data.profileImage.validate(),
    //                 height: 40,
    //               )
    //             : ImageBorder(
    //                 src: ic_notification_user,
    //                 height: 40,
    //               ),
    //         16.width,
    //         // Text Content
    //         Expanded(
    //           child: Column(
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               // Title and Time Row
    //               Row(
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Expanded(
    //                     child: Text(
    //                       '${data.data!.type.validate().split('_').join(' ').capitalizeFirstLetter()}',
    //                       style: boldTextStyle(size: 12),
    //                     ),
    //                   ),
    //                   8.width,
    //                   Text(
    //                     data.createdAt.validate(),
    //                     style: secondaryTextStyle(),
    //                   ),
    //                 ],
    //               ),
    //               4.height,
    //               // Description - prevent text selection and tap interception
    //               AbsorbPointer(
    //                 absorbing: onTap != null,
    //                 child: ReadMoreText(
    //                   parseHtmlString(data.data!.message.validate()),
    //                   trimLines: 2,
    //                   trimMode: TrimMode.Line,
    //                   trimCollapsedText: ' Read more',
    //                   trimExpandedText: ' Read less',
    //                   style: secondaryTextStyle(),
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //   );
   
    // }

    // If onTap is provided, make the entire card clickable
    // if (onTap != null) {
    //   return GestureDetector(
    //     onTap: onTap,
    //     onLongPress: () {}, // Prevent long press text selection
    //     onDoubleTap: () {}, // Prevent double tap text selection
    //     behavior: HitTestBehavior.opaque,
    //     child: Material(
    //       color: Colors.red,
    //       child: InkWell(
    //         onTap: onTap,
    //         splashColor: context.primaryColor.withOpacity(0.1),
    //         highlightColor: context.primaryColor.withOpacity(0.05),
    //         borderRadius: BorderRadius.zero,
    //         child: buildCardContent(),
    //       ),
    //     ),
    //   );
    // }

    // Return non-clickable version
    // return buildCardContent();
  // }
      return InkWell(
        onTap: onTap,
        child:  Container(
        width: context.width(),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: boxDecorationDefault(
          color: _getBGColor(context),
          borderRadius: radius(0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            data.profileImage.validate().isNotEmpty
                ? ImageBorder(
                    src: data.profileImage.validate(),
                    height: 40,
                  )
                : ImageBorder(
                    src: ic_notification_user,
                    height: 40,
                  ),
            16.width,
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and Time Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${data.data!.type.validate().split('_').join(' ').capitalizeFirstLetter()}',
                          style: boldTextStyle(size: 12),
                        ),
                      ),
                      8.width,
                      Text(
                        data.createdAt.validate(),
                        style: secondaryTextStyle(),
                      ),
                    ],
                  ),
                  4.height,
                  // Description - prevent text selection and tap interception
                  // AbsorbPointer(
                  //   absorbing: onTap != null,
                  //   child: ReadMoreText(
                  //     parseHtmlString(data.data!.message.validate()),
                  //     trimLines: 2,
                  //     trimMode: TrimMode.Line,
                  //     trimCollapsedText: ' Read more',
                  //     trimExpandedText: ' Read less',
                  //     style: secondaryTextStyle(),
                  //   ),
                  // ),
                   Text(
                        parseHtmlString(data.data!.message.validate()),
                        style: secondaryTextStyle(),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
