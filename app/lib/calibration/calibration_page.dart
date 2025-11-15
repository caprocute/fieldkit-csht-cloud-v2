import 'package:fk/models/known_stations_model.dart';
import 'package:fk/reader/screens.dart';
import 'package:flutter/material.dart';
import 'package:fk/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:caldor/calibration.dart';

import 'package:fk/gen/api.dart';
import 'package:fk/meta.dart';
import 'package:fk/app_state.dart';
import 'package:fk/diagnostics.dart';
import 'package:fk/common_widgets.dart';

import 'calibration_review_page.dart';
import 'calibration_model.dart';
import 'countdown.dart';
import 'standard_form.dart';
import 'step_counter.dart';

enum CanContinue { ready, form, countdown, staleValue, yes }

class CalibrationPage extends StatelessWidget {
  final ActiveCalibration active = ActiveCalibration();
  final CurrentCalibration current;
  final CalibrationConfig config;
  final String stationName;

  CalibrationPage({super.key, required this.config, required this.stationName})
      : current = CurrentCalibration(curveType: config.curveType);

  Future<bool?> _confirmBackDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;

    return showDialog<bool>(
        context: context,
        builder: (context) {
          final navigator = Navigator.of(context);

          return AlertDialog(
            title: Text(localizations.backAreYouSure),
            content: Text(localizations.backWarning),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    navigator.pop(false);
                  },
                  child: Text(localizations.confirmCancel)),
              TextButton(
                  onPressed: () async {
                    navigator.pop(true);
                  },
                  child: Text(localizations.confirmYes))
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final module = context
        .read<KnownStationsModel>()
        .findModule(config.moduleIdentity)!
        .module;
    final localizations = AppLocalizations.of(context)!;
    final bay = localizations.bayNumber(module.position);

    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StepCounter()),
        ],
        child: Builder(builder: (context) {
          final stepCounter = Provider.of<StepCounter>(context);

          Loggers.ui.i("stepCounter: $stepCounter");

          if (!config.moreStandards) {
            // If there are no more standards, we're done calibrating and likely
            // waiting on the call to configure the module to finish, so until that happens
            // show a simple message.
            return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                      child: Text(
                    localizations.calibratingBusy,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ))
                ]);
          }

          return PopScope(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) async {
                if (didPop) {
                  return;
                }
                final NavigatorState navigator = Navigator.of(context);
                final bool? shouldPop = await _confirmBackDialog(context);
                if (shouldPop ?? false) {
                  navigator.popUntil((route) => route.isFirst);
                }
              },
              child: dismissKeyboardOnOutsideGap(Scaffold(
                  appBar: AppBar(
                      centerTitle: true,
                      title: Column(children: [
                        Text(localizations.calibrationPoint(stepCounter.steps)),
                        Text(
                          '$stationName - $bay',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.normal),
                        ),
                      ])),
                  body: ChangeNotifierProvider(
                      create: (context) => active,
                      child: StepsWidget(config: config, current: current)))));
        }));
  }
}

class StepsWidget extends StatefulWidget {
  final CalibrationConfig config;
  final CurrentCalibration current;

  const StepsWidget({super.key, required this.config, required this.current});

  @override
  State<StatefulWidget> createState() => _StepsState();
}

class _StepsState extends State<StepsWidget> {
  // This index is different than the StepCounter index. The StepCounter index
  // above is just the calibration point being calibrated. Ideally we could get the
  // number of points from CurrentCalibration but that isn't available, yet.
  int index = 0;

  @override
  Widget build(BuildContext context) {
    if (index >= 0 && index < widget.config.steps.length) {
      final module = context
          .read<KnownStationsModel>()
          .findModule(widget.config.moduleIdentity)!
          .module;

      final navigator = Navigator.of(context);

      final step = widget.config.steps[index];

      final key = UniqueKey();

      Loggers.ui.i("Calibration[$index] $key ${widget.config.done}");

      if (step is HelpStep) {
        return FlowNamedScreenWidget(
          name: step.screen,
          onForward: () {
            setState(() {
              index += 1;
            });
          },
        );
      }

      if (step is StandardStep) {
        return ProvideCountdown(
            duration: const Duration(seconds: 120),
            child:
                Consumer<CountdownTimer>(builder: (context, countdown, child) {
              if (widget.config.done) {
                return Container();
              }

              return CalibrationPanel(
                  key: key,
                  config: widget.config,
                  current: widget.current,
                  onDone: () {
                    if (widget.config.done) {
                      navigator.pushReplacement(MaterialPageRoute(
                          builder: (context) =>
                              CalibrationReviewPage(module: module)));
                      Loggers.ui.i("done!");
                    } else {
                      setState(() {
                        index += 1;
                      });
                    }
                  });
            }));
      }
    }

    return const OopsBug();
  }
}

class CalibrationPanel extends StatelessWidget {
  final CurrentCalibration current;
  final CalibrationConfig config;
  final VoidCallback onDone;

  const CalibrationPanel(
      {super.key,
      required this.current,
      required this.config,
      required this.onDone});

  Future<void> calibrateAndContinue(BuildContext context, SensorConfig sensor,
      CurrentCalibration current, ActiveCalibration active) async {
    final moduleConfigurations = context.read<ModuleConfigurations>();
    final standard = active.userStandard();
    final reading = SensorReading(
      uncalibrated: sensor.value!.uncalibrated,
      value: sensor.value!.value,
    );
    current.addPoint(CalibrationPoint(standard: standard, reading: reading));

    Loggers.cal.i("(calibrate) calibration: $current");
    Loggers.cal.i("(calibrate) active: $active");

    active.haveStandard(null);

    config.popStandard();
    if (config.done) {
      final overlay = context.loaderOverlay;
      final cal = current.toDataProtocol();
      final serialized = current.toBytes();

      Loggers.cal.i("(calibrate) $cal");

      overlay.show();
      try {
        await moduleConfigurations.calibrateModule(
            config.moduleIdentity, serialized);
      } catch (e) {
        Loggers.cal.e("Exception calibration: $e");
      } finally {
        overlay.hide();
      }
    }
    onDone();
  }

  CanContinue canContinue(SensorConfig sensor, Standard standard,
      ActiveCalibration active, CountdownTimer countdown) {
    if (!countdown.started) {
      return CanContinue.ready;
    }

    if (active.invalid) {
      return CanContinue.form;
    }

    if (countdown.done) {
      final time = sensor.value?.time;
      if (time == null) {
        return CanContinue.staleValue;
      } else {
        if (countdown.finishedBefore(
            DateTime.fromMillisecondsSinceEpoch(time.field0.toInt()))) {
          return CanContinue.yes;
        }
        return CanContinue.staleValue;
      }
    }

    return CanContinue.countdown;
  }

  @override
  Widget build(BuildContext context) {
    final knownStations = context.watch<KnownStationsModel>();
    final active = context.watch<ActiveCalibration>();
    final countdown = context.watch<CountdownTimer>();
    final mas = knownStations.findModule(config.moduleIdentity);
    final sensor = mas?.module.calibrationSensor;
    if (sensor == null || mas == null) {
      return const OopsBug();
    }

    return CalibrationWait(
      config: config,
      sensor: sensor,
      onStartTimer: () => countdown.start(DateTime.now()),
      canContinue: canContinue(sensor, config.standard, active, countdown),
      onCalibrateAndContinue: () =>
          calibrateAndContinue(context, sensor, current, active),
      onSkipTimer: () => countdown.skip(),
    );
  }
}

class CalibrationWait extends StatelessWidget {
  final CalibrationConfig config;
  final SensorConfig sensor;
  final VoidCallback onStartTimer;
  final VoidCallback onCalibrateAndContinue;
  final VoidCallback onSkipTimer;
  final CanContinue canContinue;

  const CalibrationWait({
    super.key,
    required this.config,
    required this.sensor,
    required this.onStartTimer,
    required this.onCalibrateAndContinue,
    required this.canContinue,
    required this.onSkipTimer,
  });

  Widget continueWidget(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final stepCounter = Provider.of<StepCounter>(context);

    switch (canContinue) {
      case CanContinue.ready:
        return OutlinedButton(
          onPressed: onStartTimer,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(80.0, 18.0, 80.0, 18.0),
            side: const BorderSide(color: Colors.lightBlue),
          ),
          child: Text(
            localizations.calibrationStartTimer,
            style: const TextStyle(color: Colors.lightBlue),
          ),
        );
      case CanContinue.yes:
        return OutlinedButton(
          onPressed: () {
            stepCounter.increment();
            onCalibrateAndContinue();
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(80.0, 18.0, 80.0, 18.0),
            side: const BorderSide(color: Colors.lightBlue),
          ),
          child: Text(
            localizations.calibrateButton,
            style: const TextStyle(color: Colors.lightBlue),
          ),
        );
      case CanContinue.form:
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(80.0, 18.0, 80.0, 18.0),
            side: const BorderSide(color: Colors.grey),
          ),
          child: Text(
            localizations.waitingOnForm,
            style: const TextStyle(color: Colors.grey),
          ),
        );
      case CanContinue.countdown:
        return GestureDetector(
          onLongPress: onSkipTimer,
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.fromLTRB(80.0, 18.0, 80.0, 18.0),
              side: const BorderSide(color: Colors.grey),
            ),
            child: Text(
              localizations.waitingOnTimer,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        );
      case CanContinue.staleValue:
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(80.0, 18.0, 80.0, 18.0),
            side: const BorderSide(color: Colors.grey),
          ),
          child: Text(
            localizations.waitingOnReading,
            style: const TextStyle(color: Colors.grey),
          ),
        );
      // ignore: unreachable_switch_default
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      Expanded(
        child: CurrentReadingAndStandard(
          canContinue: canContinue,
          sensor: sensor,
          standard: config.standard,
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.grey[200],
          child: Text(
            AppLocalizations.of(context)!.calibrationMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.all(30.0),
        child: continueWidget(context),
      ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

extension CalibrationSensors on ModuleConfig {
  SensorConfig? get calibrationSensor {
    if (key.startsWith("modules.water")) {
      return sensors.sorted((a, b) => a.number.compareTo(b.number)).first;
    }
    return null;
  }
}
