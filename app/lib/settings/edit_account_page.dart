import 'package:flutter/material.dart';
import 'package:fk/common_widgets.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_svg/svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../app_state.dart';
import '../diagnostics.dart';

typedef FormValues = Map<String, Object?>;

class EditAccountPage extends StatefulWidget {
  final PortalAccount original;

  const EditAccountPage({super.key, required this.original});

  @override
  State<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  final _passwordKey = UniqueKey();
  final _confirmPasswordKey = UniqueKey();
  final _formKey = GlobalKey<FormBuilderState>();
  bool _passwordVisible = false;
  bool _registering = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();

    setState(() {
      _isConnected = connectivityResult.first != ConnectivityResult.none;
    });
  }

  Future<void> _save(BuildContext context, PortalAccounts accounts,
      AppLocalizations localizations) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final overlay = context.loaderOverlay;
    final values = _formKey.currentState!.value as FormValues;
    final String email = values['email'] as String;
    final String password = values['password'] as String;
    overlay.show();
    try {
      if (_registering) {
        final String name = values['name'] as String;
        bool tncAccept = true;
        final error =
            await accounts.registerAccount(email, password, name, tncAccept);
        if (error == null) {
          // Note, registerAccount returns null on success
          navigator.pop();
          messenger.showSnackBar(SnackBar(
            content: Text(localizations.accountCreated),
          ));
        } else {
          _handleAccountError(messenger, localizations, error);
        }
      } else {
        final error = await accounts.addOrUpdate(email, password);
        if (error == null) {
          // Note, addOrUpdate returns null on success
          navigator.pop();
          messenger.showSnackBar(SnackBar(
            content: Text(localizations.accountUpdated),
          ));
        } else {
          _handleAccountError(messenger, localizations, error);
        }
      }
    } catch (error) {
      Loggers.portal.e("$error");
      messenger.showSnackBar(SnackBar(
        content: Text(localizations.unknownError),
      ));
    } finally {
      overlay.hide();
    }
  }

  void _handleAccountError(ScaffoldMessengerState messenger,
      AppLocalizations localizations, AccountError error) {
    String message;
    switch (error) {
      case AccountError.invalidCredentials:
        message = localizations.invalidCredentialsError;
        break;
      case AccountError.serverError:
        message = localizations.serverError;
        break;
      default:
        message = localizations.unknownError;
        break;
    }
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 7),
      showCloseIcon: true,
      closeIconColor: Colors.black,
      backgroundColor: const Color(0xffffd4cc),
      content: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SvgPicture.asset(
              'resources/images/confirm_dark_icon.svg',
              width: 15,
              height: 15,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(color: Colors.black),
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.read<PortalAccounts>();
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.accountAddTitle),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      FormBuilder(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          // Form Builder will use the **order** and type
                          // of fields to try and infer field values when rebuilding the widgets after a
                          // refresh. This means that if the order here changes field values can move around
                          // and this is especially important because one or more of these fields have a
                          // password in them. So, always use `Visibility` here to show/hide things. I've
                          // also added a `UniqueKey` on password in the hopes that it'll always be able to
                          // find the right value using that. I wasn't able to find a mention of this gotcha
                          // in the documentation and would love to reference that.
                          children: [
                            Visibility(
                              visible: !_isConnected,
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                color: const Color(0xFFF4F5F7),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'resources/images/icon_warning_error.png',
                                        width: 20,
                                        height: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(localizations.noInternetConnection,
                                          style: const TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Visibility(
                              visible: _registering,
                              child: FormBuilderTextField(
                                name: 'name',
                                keyboardType: TextInputType.name,
                                decoration: InputDecoration(
                                    labelText: localizations.accountName),
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                ]),
                              ),
                            ),
                            FormBuilderTextField(
                              name: 'email',
                              initialValue: widget.original.email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                  labelText: localizations.accountEmail),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(),
                                FormBuilderValidators.email(),
                              ]),
                            ),
                            FormBuilderTextField(
                              key: _passwordKey,
                              name: 'password',
                              keyboardType: TextInputType.visiblePassword,
                              decoration: InputDecoration(
                                labelText: localizations.accountPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Theme.of(context).primaryColorDark,
                                  ),
                                  tooltip: _passwordVisible
                                      ? localizations.passwordHideTooltip
                                      : localizations.passwordShowTooltip,
                                  onPressed: () {
                                    setState(() {
                                      _passwordVisible = !_passwordVisible;
                                    });
                                  },
                                ),
                              ),
                              obscureText: !_passwordVisible,
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(),
                                FormBuilderValidators.minLength(10),
                              ]),
                            ),
                            Visibility(
                              visible: _registering,
                              child: FormBuilderTextField(
                                key: _confirmPasswordKey,
                                name: 'confirmPassword',
                                keyboardType: TextInputType.visiblePassword,
                                decoration: InputDecoration(
                                  labelText:
                                      localizations.accountConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Theme.of(context).primaryColorDark,
                                    ),
                                    tooltip: _passwordVisible
                                        ? localizations.passwordHideTooltip
                                        : localizations.passwordShowTooltip,
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: !_passwordVisible,
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                  FormBuilderValidators.minLength(10),
                                  (val) {
                                    if (_formKey.currentState
                                            ?.fields["password"]?.value ==
                                        val) {
                                      return null;
                                    }
                                    return localizations
                                        .accountConfirmPasswordMatch;
                                  }
                                ]),
                              ),
                            ),
                            CheckboxListTile(
                              title: Text(localizations.accountRegisterLabel),
                              tristate: false, // can not be null
                              value: _registering,
                              onChanged: (bool? value) {
                                setState(() {
                                  _registering = value ?? false;
                                });
                              },
                            ),
                            ElevatedTextButton(
                              onPressed: _isConnected
                                  ? () async {
                                      if (_formKey.currentState!
                                          .saveAndValidate()) {
                                        await _save(
                                            context, accounts, localizations);
                                      }
                                    }
                                  : null,
                              text: _registering
                                  ? localizations.accountRegisterButton
                                  : localizations.accountSaveButton,
                            ),
                          ]
                              .map((child) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: child))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
