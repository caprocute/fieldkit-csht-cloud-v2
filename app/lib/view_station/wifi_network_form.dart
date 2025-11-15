import 'package:fk/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:fk/l10n/app_localizations.dart';

import '../common_widgets.dart';

typedef FormValues = Map<String, Object?>;

class WifiNetworkForm extends StatefulWidget {
  final void Function(WifiNetwork) onSave;
  final WifiNetwork original;

  const WifiNetworkForm(
      {super.key, required this.onSave, required this.original});

  @override
  State<WifiNetworkForm> createState() => _WifiNetworkFormState();
}

class _WifiNetworkFormState extends State<WifiNetworkForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.networkEditTitle),
      ),
      body: FormBuilder(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FormBuilderTextField(
              name: 'ssid',
              initialValue: widget.original.ssid,
              decoration: InputDecoration(labelText: localizations.wifiSsid),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
              ]),
            ),
            FormBuilderTextField(
              name: 'password',
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: localizations.wifiPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
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
              ]),
            ),
            ElevatedTextButton(
              onPressed: () async {
                if (_formKey.currentState!.saveAndValidate()) {
                  final values = _formKey.currentState!.value as FormValues;
                  final String ssid = values['ssid'] as String;
                  final String password = values['password'] as String;
                  widget.onSave(WifiNetwork(
                      ssid: ssid, password: password, preferred: false));
                }
              },
              text: localizations.networkSaveButton,
            ),
          ]
              .map((child) =>
                  Padding(padding: const EdgeInsets.all(8), child: child))
              .toList(),
        ),
      ),
    );
  }
}
