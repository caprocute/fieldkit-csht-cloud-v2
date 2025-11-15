import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:fk/app_state.dart';
import '../l10n/app_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fk/constants.dart';
import 'dart:io' show Platform, File;
import 'package:image_picker/image_picker.dart';

import 'package:fk/diagnostics.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;

class ReportIssueDraft {
  static final ReportIssueDraft _instance = ReportIssueDraft._internal();
  factory ReportIssueDraft() => _instance;
  ReportIssueDraft._internal();

  String? email;
  String? description;
  List<XFile> images = [];

  void clear() {
    email = null;
    description = null;
    images = [];
  }
}

class DeskproApiHelper {
  static String? getApiKeyError() {
    final apiKey = dotenv.env['DESKPRO_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      return 'DESKPRO_API_KEY is not set in the .env file. Please create a .env file based on env.template and add your DeskPro API key.';
    }

    final cleanApiKey = apiKey.trim();
    if (cleanApiKey.isEmpty) {
      return 'DESKPRO_API_KEY is blank. Please add your DeskPro API key to the .env file.';
    }

    if (cleanApiKey.contains('YOUR_ACTUAL_DESKPRO_API_KEY_HERE')) {
      return 'Please replace the placeholder DESKPRO_API_KEY in your .env file with your actual DeskPro API key.';
    }

    return null; // No error
  }

  static String getApiKey() {
    final apiKey = dotenv.env['DESKPRO_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DESKPRO_API_KEY is not set');
    }
    final cleanApiKey = apiKey.trim();
    if (cleanApiKey.isEmpty) {
      throw Exception('DESKPRO_API_KEY is blank');
    }
    if (cleanApiKey.contains('YOUR_ACTUAL_DESKPRO_API_KEY_HERE')) {
      throw Exception('DESKPRO_API_KEY contains placeholder');
    }
    return cleanApiKey;
  }

  static Map<String, String> getHeaders(String apiKey) {
    return {
      'Authorization': 'key $apiKey',
      'X-DeskPRO-Agent-ID': getAgentId().toString(),
    };
  }

  static Map<String, String> getJsonHeaders(String apiKey) {
    return {
      'Content-Type': 'application/json',
      ...getHeaders(apiKey),
    };
  }

  static void validateEmail(String email) {
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      throw Exception('Invalid email format: $email');
    }
  }

  static String? getDepartmentError() {
    final departmentStr = dotenv.env['DESKPRO_DEPARTMENT'];

    if (departmentStr == null || departmentStr.isEmpty) {
      return 'DESKPRO_DEPARTMENT is not set in the .env file. Please add your DeskPro department ID to the .env file.';
    }

    final department = int.tryParse(departmentStr);
    if (department == null) {
      return 'Invalid DESKPRO_DEPARTMENT value: $departmentStr. Please set a valid integer department ID in the .env file.';
    }

    return null; // No error
  }

  static int getDepartment() {
    final departmentStr = dotenv.env['DESKPRO_DEPARTMENT'];
    if (departmentStr == null || departmentStr.isEmpty) {
      throw Exception('DESKPRO_DEPARTMENT is not set');
    }
    final department = int.tryParse(departmentStr);
    if (department == null) {
      throw Exception('Invalid DESKPRO_DEPARTMENT value: $departmentStr');
    }
    return department;
  }

  static String? getAgentIdError() {
    final agentIdStr = dotenv.env['DESKPRO_AGENT_ID'];

    if (agentIdStr == null || agentIdStr.isEmpty) {
      return 'DESKPRO_AGENT_ID is not set in the .env file. Please add your DeskPro agent ID to the .env file.';
    }

    final agentId = int.tryParse(agentIdStr);
    if (agentId == null) {
      return 'Invalid DESKPRO_AGENT_ID value: $agentIdStr. Please set a valid integer agent ID in the .env file.';
    }

    return null; // No error
  }

  static int getAgentId() {
    final agentIdStr = dotenv.env['DESKPRO_AGENT_ID'];
    if (agentIdStr == null || agentIdStr.isEmpty) {
      throw Exception('DESKPRO_AGENT_ID is not set');
    }
    final agentId = int.tryParse(agentIdStr);
    if (agentId == null) {
      throw Exception('Invalid DESKPRO_AGENT_ID value: $agentIdStr');
    }
    return agentId;
  }
}

Future<List<String>> uploadFilesToDeskpro({
  required List<String> filePaths,
}) async {
  final apiKey = DeskproApiHelper.getApiKey();
  final List<String> blobTokens = [];

  for (String filePath in filePaths) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        Loggers.ui.w('File does not exist: $filePath');
        continue;
      }

      final fileName = path.basename(filePath);
      final fileBytes = await file.readAsBytes();

      final uri = Uri.parse('https://fieldkit.deskpro.com/api/v2/blobs');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(DeskproApiHelper.getHeaders(apiKey));

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ));

      Loggers.ui.i('Uploading file: $fileName (${fileBytes.length} bytes)');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final responseData = jsonDecode(responseBody);
        final blobToken = responseData['data']?['blob_auth'];
        if (blobToken != null) {
          blobTokens.add(blobToken);
          Loggers.ui.i(
              'File uploaded successfully: $fileName, blob token: $blobToken');
        } else {
          Loggers.ui.w('No blob token returned for file: $fileName');
        }
      } else {
        Loggers.ui.e('Failed to upload file $fileName: ${response.statusCode}');
        Loggers.ui.e('Response: $responseBody');
      }
    } catch (e) {
      Loggers.ui.e('Error uploading file $filePath: $e');
    }
  }

  return blobTokens;
}

Future<void> submitDeskproTicket({
  required String subject,
  required String email,
  required String messageHtml,
  List<String>? blobAuthTokens,
}) async {
  final url = Uri.parse('https://fieldkit.deskpro.com/api/v2/tickets');
  final apiKey = DeskproApiHelper.getApiKey();

  DeskproApiHelper.validateEmail(email);

  final headers = DeskproApiHelper.getJsonHeaders(apiKey);

  final message = <String, dynamic>{
    'message': messageHtml,
    'format': 'html',
    if (blobAuthTokens != null && blobAuthTokens.isNotEmpty)
      'attachments': blobAuthTokens
          .map((token) => <String, dynamic>{
                'blob_auth': token,
                'is_inline': false,
              })
          .toList(),
  };

  final requestBody = <String, dynamic>{
    'subject': subject.trim(),
    'person': email.trim(),
    'message': message,
    'department': DeskproApiHelper.getDepartment(),
  };

  try {
    final body = jsonEncode(requestBody);

    Loggers.ui.d('Request URL: $url');
    Loggers.ui.d('Request headers: ${headers.keys.join(', ')}');
    Loggers.ui.d('Request body length: ${body.length}');

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 201) {
      Loggers.ui.i('Ticket created successfully.');
    } else if (response.statusCode == 400) {
      Loggers.ui.e('Failed to create ticket: ${response.statusCode}');
      Loggers.ui.e('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      if (responseData['code'] == 'invalid_input' &&
          responseData['errors']?['errors']
                  ?.any((error) => error['code'] == 'dupe_ticket') ==
              true) {
        throw Exception(
            'This appears to be a duplicate ticket. Please wait a few minutes before submitting again or modify your description.');
      } else {
        Loggers.ui.e('API Key used: $apiKey');
        throw Exception(
            'Failed to create ticket: ${responseData['message'] ?? 'Unknown error'}');
      }
    } else {
      Loggers.ui.e('Failed to create ticket: ${response.statusCode}');
      Loggers.ui.e('Response body: ${response.body}');
      Loggers.ui.e('API Key used: $apiKey');
      throw Exception('Failed to create ticket: HTTP ${response.statusCode}');
    }
  } on FormatException catch (e) {
    Loggers.ui.e('JSON encoding error: $e');
    Loggers.ui.e('API Key used: $apiKey');
    throw Exception('Failed to encode request data: $e');
  } on Exception catch (e) {
    Loggers.ui.e('HTTP request error: $e');
    Loggers.ui.e('API Key used: $apiKey');
    throw Exception('Network error: ${e.toString()}');
  } catch (e) {
    Loggers.ui.e('Unexpected error submitting ticket: $e');
    Loggers.ui.e('API Key used: $apiKey');
    rethrow;
  }
}

class ReportIssuePage extends StatefulWidget {
  final String? email;

  const ReportIssuePage({super.key, this.email});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final List<XFile> _images = [];
  // final _picker = ImagePicker();
  String? _diagnosticsPath;
  String? _selectedEmail;
  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final draft = ReportIssueDraft();
    _selectedEmail = draft.email;
    _emailController =
        TextEditingController(text: draft.email ?? widget.email ?? '');
    _descriptionController =
        TextEditingController(text: draft.description ?? '');
    _images.addAll(draft.images);
  }

  @override
  void dispose() {
    final draft = ReportIssueDraft();
    draft.email = _selectedEmail ?? _emailController.text;
    draft.description = _descriptionController.text;
    draft.images = List<XFile>.from(_images);
    super.dispose();
  }

  // Future<void> _pickImage() async {
  //   final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
  //   if (image != null && mounted) {
  //     setState(() {
  //       _images.add(image);
  //       ReportIssueDraft().images = List<XFile>.from(_images);
  //     });
  //   }
  // }

  // Future<void> _takePhoto() async {
  //   final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
  //   if (photo != null && mounted) {
  //     setState(() {
  //       _images.add(photo);
  //       ReportIssueDraft().images = List<XFile>.from(_images);
  //     });
  //   }
  // }

  Future<String> _getAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<String> _getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.systemName} ${iosInfo.systemVersion} / ${iosInfo.model}';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return 'Android ${androidInfo.version.release} / ${androidInfo.model}';
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      return 'macOS ${macInfo.osRelease} / ${macInfo.model}';
    }
    return 'Unknown Device';
  }

  Future<void> _saveDiagnostics() async {
    try {
      final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
      final stamp = formatter.format(DateTime.now());
      final support = await getApplicationSupportDirectory();
      final diagnosticsPath = "${support.path}/diagnostics-$stamp.txt";

      final logsFile = File(Loggers.path);
      if (logsFile.existsSync()) {
        await logsFile.copy(diagnosticsPath);
        _diagnosticsPath = diagnosticsPath;
        Loggers.ui.i("Diagnostics saved to: $_diagnosticsPath");
      }
    } catch (e) {
      Loggers.ui.e("Failed to save diagnostics: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final portalAccounts = context.watch<PortalAccounts>();
    final isLoggedIn = portalAccounts.hasAnyValidTokens();
    final accounts = portalAccounts.accounts;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.reportIssue),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmailField(context, isLoggedIn, accounts, localizations),
              Text(localizations.reportIssue,
                  style: const TextStyle(fontSize: 16, fontFamily: "Avenir")),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: localizations.reportIssueDescription,
                ),
                onChanged: (value) {
                  ReportIssueDraft().description = value;
                },
              ),
              const SizedBox(height: 16),
              // Temporarily disabled image functionality
              // Text(localizations.photos,
              //     style: const TextStyle(fontSize: 16, fontFamily: "Avenir")),
              // const SizedBox(height: 8),
              // _buildImagePickerRow(localizations),
              // const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 300,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () =>
                        _onSubmit(context, isLoggedIn, localizations),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                    child: Text(localizations.reportIssueSubmit),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context, bool isLoggedIn, List accounts,
      AppLocalizations localizations) {
    if (!isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.reportIssueEmail,
              style: const TextStyle(fontSize: 16, fontFamily: "Avenir")),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: localizations.reportIssueEmail,
            ),
            onChanged: (value) {
              _selectedEmail = value;
              ReportIssueDraft().email = value;
            },
          ),
          const SizedBox(height: 16),
        ],
      );
    } else if (accounts.length == 1) {
      // Pre-populated, editable
      _emailController.text = accounts.first.email;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.reportIssueEmail,
              style: const TextStyle(fontSize: 16, fontFamily: "Avenir")),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: localizations.reportIssueEmail,
            ),
            onChanged: (value) {
              _selectedEmail = value;
              ReportIssueDraft().email = value;
            },
          ),
          const SizedBox(height: 16),
        ],
      );
    } else if (accounts.length > 1) {
      // Autofill dropdown
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.reportIssueEmail,
              style: const TextStyle(fontSize: 16, fontFamily: "Avenir")),
          LayoutBuilder(
            builder: (context, constraints) {
              return Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return accounts
                      .map((a) => a.email)
                      .where((email) => email
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()))
                      .cast<String>();
                },
                onSelected: (String selection) {
                  setState(() {
                    _selectedEmail = selection;
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  controller.text = _selectedEmail ?? '';
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: localizations.reportIssueEmail,
                    ),
                    onChanged: (value) {
                      _selectedEmail = value;
                      ReportIssueDraft().email = value;
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: options.map((option) {
                            return ListTile(
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // Widget _buildImagePickerRow(AppLocalizations localizations) {
  //   return SizedBox(
  //     height: 100,
  //     child: Row(
  //       children: [
  //         GestureDetector(
  //           onTap: () {
  //             showModalBottomSheet(
  //               context: context,
  //               builder: (BuildContext context) {
  //                 return SafeArea(
  //                   child: Wrap(
  //                     children: <Widget>[
  //                       ListTile(
  //                         leading: const Icon(Icons.photo_library),
  //                         title: Text(localizations.attachPhotos),
  //                         onTap: () {
  //                           Navigator.pop(context);
  //                           _pickImage();
  //                         },
  //                       ),
  //                       ListTile(
  //                         leading: const Icon(Icons.camera_alt),
  //                         title: Text(localizations.takePhoto),
  //                         onTap: () {
  //                           Navigator.pop(context);
  //                           _takePhoto();
  //                         },
  //                       ),
  //                     ],
  //                   ),
  //                 );
  //               },
  //             );
  //           },
  //           child: Container(
  //             width: 100,
  //             height: 100,
  //             decoration: BoxDecoration(
  //               color: Colors.grey[200],
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //             child: const Icon(
  //               Icons.add_photo_alternate,
  //               size: 40,
  //               color: Colors.grey,
  //             ),
  //           ),
  //         ),
  //         if (_images.isNotEmpty)
  //           Expanded(
  //             child: ListView.builder(
  //               scrollDirection: Axis.horizontal,
  //               itemCount: _images.length,
  //               itemBuilder: (context, index) {
  //                 return Padding(
  //                   padding: const EdgeInsets.only(left: 8.0),
  //                   child: Stack(
  //                     children: [
  //                       ClipRRect(
  //                         borderRadius: BorderRadius.circular(8),
  //                         child: Image.file(
  //                           File(_images[index].path),
  //                           height: 100,
  //                           width: 100,
  //                           fit: BoxFit.cover,
  //                         ),
  //                       ),
  //                       Positioned(
  //                         right: 0,
  //                         top: 0,
  //                         child: IconButton(
  //                           icon: const Icon(Icons.close, color: Colors.red),
  //                           onPressed: () {
  //                             setState(() {
  //                               _images.removeAt(index);
  //                               ReportIssueDraft().images =
  //                                   List<XFile>.from(_images);
  //                             });
  //                           },
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 );
  //               },
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _onSubmit(BuildContext context, bool isLoggedIn,
      AppLocalizations localizations) async {
    final String description = _descriptionController.text;
    final String? userEmail = isLoggedIn
        ? (context.read<PortalAccounts>().accounts.length > 1
            ? _selectedEmail
            : _emailController.text)
        : _emailController.text;

    if (description.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.reportIssueDescription)),
      );
      return;
    }

    if (userEmail?.trim().isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.reportIssueEmailRequired)),
      );
      return;
    }

    // Email format validation only for non-logged in users
    if (!isLoggedIn) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(userEmail!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.reportIssueEmailInvalid)),
        );
        return;
      }
    }

    try {
      // Check for configuration errors first
      final apiKeyError = DeskproApiHelper.getApiKeyError();
      if (apiKeyError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiKeyError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      final departmentError = DeskproApiHelper.getDepartmentError();
      if (departmentError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(departmentError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      final String version = await _getAppVersion();
      final String deviceInfo = await _getDeviceInfo();
      await _saveDiagnostics();

      final timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final uniqueSubject =
          'FieldKit Issue Report from $userEmail - $timestamp';

      final Map<String, String> diagnostics = {
        'App Version': version,
        'Device Info': deviceInfo,
        if (_diagnosticsPath != null) 'Diagnostics Path': _diagnosticsPath!,
      };

      // Temporarily disabled file upload functionality
      // final blobTokens = await uploadFilesToDeskpro(
      //   filePaths: _images.map((e) => e.path).toList(),
      // );
      // final blobTokens = <String>[]; // Empty list - uploads disabled

      final messageHtml = '''
        <h3>Issue Report</h3>
        <p><strong>Description:</strong><br>$description</p>
        <h4>System Information</h4>
        <ul>
          <li><strong>App Version:</strong> $version</li>
          <li><strong>Device Info:</strong> $deviceInfo</li>
          ${_diagnosticsPath != null ? '<li><strong>Diagnostics:</strong> Attached</li>' : ''}
        </ul>
      ''';

      Loggers.ui.d('Description: $description');
      Loggers.ui.d('Email: $userEmail');
      Loggers.ui.d('Diagnostics: $diagnostics');
      Loggers.ui.d('Images: ${_images.map((e) => e.path).toList()}');

      await submitDeskproTicket(
        subject: uniqueSubject,
        email: userEmail!,
        messageHtml: messageHtml,
        // blobAuthTokens: blobTokens, // Temporarily disabled
      );

      ReportIssueDraft().clear();

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text(localizations.reportIssue)),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.logoBlue, size: 80),
                    const SizedBox(height: 24),
                    Text(localizations.reportIssueSubmitted,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(localizations.reportIssueThankYou,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage;
        if (e.toString().toLowerCase().contains('network') ||
            e.toString().toLowerCase().contains('connection') ||
            e.toString().toLowerCase().contains('timeout')) {
          errorMessage = localizations.reportIssueNetworkError;
        } else if (e.toString().toLowerCase().contains('server') ||
            e.toString().toLowerCase().contains('http')) {
          errorMessage = localizations.reportIssueServerError;
        } else {
          errorMessage =
              '${localizations.reportIssueSubmissionFailed}: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      Loggers.ui.e('Error submitting report: $e');
    }
  }
}
