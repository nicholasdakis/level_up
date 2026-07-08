import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../globals.dart';
import '../../providers/user_data_provider.dart';
import '../../providers/weight_logs_provider.dart';
import '../../services/user_data_manager.dart' show defaultAppColor;
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';

Future<void> showWeightLogSheet(BuildContext context, Color appColor) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => _WeightLogSheet(appColor: appColor),
  );
}

class _WeightLogSheet extends ConsumerStatefulWidget {
  final Color appColor;
  const _WeightLogSheet({required this.appColor});

  @override
  ConsumerState<_WeightLogSheet> createState() => _WeightLogSheetState();
}

class _WeightLogSheetState extends ConsumerState<_WeightLogSheet> {
  bool get isImperial =>
      ref.watch(userDataProvider.select((s) => s.value?.units == 'imperial'));
  DateTime selectedDate = DateTime.now();
  final controller = TextEditingController();
  String? feedback;
  String lastFeedback = 'ok';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String dateKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String displayFor(double kg) => isImperial
      ? UnitConverter.displayWeight(kg, imperial: isImperial)
      : kg.toStringAsFixed(1);

  String labelFor(DateTime d) {
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return "Today";
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return "Yesterday";
    }
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  List<MapEntry<String, double>> recentEntries() {
    final entries = ref.read(weightLogsProvider).value?.entries.toList() ?? [];
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries.take(7).toList();
  }

  String get weightHint {
    final entries = ref.read(weightLogsProvider).value?.entries.toList() ?? [];
    entries.sort((a, b) => b.key.compareTo(a.key));
    final byDate = ref.read(weightLogsProvider).value;
    double? latest;
    if (entries.isNotEmpty && byDate != null) {
      latest = byDate[entries.first.key];
    }
    if (latest != null) {
      final hintKg = latest + (Random().nextDouble() * 4 - 2);
      return isImperial
          ? "e.g. ${UnitConverter.displayWeight(hintKg, imperial: isImperial)}"
          : "e.g. ${hintKg.toStringAsFixed(1)}";
    }
    return isImperial ? "e.g. 154.0" : "e.g. 70.0";
  }

  Future<void> _save(String dateKey, double? existingKg) async {
    final input = double.tryParse(controller.text.trim());
    if (input == null || input <= 0) return;
    final kg = isImperial ? UnitConverter.lbsToKg(input) : input;
    final ok = await ref
        .read(weightLogsProvider.notifier)
        .updateWeightLog(dateKey, kg);
    if (!mounted) return;
    setState(() {
      feedback = ok ? (existingKg != null ? 'updated' : 'ok') : 'error';
      lastFeedback = feedback!;
    });
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => feedback = null);
  }

  Future<void> _delete(String entryKey) async {
    final entryDisplay = displayFor(
      ref.read(weightLogsProvider).value?[entryKey] ?? 0,
    );
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      appColor: widget.appColor,
      title: "Delete Entry",
      content: Text(
        "Delete $entryDisplay ${UnitConverter.weightUnit(imperial: isImperial)} from ${labelFor(DateTime.parse(entryKey))}?",
        style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text("Cancel", style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text("Delete", style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(weightLogsProvider.notifier)
        .deleteWeightLog(entryKey);
    if (!mounted) return;
    setState(() {
      feedback = ok ? 'deleted' : 'error';
      lastFeedback = feedback!;
    });
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => feedback = null);
  }

  @override
  Widget build(BuildContext context) {
    final appColor = ref.watch(
      userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
    );
    final dateKey = dateKeyFor(selectedDate);
    final existingKg = ref.watch(weightLogsProvider).value?[dateKey];
    final c = cardColors(appColor);
    final onCard = c.onCard;
    final onCardDim = c.onCard.withAlpha(140);
    final recent = recentEntries();

    return SizedBox(
      height:
          MediaQuery.of(context).size.height * 0.55 +
          MediaQuery.of(context).viewInsets.bottom,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: darkenColor(appColor, 0.05).withAlpha(220),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: c.border, width: 1)),
              ),
              padding: EdgeInsets.fromLTRB(
                Responsive.width(context, 24),
                Responsive.height(context, 20),
                Responsive.width(context, 24),
                Responsive.height(context, 32),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "LOG WEIGHT",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 11),
                          color: onCardDim,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 12)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final d = selectedDate.subtract(
                                const Duration(days: 1),
                              );
                              final kg = ref
                                  .read(weightLogsProvider)
                                  .value?[dateKeyFor(d)];
                              setState(() {
                                selectedDate = d;
                                controller.text = kg != null
                                    ? displayFor(kg)
                                    : '';
                              });
                            },
                            child: Icon(
                              Icons.chevron_left,
                              color: onCard,
                              size: Responsive.scale(context, 22),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showThemedDatePicker(
                                appColor: appColor,
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                final kg = ref
                                    .read(weightLogsProvider)
                                    .value?[dateKeyFor(picked)];
                                setState(() {
                                  selectedDate = picked;
                                  controller.text = kg != null
                                      ? displayFor(kg)
                                      : '';
                                });
                              }
                            },
                            child: Text(
                              labelFor(selectedDate),
                              style: GoogleFonts.manrope(
                                color: onCard,
                                fontSize: Responsive.font(context, 14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap:
                                selectedDate.day == DateTime.now().day &&
                                    selectedDate.month ==
                                        DateTime.now().month &&
                                    selectedDate.year == DateTime.now().year
                                ? null
                                : () {
                                    final d = selectedDate.add(
                                      const Duration(days: 1),
                                    );
                                    final kg = ref
                                        .read(weightLogsProvider)
                                        .value?[dateKeyFor(d)];
                                    setState(() {
                                      selectedDate = d;
                                      controller.text = kg != null
                                          ? displayFor(kg)
                                          : '';
                                    });
                                  },
                            child: Icon(
                              Icons.chevron_right,
                              color: selectedDate.day == DateTime.now().day
                                  ? onCard.withAlpha(60)
                                  : onCard,
                              size: Responsive.scale(context, 22),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.height(context, 16)),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d{0,3}(\.\d{0,1})?'),
                                ),
                              ],
                              autofocus: false,
                              style: GoogleFonts.manrope(
                                color: onCard,
                                fontSize: Responsive.font(context, 22),
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: weightHint,
                                hintStyle: GoogleFonts.manrope(
                                  color: onCardDim,
                                ),
                                suffix: Text(
                                  " ${UnitConverter.weightUnit(imperial: isImperial)}",
                                  style: GoogleFonts.manrope(
                                    color: onCardDim,
                                    fontSize: Responsive.font(context, 16),
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: onCard.withAlpha(60),
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: onCard),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 16)),
                          GestureDetector(
                            onTap: () => _save(dateKey, existingKg),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 20),
                                vertical: Responsive.height(context, 12),
                              ),
                              decoration: BoxDecoration(
                                color: onCard.withAlpha(20),
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 12),
                                ),
                                border: Border.all(color: onCard.withAlpha(60)),
                              ),
                              child: Text(
                                existingKg != null ? "Update" : "Log",
                                style: GoogleFonts.manrope(
                                  color: onCard,
                                  fontSize: Responsive.font(context, 14),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (recent.isNotEmpty) ...[
                        SizedBox(height: Responsive.height(context, 20)),
                        Text(
                          "RECENT",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: onCardDim,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 8)),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.25,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (int i = 0; i < recent.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      color: onCard.withAlpha(20),
                                      height: 1,
                                    ),
                                  GestureDetector(
                                    onTap: () {
                                      final d = DateTime.parse(recent[i].key);
                                      setState(() {
                                        selectedDate = d;
                                        controller.text = displayFor(
                                          recent[i].value,
                                        );
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: Responsive.height(
                                          context,
                                          10,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedWeightScale,
                                            color: onCardDim,
                                            size: Responsive.scale(context, 15),
                                          ),
                                          SizedBox(
                                            width: Responsive.width(
                                              context,
                                              10,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              labelFor(
                                                DateTime.parse(recent[i].key),
                                              ),
                                              style: GoogleFonts.manrope(
                                                color: onCardDim,
                                                fontSize: Responsive.font(
                                                  context,
                                                  13,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "${displayFor(recent[i].value)} ${UnitConverter.weightUnit(imperial: isImperial)}",
                                            style: GoogleFonts.manrope(
                                              color: onCard,
                                              fontSize: Responsive.font(
                                                context,
                                                14,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(
                                            width: Responsive.width(context, 6),
                                          ),
                                          Builder(
                                            builder: (_) {
                                              if (i + 1 >= recent.length) {
                                                return SizedBox(
                                                  width: Responsive.scale(
                                                    context,
                                                    16,
                                                  ),
                                                );
                                              }
                                              final diff =
                                                  recent[i].value -
                                                  recent[i + 1].value;
                                              if (diff.abs() < 0.01) {
                                                return HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedRemove01,
                                                  color: onCardDim,
                                                  size: Responsive.scale(
                                                    context,
                                                    14,
                                                  ),
                                                );
                                              }
                                              return HugeIcon(
                                                icon: diff > 0
                                                    ? HugeIcons
                                                          .strokeRoundedChartUp
                                                    : HugeIcons
                                                          .strokeRoundedChartDown,
                                                color: onCardDim,
                                                size: Responsive.scale(
                                                  context,
                                                  14,
                                                ),
                                              );
                                            },
                                          ),
                                          SizedBox(
                                            width: Responsive.width(context, 8),
                                          ),
                                          GestureDetector(
                                            onTap: () => _delete(recent[i].key),
                                            child: HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedDelete02,
                                              color: onCardDim,
                                              size: Responsive.scale(
                                                context,
                                                16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: feedback != null ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 10),
                            vertical: Responsive.height(context, 5),
                          ),
                          decoration: BoxDecoration(
                            color: onCard.withAlpha(40),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 20),
                            ),
                            border: Border.all(color: onCard.withAlpha(60)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                feedback == 'error'
                                    ? Icons.wifi_off
                                    : Icons.check,
                                color: onCard,
                                size: Responsive.scale(context, 13),
                              ),
                              SizedBox(width: Responsive.width(context, 5)),
                              Text(
                                lastFeedback == 'error'
                                    ? "No connection"
                                    : lastFeedback == 'updated'
                                    ? "Updated!"
                                    : lastFeedback == 'deleted'
                                    ? "Deleted!"
                                    : "Logged!",
                                style: GoogleFonts.manrope(
                                  color: onCard,
                                  fontSize: Responsive.font(context, 12),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
