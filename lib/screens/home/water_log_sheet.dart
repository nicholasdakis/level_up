import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../globals.dart';
import '../../providers/user_data_provider.dart';
import '../../providers/water_logs_provider.dart';
import '../../services/user_data_manager.dart' show defaultAppColor;
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';

Future<void> showWaterLogSheet(BuildContext context, Color appColor) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => _WaterLogSheet(appColor: appColor),
  );
}

class _WaterLogSheet extends ConsumerStatefulWidget {
  final Color appColor;
  const _WaterLogSheet({required this.appColor});

  @override
  ConsumerState<_WaterLogSheet> createState() => _WaterLogSheetState();
}

class _WaterLogSheetState extends ConsumerState<_WaterLogSheet> {
  bool get isImperial =>
      ref.watch(userDataProvider.select((s) => s.value?.units == 'imperial'));
  DateTime selectedDate = DateTime.now();
  final customController = TextEditingController();
  String? feedback;
  // keeps the pill text visible while it fades out, otherwise it blanks before the animation finishes
  String lastFeedback = 'ok';

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  String dateKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  Future<void> _log(int ml) async {
    logAnalyticsEvent('log_water', parameters: {'ml': ml});
    final dateKey = dateKeyFor(selectedDate);
    final entries = List<int>.from(
      ref.read(waterLogsProvider).value?[dateKey] ?? [],
    );
    entries.add(ml);
    await ref.read(waterLogsProvider.notifier).updateWaterLog(dateKey, entries);
    if (!mounted) return;
    setState(() {
      feedback = 'ok';
      lastFeedback = 'ok';
    });
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => feedback = null);
  }

  Future<void> _remove(int index) async {
    final dateKey = dateKeyFor(selectedDate);
    final entries = List<int>.from(
      ref.read(waterLogsProvider).value?[dateKey] ?? [],
    );
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      appColor: widget.appColor,
      title: "Remove Entry",
      content: Text(
        isImperial
            ? "Remove ${UnitConverter.displayWater(entries[index], imperial: isImperial)} oz from ${labelFor(selectedDate).toLowerCase()}?"
            : "Remove ${entries[index]} ml from ${labelFor(selectedDate).toLowerCase()}?",
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
          child: Text("Remove", style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    entries.removeAt(index);
    await ref.read(waterLogsProvider.notifier).updateWaterLog(dateKey, entries);
    if (!mounted) return;
    setState(() {
      feedback = 'deleted';
      lastFeedback = 'deleted';
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
    final entries = List<int>.from(
      ref.watch(waterLogsProvider).value?[dateKey] ?? [],
    );
    final c = cardColors(appColor);
    final onCard = c.onCard;
    final onCardDim = c.onCard.withAlpha(140);

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
                        "LOG WATER",
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
                            onTap: () => setState(() {
                              selectedDate = selectedDate.subtract(
                                const Duration(days: 1),
                              );
                              customController.clear();
                            }),
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
                                setState(() {
                                  selectedDate = picked;
                                  customController.clear();
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
                                : () => setState(() {
                                    selectedDate = selectedDate.add(
                                      const Duration(days: 1),
                                    );
                                    customController.clear();
                                  }),
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
                          for (final amount
                              in isImperial ? [8, 12, 16] : [250, 500, 750])
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: amount != (isImperial ? 16 : 750)
                                      ? Responsive.width(context, 8)
                                      : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () async {
                                    final ml = isImperial
                                        ? UnitConverter.ozToMl(
                                            amount.toDouble(),
                                          ).round()
                                        : amount;
                                    await _log(ml);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: Responsive.height(context, 12),
                                    ),
                                    decoration: BoxDecoration(
                                      color: onCard.withAlpha(15),
                                      borderRadius: BorderRadius.circular(
                                        Responsive.scale(context, 12),
                                      ),
                                      border: Border.all(
                                        color: onCard.withAlpha(40),
                                      ),
                                    ),
                                    child: Text(
                                      isImperial
                                          ? "+${amount}oz"
                                          : "+${amount}ml",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: onCard,
                                        fontSize: Responsive.font(context, 14),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: Responsive.height(context, 16)),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              style: GoogleFonts.manrope(color: onCard),
                              decoration: InputDecoration(
                                hintText: isImperial
                                    ? "Custom amount (oz)"
                                    : "Custom amount (ml)",
                                hintStyle: GoogleFonts.manrope(
                                  color: onCardDim,
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
                            onTap: () async {
                              final val = isImperial
                                  ? UnitConverter.ozToMl(
                                      double.tryParse(
                                            customController.text.trim(),
                                          ) ??
                                          0,
                                    ).round()
                                  : int.tryParse(
                                          customController.text.trim(),
                                        ) ??
                                        0;
                              if (val > 0) {
                                customController.clear();
                                await _log(val);
                              }
                            },
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
                                "Log",
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
                      SizedBox(height: Responsive.height(context, 20)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ENTRIES",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: onCardDim,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          if (entries.isNotEmpty)
                            Text(
                              isImperial
                                  ? "${UnitConverter.displayWater(entries.fold(0, (total, entryMl) => total + entryMl), imperial: isImperial)} oz total"
                                  : "${entries.fold(0, (total, entryMl) => total + entryMl)} ml total",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 12),
                                color: onCard,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: Responsive.height(context, 8)),
                      if (entries.isEmpty)
                        Text(
                          "No entries today",
                          style: GoogleFonts.manrope(
                            color: onCardDim,
                            fontSize: Responsive.font(context, 13),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.28,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (
                                  int i = entries.length - 1;
                                  i >= 0;
                                  i--
                                ) ...[
                                  if (i < entries.length - 1)
                                    Divider(
                                      color: onCard.withAlpha(20),
                                      height: 1,
                                    ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: Responsive.height(context, 10),
                                    ),
                                    child: Row(
                                      children: [
                                        HugeIcon(
                                          icon: HugeIcons.strokeRoundedDroplet,
                                          color: onCardDim,
                                          size: Responsive.scale(context, 15),
                                        ),
                                        SizedBox(
                                          width: Responsive.width(context, 10),
                                        ),
                                        Expanded(
                                          child: Text(
                                            isImperial
                                                ? "${UnitConverter.displayWater(entries[i], imperial: isImperial)} oz"
                                                : "${entries[i]} ml",
                                            style: GoogleFonts.manrope(
                                              color: onCard,
                                              fontSize: Responsive.font(
                                                context,
                                                14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _remove(i),
                                          child: HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedDelete02,
                                            color: onCardDim,
                                            size: Responsive.scale(context, 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
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
                                    : lastFeedback == 'deleted'
                                    ? "Removed"
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
