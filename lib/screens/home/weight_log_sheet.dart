import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';

Future<void> showWeightLogSheet(BuildContext context) async {
  final isImperial = UnitConverter.isImperial;
  DateTime selectedDate = DateTime.now();
  final controller = TextEditingController();
  String? feedback;
  String lastFeedback = 'ok';

  // Use latest logged weight as hint base, offset randomly by -2 to +2
  final weightHint = () {
    final entries = currentUserData?.weightByDate.entries.toList() ?? [];
    entries.sort((a, b) => b.key.compareTo(a.key));
    final latest = entries.isNotEmpty
        ? (currentUserData!.weightByDate[entries.first.key])
        : null;
    if (latest != null) {
      final hintKg = latest + (Random().nextDouble() * 4 - 2);
      return isImperial
          ? "e.g. ${UnitConverter.displayWeight(hintKg, imperial: isImperial)}"
          : "e.g. ${hintKg.toStringAsFixed(1)}";
    }
    return isImperial ? "e.g. 154.0" : "e.g. 70.0";
  }();

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

  // Get last 7 days that have weight logged, sorted newest first
  List<MapEntry<String, double>> recentEntries() {
    final entries = currentUserData?.weightByDate.entries.toList() ?? [];
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries.take(7).toList();
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final c = cardColors(appColorNotifier.value);
        final onCard = c.onCard;
        final onCardDim = c.onCard.withAlpha(140);
        final dateKey = dateKeyFor(selectedDate);
        final existingKg = currentUserData?.weightByDate[dateKey];

        // Pre-fill on first build
        if (controller.text.isEmpty && existingKg != null) {
          controller.text = displayFor(existingKg);
        }

        Future<void> save() async {
          final input = double.tryParse(controller.text.trim());
          if (input == null || input <= 0) return;
          final kg = isImperial ? UnitConverter.lbsToKg(input) : input;
          final ok = await userManager.updateWeightLog(dateKey, kg);
          try {
            setSheet(() {
              feedback = ok ? (existingKg != null ? 'updated' : 'ok') : 'error';
              lastFeedback = feedback!;
            });
          } catch (_) {
            return;
          }
          await Future.delayed(const Duration(milliseconds: 1600));
          try {
            setSheet(() => feedback = null);
          } catch (_) {}
        }

        Widget pill() => Positioned(
          top: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: feedback != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(ctx, 10),
                  vertical: Responsive.height(ctx, 5),
                ),
                decoration: BoxDecoration(
                  color: onCard.withAlpha(40),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 20),
                  ),
                  border: Border.all(color: onCard.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      feedback == 'error' ? Icons.wifi_off : Icons.check,
                      color: onCard,
                      size: Responsive.scale(ctx, 13),
                    ),
                    SizedBox(width: Responsive.width(ctx, 5)),
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
                        fontSize: Responsive.font(ctx, 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // keyboard pushes up the sheet so we grow the height to match, then pad the bottom by the same amount
        return SizedBox(
          height:
              MediaQuery.of(ctx).size.height * 0.55 +
              MediaQuery.of(ctx).viewInsets.bottom,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: darkenColor(
                      appColorNotifier.value,
                      0.05,
                    ).withAlpha(220),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(top: BorderSide(color: c.border, width: 1)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    Responsive.width(ctx, 24),
                    Responsive.height(ctx, 20),
                    Responsive.width(ctx, 24),
                    Responsive.height(ctx, 32),
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
                              fontSize: Responsive.font(ctx, 11),
                              color: onCardDim,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: Responsive.height(ctx, 12)),
                          // Date navigation row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final d = selectedDate.subtract(
                                    const Duration(days: 1),
                                  );
                                  final kg = currentUserData
                                      ?.weightByDate[dateKeyFor(d)];
                                  setSheet(() {
                                    selectedDate = d;
                                    controller.text = kg != null
                                        ? displayFor(kg)
                                        : '';
                                  });
                                },
                                child: Icon(
                                  Icons.chevron_left,
                                  color: onCard,
                                  size: Responsive.scale(ctx, 22),
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showThemedDatePicker(
                                    context: ctx,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    final kg = currentUserData
                                        ?.weightByDate[dateKeyFor(picked)];
                                    setSheet(() {
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
                                    fontSize: Responsive.font(ctx, 14),
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
                                        final kg = currentUserData
                                            ?.weightByDate[dateKeyFor(d)];
                                        setSheet(() {
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
                                  size: Responsive.scale(ctx, 22),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.height(ctx, 16)),
                          // Input row
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
                                    fontSize: Responsive.font(ctx, 22),
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
                                        fontSize: Responsive.font(ctx, 16),
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
                              SizedBox(width: Responsive.width(ctx, 16)),
                              GestureDetector(
                                onTap: save,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(ctx, 20),
                                    vertical: Responsive.height(ctx, 12),
                                  ),
                                  decoration: BoxDecoration(
                                    color: onCard.withAlpha(20),
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(ctx, 12),
                                    ),
                                    border: Border.all(
                                      color: onCard.withAlpha(60),
                                    ),
                                  ),
                                  child: Text(
                                    existingKg != null ? "Update" : "Log",
                                    style: GoogleFonts.manrope(
                                      color: onCard,
                                      fontSize: Responsive.font(ctx, 14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Recent 7-day history
                          if (recentEntries().isNotEmpty) ...[
                            SizedBox(height: Responsive.height(ctx, 20)),
                            Text(
                              "RECENT",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(ctx, 11),
                                color: onCardDim,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: Responsive.height(ctx, 8)),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(ctx).size.height * 0.25,
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    for (
                                      int i = 0;
                                      i < recentEntries().length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        Divider(
                                          color: onCard.withAlpha(20),
                                          height: 1,
                                        ),
                                      GestureDetector(
                                        // Tap a history row to jump to that date and prefill the input
                                        onTap: () {
                                          final d = DateTime.parse(
                                            recentEntries()[i].key,
                                          );
                                          final kg = recentEntries()[i].value;
                                          setSheet(() {
                                            selectedDate = d;
                                            controller.text = displayFor(kg);
                                          });
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: Responsive.height(
                                              ctx,
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              HugeIcon(
                                                icon: HugeIcons
                                                    .strokeRoundedWeightScale,
                                                color: onCardDim,
                                                size: Responsive.scale(ctx, 15),
                                              ),
                                              SizedBox(
                                                width: Responsive.width(
                                                  ctx,
                                                  10,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  labelFor(
                                                    DateTime.parse(
                                                      recentEntries()[i].key,
                                                    ),
                                                  ),
                                                  style: GoogleFonts.manrope(
                                                    color: onCardDim,
                                                    fontSize: Responsive.font(
                                                      ctx,
                                                      13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                "${displayFor(recentEntries()[i].value)} ${UnitConverter.weightUnit(imperial: isImperial)}",
                                                style: GoogleFonts.manrope(
                                                  color: onCard,
                                                  fontSize: Responsive.font(
                                                    ctx,
                                                    14,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(
                                                width: Responsive.width(ctx, 6),
                                              ),
                                              // Trend arrow comparing to the previous (older) entry
                                              Builder(
                                                builder: (_) {
                                                  final entries =
                                                      recentEntries();
                                                  if (i + 1 >= entries.length) {
                                                    return SizedBox(
                                                      width: Responsive.scale(
                                                        ctx,
                                                        16,
                                                      ),
                                                    );
                                                  }
                                                  final diff =
                                                      entries[i].value -
                                                      entries[i + 1].value;
                                                  if (diff.abs() < 0.01) {
                                                    return HugeIcon(
                                                      icon: HugeIcons
                                                          .strokeRoundedRemove01,
                                                      color: onCardDim,
                                                      size: Responsive.scale(
                                                        ctx,
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
                                                      ctx,
                                                      14,
                                                    ),
                                                  );
                                                },
                                              ),
                                              SizedBox(
                                                width: Responsive.width(ctx, 8),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  final entryKey =
                                                      recentEntries()[i].key;
                                                  final entryDisplay =
                                                      displayFor(
                                                        recentEntries()[i]
                                                            .value,
                                                      );
                                                  final confirmed =
                                                      await showFrostedAlertDialog<
                                                        bool
                                                      >(
                                                        context: ctx,
                                                        title: "Delete Entry",
                                                        content: Text(
                                                          "Delete $entryDisplay ${UnitConverter.weightUnit(imperial: isImperial)} from ${labelFor(DateTime.parse(entryKey))}?",
                                                          style:
                                                              GoogleFonts.manrope(
                                                                color: Colors
                                                                    .white54,
                                                                fontSize: 13,
                                                              ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  ctx,
                                                                  rootNavigator:
                                                                      true,
                                                                ).pop(false),
                                                            child: Text(
                                                              "Cancel",
                                                              style:
                                                                  dialogButtonStyle(),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  ctx,
                                                                  rootNavigator:
                                                                      true,
                                                                ).pop(true),
                                                            child: Text(
                                                              "Delete",
                                                              style:
                                                                  dialogButtonStyle(
                                                                    confirm:
                                                                        true,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                  if (confirmed == true) {
                                                    final ok = await userManager
                                                        .deleteWeightLog(
                                                          entryKey,
                                                        );
                                                    try {
                                                      setSheet(() {
                                                        feedback = ok
                                                            ? 'deleted'
                                                            : 'error';
                                                        lastFeedback =
                                                            feedback!;
                                                      });
                                                    } catch (_) {
                                                      return;
                                                    }
                                                    await Future.delayed(
                                                      const Duration(
                                                        milliseconds: 1600,
                                                      ),
                                                    );
                                                    try {
                                                      setSheet(
                                                        () => feedback = null,
                                                      );
                                                    } catch (_) {}
                                                  }
                                                },
                                                child: HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: onCardDim,
                                                  size: Responsive.scale(
                                                    ctx,
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
                      pill(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
