import 'dart:convert';
import 'dart:io';

import 'package:booking_system_flutter/component/base_scaffold_widget.dart';
import 'package:booking_system_flutter/main.dart';
import 'package:booking_system_flutter/model/category_model.dart';
import 'package:booking_system_flutter/model/service_data_model.dart';
import 'package:booking_system_flutter/network/network_utils.dart';
import 'package:booking_system_flutter/network/rest_apis.dart';
import 'package:booking_system_flutter/screens/map/map_screen.dart';
import 'package:booking_system_flutter/services/location_service.dart';
import 'package:booking_system_flutter/utils/colors.dart';
import 'package:booking_system_flutter/utils/common.dart';
import 'package:booking_system_flutter/utils/constant.dart';
import 'package:booking_system_flutter/utils/images.dart';
import 'package:booking_system_flutter/utils/model_keys.dart';
import 'package:booking_system_flutter/utils/permissions.dart';
import 'package:booking_system_flutter/utils/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../component/chat_gpt_loder.dart';

class CreatePostRequestScreen extends StatefulWidget {
  @override
  _CreatePostRequestScreenState createState() =>
      _CreatePostRequestScreenState();
}

class _CreatePostRequestScreenState extends State<CreatePostRequestScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController postTitleCont = TextEditingController();
  TextEditingController descriptionCont = TextEditingController();
  TextEditingController priceCont = TextEditingController();
  TextEditingController addressCont = TextEditingController();

  FocusNode descriptionFocus = FocusNode();
  FocusNode priceFocus = FocusNode();

  List<ServiceData> myServiceList = [];
  List<ServiceData> selectedServiceList = [];

  // Service creation variables
  ImagePicker picker = ImagePicker();
  List<XFile> imageFiles = [];
  List<CategoryData> categoryList = [];
  CategoryData? selectedCategory;
  
  // Local loading state for save button
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    log('init: Starting initialization');
    appStore.setLoading(true);

    log('init: Fetching user service list');
    await getMyServiceList().then((value) {
      if (value.userServices != null) {
        myServiceList = value.userServices.validate();
        log('init: Loaded ${myServiceList.length} services');
      } else {
        log('init: No services found');
      }
    }).catchError((e) {
      log('init: Error fetching services - $e');
      toast(e.toString());
    });

    log('init: Fetching category list');
    await getCategoryList(CATEGORY_LIST_ALL).then((value) {
      if (value.categoryList!.isNotEmpty) {
        categoryList.addAll(value.categoryList.validate());
        log('init: Loaded ${categoryList.length} categories');
      } else {
        log('init: No categories found');
      }
    }).catchError((e) {
      log('init: Error fetching categories - $e');
      toast(e.toString(), print: true);
    });

    appStore.setLoading(false);
    log('init: Initialization complete');
    setState(() {});
  }

  void _handleSetLocationClick() {
    Permissions.cameraFilesAndLocationPermissionsGranted().then((value) async {
      await setValue(PERMISSION_STATUS, value);

      if (value) {
        String? res = await MapScreen(
          latitude: getDoubleAsync(LATITUDE),
          latLong: getDoubleAsync(LONGITUDE),
        ).launch(context);

        if (res != null) {
          addressCont.text = res;
          setState(() {});
        }
      }
    });
  }

  void _handleCurrentLocationClick() {
    Permissions.cameraFilesAndLocationPermissionsGranted().then((value) async {
      await setValue(PERMISSION_STATUS, value);

      if (value) {
        appStore.setLoading(true);

        await getUserLocation().then((value) {
          addressCont.text = value;
          setState(() {});
        }).catchError((e) {
          log(e);
          toast(e.toString());
        });

        appStore.setLoading(false);
      }
    }).catchError((e) {
      //
    });
  }

  Future<void> createPostJobClick() async {
    log('createPostJobClick: Starting post job creation');
    
    List<int> serviceList = [];

    if (selectedServiceList.isNotEmpty) {
      selectedServiceList.forEach((element) {
        serviceList.add(element.id.validate());
      });
      log('createPostJobClick: Selected services: $serviceList');
    } else {
      log('createPostJobClick: Warning - No services selected');
    }

    Map request = {
      PostJob.postTitle: postTitleCont.text.validate(),
      PostJob.description: descriptionCont.text.validate(),
      PostJob.serviceId: serviceList,
      PostJob.price: priceCont.text.validate(),
      PostJob.status: JOB_REQUEST_STATUS_REQUESTED,
      PostJob.latitude: appStore.latitude,
      PostJob.longitude: appStore.longitude,
      CommonKeys.address: addressCont.text.validate(),
    };
    
    log('createPostJobClick: Post job request data: $request');
    log('createPostJobClick: Calling savePostJob API');

    await savePostJob(request).then((value) {
      log('createPostJobClick: API Success - ${value.message}');
      setState(() => isSaving = false);
      toast(value.message.validate());

      log('createPostJobClick: Navigating back with success result');
      finish(context, true);
    }).catchError((e) {
      log('createPostJobClick: API Error - $e');
      setState(() => isSaving = false);
      toast(e.toString(), print: true);
    });
  }

  void deleteService(ServiceData data) {
    appStore.setLoading(true);

    deleteServiceRequest(data.id.validate()).then((value) {
      appStore.setLoading(false);
      toast(value.message.validate());
      init();
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString(), print: true);
    });
  }

  Future<void> getMultipleFile() async {
    await picker.pickMultiImage().then((value) {
      imageFiles.addAll(value);
      setState(() {});
    });
  }

  Future<ServiceData?> createNewService() async {
    log('createNewService: Starting service creation');
    
    if (selectedCategory == null) {
      log('createNewService: No category selected');
      toast(language.selectCategory);
      return null;
    }

    log('createNewService: Building service request');
    final req = await _buildServiceRequest();
    
    log('createNewService: Submitting service to API');
    return await _submitService(req);
  }

  Future<ServiceData?> _submitService(MultipartRequest req) async {
    try {
      log('_submitService: Sending service creation request to API');
      ServiceData? newService;
      
      await sendMultiPartRequest(
        req,
        onSuccess: (data) async {
          log('_submitService: API Response received: $data');
          var response = jsonDecode(data);
          
          // Check for service_id in response (direct field)
          if (response['service_id'] != null) {
            int serviceId = int.parse(response['service_id'].toString());
            log('_submitService: Service created with ID: $serviceId');
            
            // Create ServiceData object with the received ID and form data
            newService = ServiceData(
              id: serviceId,
              name: postTitleCont.text.trim(),
              description: descriptionCont.text.trim().isNotEmpty 
                  ? descriptionCont.text.trim() 
                  : 'N/A',
              categoryId: selectedCategory?.id,
              categoryName: selectedCategory?.name,
              type: SERVICE_TYPE_FIXED,
              price: 0,
              status: 1,
              attachments: imageFiles.map((e) => e.path).toList(),
            );
            log('_submitService: Service created successfully - ID: ${newService?.id}, Name: ${newService?.name}');
          } 
          // Fallback: Check for data field (alternative response structure)
          else if (response['data'] != null) {
            newService = ServiceData.fromJson(response['data']);
            log('_submitService: Service created successfully with ID: ${newService?.id}');
          } 
          else {
            log('_submitService: Warning - No service data or service_id in response');
          }
        },
        onError: (error) {
          log('_submitService: API Error: $error');
          toast(error.toString(), print: true);
          throw error;
        },
      ).catchError((e) {
        log('_submitService: Exception caught: $e');
        toast(e.toString(), print: true);
        throw e;
      });
      
      log('_submitService: Returning service data: ${newService?.toJson()}');
      return newService;
    } catch (e) {
      log('_submitService: Fatal error: $e');
      toast(e.toString());
      throw e;
    }
  }

  Future<File?> _getPlaceholderImageFile() async {
    try {
      log('_getPlaceholderImageFile: Loading placeholder image from assets');
      final ByteData data = await rootBundle.load('assets/place_holder.png');
      final List<int> bytes = data.buffer.asUint8List();
      
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = path.join(tempDir.path, 'place_holder_${DateTime.now().millisecondsSinceEpoch}.png');
      final File tempFile = File(tempPath);
      
      await tempFile.writeAsBytes(bytes);
      log('_getPlaceholderImageFile: Placeholder image saved to: $tempPath');
      
      return tempFile;
    } catch (e) {
      log('_getPlaceholderImageFile: Error loading placeholder - $e');
      return null;
    }
  }

  Future<MultipartRequest> _buildServiceRequest() async {
    log('_buildServiceRequest: Building multipart request');
    
    MultipartRequest multiPartRequest =
        await getMultiPartRequest('service-save');
        
    multiPartRequest.fields[CreateService.name] = postTitleCont.text.trim();
    multiPartRequest.fields[CreateService.description] = 
        descriptionCont.text.trim().isNotEmpty 
            ? descriptionCont.text.trim() 
            : 'N/A';
    multiPartRequest.fields[CreateService.type] = SERVICE_TYPE_FIXED;
    multiPartRequest.fields[CreateService.price] = '0';
    multiPartRequest.fields[CreateService.addedBy] =
        appStore.userId.toString().validate();
    multiPartRequest.fields[CreateService.providerId] =
        appStore.userId.toString();
    multiPartRequest.fields[CreateService.categoryId] =
        selectedCategory!.id.toString();
    multiPartRequest.fields[CreateService.status] = '1';
    multiPartRequest.fields[CreateService.duration] = "0";
    
    log('_buildServiceRequest: Request fields: ${multiPartRequest.fields}');

    if (imageFiles.isNotEmpty) {
      log('_buildServiceRequest: Processing ${imageFiles.length} images');
      
      List<XFile> tempImages = imageFiles
          .where((element) => !element.path.contains("https"))
          .toList();

      multiPartRequest.files.clear();
      await Future.forEach<XFile>(tempImages, (element) async {
        int i = tempImages.indexOf(element);
        multiPartRequest.files.add(await MultipartFile.fromPath(
            '${CreateService.serviceAttachment + i.toString()}', element.path));
        log('_buildServiceRequest: Added image ${i + 1}/${tempImages.length}');
      });

      if (tempImages.isNotEmpty) {
        multiPartRequest.fields[CreateService.attachmentCount] =
            tempImages.length.toString();
        log('_buildServiceRequest: Total images attached: ${tempImages.length}');
      }
    } else {
      log('_buildServiceRequest: No images attached, using placeholder image');
      
      // Use placeholder image when no images are attached
      File? placeholderFile = await _getPlaceholderImageFile();
      if (placeholderFile != null && await placeholderFile.exists()) {
        multiPartRequest.files.clear();
        multiPartRequest.files.add(await MultipartFile.fromPath(
            '${CreateService.serviceAttachment}0', placeholderFile.path));
        multiPartRequest.fields[CreateService.attachmentCount] = '1';
        log('_buildServiceRequest: Placeholder image added successfully');
      } else {
        log('_buildServiceRequest: Warning - Could not load placeholder image');
      }
    }

    multiPartRequest.headers.addAll(buildHeaderTokens());
    log('_buildServiceRequest: Request built successfully');

    return multiPartRequest;
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => hideKeyboard(context),
      child: AppScaffold(
        appBarTitle: language.newPostJobRequest,
        child: Observer(
          builder: (context) {
            return Stack(
              children: [
                AnimatedScrollView(
              listAnimationType: ListAnimationType.FadeIn,
              fadeInConfiguration: FadeInConfiguration(duration: 2.seconds),
              padding: EdgeInsets.only(bottom: 100),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          16.height,
                          AppTextField(
                            controller: postTitleCont,
                            textFieldType: TextFieldType.NAME,
                            errorThisFieldRequired: language.requiredText,
                            nextFocus: descriptionFocus,
                            decoration: inputDecoration(
                              context,
                              labelText: language.postJobTitle,
                            ),
                          ),
                          16.height,
                          AppTextField(
                            controller: descriptionCont,
                            textFieldType: TextFieldType.MULTILINE,
                            errorThisFieldRequired: language.requiredText,
                            maxLines: 2,
                            focus: descriptionFocus,
                            nextFocus: priceFocus,
                            enableChatGPT: appConfigurationStore.chatGPTStatus,
                            promptFieldInputDecorationChatGPT:
                                inputDecoration(context).copyWith(
                              hintText: language.writeHere,
                              fillColor: context.scaffoldBackgroundColor,
                              filled: true,
                            ),
                            testWithoutKeyChatGPT:
                                appConfigurationStore.testWithoutKey,
                            loaderWidgetForChatGPT:
                                const ChatGPTLoadingWidget(),
                            decoration: inputDecoration(
                              context,
                              labelText: language.postJobDescription,
                            ),
                          ),
                          16.height,
                          AppTextField(
                            textFieldType: TextFieldType.PHONE,
                            controller: priceCont,
                            focus: priceFocus,
                            errorThisFieldRequired: language.requiredText,
                            decoration: inputDecoration(
                              context,
                              labelText: language.price,
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            validator: (s) {
                              if (s!.isEmpty) return errorThisFieldRequired;

                              if (s.toDouble() <= 0)
                                return language.priceAmountValidationMessage;
                              return null;
                            },
                          ),
                          16.height,
                          AppTextField(
                            textFieldType: TextFieldType.MULTILINE,
                            controller: addressCont,
                            onChanged: (s) {
                              log(s);
                            },
                            decoration: inputDecoration(
                              labelText: language.lblYourAddress,
                              context,
                              prefixIcon: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ic_location
                                      .iconImage(size: 22)
                                      .paddingOnly(top: 8),
                                ],
                              ),
                            ).copyWith(
                              fillColor: context.cardColor,
                              filled: true,
                              hintText: language.lblEnterYourAddress,
                              hintStyle: secondaryTextStyle(),
                            ),
                          ),
                          8.height,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                child: Text(
                                  language.lblChooseFromMap,
                                  style: boldTextStyle(
                                    color: context.primaryColor,
                                    size: 13,
                                  ),
                                ),
                                onPressed: () {
                                  _handleSetLocationClick();
                                },
                              ).flexible(),
                              TextButton(
                                onPressed: _handleCurrentLocationClick,
                                child: Text(
                                  language.lblUseCurrentLocation,
                                  style: boldTextStyle(
                                    color: context.primaryColor,
                                    size: 13,
                                  ),
                                ),
                              ).flexible(),
                            ],
                          ),
                          16.height,
                          DropdownButtonFormField<CategoryData>(
                            decoration: inputDecoration(context,
                                labelText: language.lblCategory),
                            hint: Text(language.selectCategory,
                                style: secondaryTextStyle()),
                            value: selectedCategory,
                            dropdownColor: context.scaffoldBackgroundColor,
                            items: categoryList.map((data) {
                              return DropdownMenuItem<CategoryData>(
                                value: data,
                                child: Text(data.name.validate(),
                                    style: primaryTextStyle()),
                              );
                            }).toList(),
                            onChanged: (CategoryData? value) async {
                              selectedCategory = value!;
                              setState(() {});
                            },
                          ),
                          16.height,
                          SizedBox(
                            width: context.width(),
                            height: 120,
                            child: DottedBorderWidget(
                              color: primaryColor.withValues(alpha: 0.6),
                              strokeWidth: 1,
                              gap: 6,
                              radius: 12,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(selectImage,
                                      height: 25,
                                      width: 25,
                                      color: appStore.isDarkMode ? white : gray),
                                  8.height,
                                  Text(language.chooseImages, style: boldTextStyle()),
                                ],
                              ).center().onTap(borderRadius: radius(), () async {
                                getMultipleFile();
                              }),
                            ),
                          ),
                          if (imageFiles.isNotEmpty)
                            HorizontalList(
                              itemCount: imageFiles.length,
                              itemBuilder: (context, i) {
                                return Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Image.file(File(imageFiles[i].path),
                                            width: 90, height: 90, fit: BoxFit.cover)
                                        .cornerRadiusWithClipRRect(16),
                                    Container(
                                      decoration: boxDecorationWithRoundedCorners(
                                          boxShape: BoxShape.circle,
                                          backgroundColor: primaryColor),
                                      margin: EdgeInsets.only(right: 8, top: 4),
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.close, size: 16, color: white),
                                    ).onTap(() {
                                      showConfirmDialogCustom(
                                        context,
                                        dialogType: DialogType.DELETE,
                                        positiveText: language.lblDelete,
                                        negativeText: language.lblCancel,
                                        primaryColor: context.primaryColor,
                                        onAccept: (p0) {
                                          imageFiles.removeAt(i);
                                          setState(() {});
                                        },
                                      );
                                    }),
                                  ],
                                );
                              },
                            ).paddingBottom(16),
                        ],
                      ).paddingAll(16),
                    ),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Text(
                    //       language.services,
                    //       style: boldTextStyle(size: LABEL_TEXT_SIZE),
                    //     ),
                    //   ],
                    // ).paddingOnly(right: 8, left: 16, top: 8),
                    // if (myServiceList.isNotEmpty)
                    //   AnimatedListView(
                    //     itemCount: myServiceList.length,
                    //     shrinkWrap: true,
                    //     physics: NeverScrollableScrollPhysics(),
                    //     padding: EdgeInsets.all(8),
                    //     listAnimationType: ListAnimationType.FadeIn,
                    //     itemBuilder: (_, i) {
                    //       ServiceData data = myServiceList[i];

                    //       return Container(
                    //         padding: EdgeInsets.all(8),
                    //         margin: EdgeInsets.all(8),
                    //         width: context.width(),
                    //         decoration: boxDecorationWithRoundedCorners(
                    //           backgroundColor: context.cardColor,
                    //         ),
                    //         child: Row(
                    //           children: [
                    //             CachedImageWidget(
                    //               url: data.attachments.validate().isNotEmpty
                    //                   ? data.attachments!.first.validate()
                    //                   : "assets/place_holder.png",
                    //               fit: BoxFit.cover,
                    //               height: 60,
                    //               width: 60,
                    //               radius: defaultRadius,
                    //             ),
                    //             16.width,
                    //             Column(
                    //               crossAxisAlignment: CrossAxisAlignment.start,
                    //               children: [
                    //                 Text(
                    //                   data.categoryName.validate(),
                    //                   style: boldTextStyle(),
                    //                 ),
                    //                 4.height,
                    //                 Text(
                    //                   data.name.validate(),
                    //                   style: secondaryTextStyle(),
                    //                 ),
                    //               ],
                    //             ).expand(),
                    //             IconButton(
                    //               icon: ic_delete.iconImage(size: 14),
                    //               visualDensity: VisualDensity.compact,
                    //               onPressed: () {
                    //                 showConfirmDialogCustom(
                    //                   context,
                    //                   dialogType: DialogType.DELETE,
                    //                   positiveText: language.lblDelete,
                    //                   negativeText: language.lblCancel,
                    //                   onAccept: (p0) {
                    //                     deleteService(data);
                    //                   },
                    //                 );
                    //               },
                    //             ),
                    //             selectedServiceList.any((e) => e.id == data.id)
                    //                 ? AppButton(
                    //                     child: Text(
                    //                       language.remove,
                    //                       style: boldTextStyle(
                    //                         color: redColor,
                    //                         size: 14,
                    //                       ),
                    //                     ),
                    //                     onTap: () {
                    //                       selectedServiceList.remove(data);
                    //                       setState(() {});
                    //                     },
                    //                   )
                    //                 : AppButton(
                    //                     child: Text(
                    //                       language.add,
                    //                       style: boldTextStyle(
                    //                         size: 14,
                    //                         color: context.primaryColor,
                    //                       ),
                    //                     ),
                    //                     onTap: () {
                    //                       selectedServiceList.add(data);
                    //                       setState(() {});
                    //                     },
                    //                   ),
                    //           ],
                    //         ),
                    //       );
                    //     },
                    //   ),
                    // if (myServiceList.isEmpty && !appStore.isLoading)
                    //   NoDataWidget(
                    //     imageWidget: EmptyStateWidget(),
                    //     title: language.noServiceAdded,
                    //     imageSize: Size(90, 90),
                    //   ).paddingOnly(top: 16),
                  ],
                ),
              ],
            ),
            
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: AppButton(
                child: isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: context.primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                          16.width,
                          Text(
                            language.loading,
                            style: boldTextStyle(color: context.primaryColor),
                          ),
                        ],
                      )
                    : Text(language.save, style: boldTextStyle(color: white)),
                color: context.primaryColor,
                width: context.width(),
                onTap: isSaving
                    ? null
                    : () async {
                        hideKeyboard(context);
                        
                        log('Save Button: Clicked');

                        if (formKey.currentState!.validate()) {
                          formKey.currentState!.save();
                          log('Save Button: Form validation passed');

                          try {
                            setState(() => isSaving = true);
                            log('Save Button: Saving state set to true');
                            
                            // First create the service
                            log('Save Button: Starting service creation flow');
                            ServiceData? newService = await createNewService();
                            
                            if (newService != null) {
                              log('Save Button: Service created successfully - Service ID: ${newService.id}, Name: ${newService.name}');
                              
                              // Add the newly created service to the selected list
                              selectedServiceList.clear(); // Clear any existing selections
                              selectedServiceList.add(newService);
                              log('Save Button: Added service to selectedServiceList (Total: ${selectedServiceList.length})');
                              
                              // Now create the post job with the service
                              log('Save Button: Starting post job creation');
                              await createPostJobClick();
                            } else {
                              log('Save Button: Service creation returned null - stopping flow');
                              setState(() => isSaving = false);
                              toast(language.selectCategory);
                            }
                          } catch (e) {
                            log('Save Button: Error caught - $e');
                            setState(() => isSaving = false);
                            toast(e.toString());
                          }
                        } else {
                          log('Save Button: Form validation failed');
                        }
                      },
              ),
            ),
            
            // Loading overlay for page initialization
            if (appStore.isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: context.primaryColor,
                        ),
                        16.height,
                        Text(
                          language.loading,
                          style: boldTextStyle(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
      ),
    );
  }
}
