import 'package:fk/app_state.dart';
import 'package:fk/common_widgets.dart';
import 'package:fk/deploy/deploy_page.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/gen/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class ConfigureSchedulePage extends StatelessWidget {
  const ConfigureSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final StationConfiguration configuration =
        context.read<StationConfiguration>();

    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Column(
            children: [
              Text(AppLocalizations.of(context)!.deployTitle),
              Text(
                configuration.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        body: ListView(
          children: const [
            ConfigureScheduleForm(),
          ],
        ));
  }
}

class ConfigureScheduleForm extends StatefulWidget {
  const ConfigureScheduleForm({super.key});

  @override
  State<StatefulWidget> createState() => _ConfigureScheduleFormState();
}

class _ConfigureScheduleFormState extends State<ConfigureScheduleForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final StationConfiguration configuration =
        context.read<StationConfiguration>();
    final navigator = Navigator.of(context);
    final initial =
        configuration.config.ephemeral?.schedules?.readings?.schedule;

    return FormBuilder(
        key: _formKey,
        child: Column(
          children: [
            ScheduleWidget(initial: initial),
            ElevatedTextButton(
              onPressed: configuration.config.connected
                  ? () async {
                      if (_formKey.currentState!.saveAndValidate()) {
                        final messenger = ScaffoldMessenger.of(context);
                        final values =
                            _formKey.currentState!.value as FormValues;
                        final schedule = ScheduleHelpers.fromForm(values);
                        final overlay = context.loaderOverlay;
                        final isDeployed = configuration
                                .config.ephemeral?.deployment?.startTime !=
                            null;

                        overlay.show();
                        try {
                          // First save the schedule
                          await configuration
                              .schedules(ScheduleConfig(schedule: schedule));

                          if (!isDeployed) {
                            // Deploy the station with the schedule
                            final deployed =
                                DateTime.now().millisecondsSinceEpoch ~/ 1000;
                            await configuration.deploy(DeployConfig(
                                location:
                                    "", // Default location for new deployment as an empty string
                                deployed: BigInt.from(deployed),
                                schedule: schedule));
                          }

                          navigator.pop();
                          messenger.showSnackBar(SnackBar(
                            content: Text(isDeployed
                                ? localizations.scheduleUpdated
                                : localizations.stationDeployed),
                          ));
                        } catch (e) {
                          Loggers.ui.e("Schedule/Deploy error: $e");
                          messenger.showSnackBar(SnackBar(
                            content: Text(localizations.unknownError),
                          ));
                        } finally {
                          overlay.hide();
                        }
                      }
                    }
                  : null,
              text:
                  configuration.config.ephemeral?.deployment?.startTime != null
                      ? localizations.save
                      : localizations.deployButton,
            ),
          ]
              .map((child) =>
                  Padding(padding: const EdgeInsets.all(8), child: child))
              .toList(),
        ));
  }
}

class ScheduleWidget extends StatelessWidget {
  final Schedule? initial;

  const ScheduleWidget({super.key, this.initial});

  @override
  Widget build(BuildContext context) {
    return SimpleScheduleWidget(initial: initial);
  }
}

class SimpleScheduleWidget extends StatelessWidget {
  final Schedule? initial;

  const SimpleScheduleWidget({super.key, this.initial});

  String initialMinutes() {
    final seconds = initial?.field0;
    if (seconds == null) {
      return "5";
    }
    return "${(seconds / 60).round()}";
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(0),
                child: FormBuilderTextField(
                  name: 'scheduleEvery',
                  initialValue: initialMinutes(),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.every,
                  ),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.integer(),
                  ]),
                ))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: FormBuilderDropdown<UnitOfTime>(
                  name: 'scheduleUnit',
                  initialValue: UnitOfTime.minutes,
                  items: [
                    DropdownMenuItem<UnitOfTime>(
                      value: UnitOfTime.minutes,
                      child: Text(AppLocalizations.of(context)!.minutes),
                    ),
                    DropdownMenuItem<UnitOfTime>(
                      value: UnitOfTime.hours,
                      child: Text(AppLocalizations.of(context)!.hours),
                    ),
                  ],
                ))),
      ],
    ));
  }
}

enum UnitOfTime {
  minutes,
  hours,
}
