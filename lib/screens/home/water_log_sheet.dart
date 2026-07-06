import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';

Future<void> showWaterLogSheet(BuildContext context, Color appColor) async {
  final isImperial = UnitConverter.isImperial;
  DateTime selectedDate = DateTime.now();
  final customController = TextEditingController();

  String? feedback;
  // keeps the pill text visible while it fades out, otherwise it blanks before the animation finishes
  String lastFeedback = 'ok';

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

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final dateKey = dateKeyFor(selectedDate);
        final entries = List<int>.from(
          currentUserData?.waterEntriesByDate[dateKey] ?? [],
        );

        final c = cardColors(appColor);
        final onCard = c.onCard;
        final onCardDim = c.onCard.withAlpha(140);
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
                    color: darkenColor(appColor, 0.05).withAlpha(220),
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
                            "LOG WATER",
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
                                onTap: () => setSheet(() {
                                  selectedDate = selectedDate.subtract(
                                    const Duration(days: 1),
                                  );
                                  customController.clear();
                                }),
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
                                    setSheet(() {
                                      selectedDate = picked;
                                      customController.clear();
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
                              // null disables the tap, which grays out the arrow on today
                              GestureDetector(
                                onTap:
                                    selectedDate.day == DateTime.now().day &&
                                        selectedDate.month ==
                                            DateTime.now().month &&
                                        selectedDate.year == DateTime.now().year
                                    ? null
                                    : () => setSheet(() {
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
                                  size: Responsive.scale(ctx, 22),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.height(ctx, 16)),
                          Row(
                            children: [
                              for (final amount
                                  in isImperial ? [8, 12, 16] : [250, 500, 750])
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: amount != (isImperial ? 16 : 750)
                                          ? Responsive.width(ctx, 8)
                                          : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () async {
                                        // everything is stored as ml so oz gets converted before it goes in
                                        final ml = isImperial
                                            ? UnitConverter.ozToMl(
                                                amount.toDouble(),
                                              ).round()
                                            : amount;
                                        entries.add(ml);
                                        await userManager.updateWaterLog(
                                          dateKey,
                                          entries,
                                        );
                                        // setSheet throws if the user closed the sheet before this finished
                                        try {
                                          setSheet(() {
                                            feedback = 'ok';
                                            lastFeedback = 'ok';
                                          });
                                        } catch (_) {
                                          return;
                                        }
                                        await Future.delayed(
                                          const Duration(milliseconds: 1600),
                                        );
                                        // setting feedback to null starts the fade-out
                                        try {
                                          setSheet(() => feedback = null);
                                        } catch (_) {}
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: Responsive.height(ctx, 12),
                                        ),
                                        decoration: BoxDecoration(
                                          color: onCard.withAlpha(15),
                                          borderRadius: BorderRadius.circular(
                                            Responsive.scale(ctx, 12),
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
                                            fontSize: Responsive.font(ctx, 14),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: Responsive.height(ctx, 16)),
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
                              SizedBox(width: Responsive.width(ctx, 16)),
                              GestureDetector(
                                onTap: () async {
                                  // oz can be fractional so imperial parses as double, metric is always whole ml
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
                                    entries.add(val);
                                    await userManager.updateWaterLog(
                                      dateKey,
                                      entries,
                                    );
                                    try {
                                      setSheet(() {
                                        feedback = 'ok';
                                        lastFeedback = 'ok';
                                        customController.clear();
                                      });
                                    } catch (_) {
                                      return;
                                    }
                                    await Future.delayed(
                                      const Duration(milliseconds: 1600),
                                    );
                                    try {
                                      setSheet(() => feedback = null);
                                    } catch (_) {}
                                  }
                                },
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
                                    "Log",
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
                          SizedBox(height: Responsive.height(ctx, 20)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "ENTRIES",
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(ctx, 11),
                                  color: onCardDim,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              if (entries.isNotEmpty)
                                Text(
                                  isImperial
                                      ? "${UnitConverter.displayWater(entries.fold(0, (s, e) => s + e), imperial: isImperial)} oz total"
                                      : "${entries.fold(0, (s, e) => s + e)} ml total",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(ctx, 12),
                                    color: onCard,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: Responsive.height(ctx, 8)),
                          if (entries.isEmpty)
                            Text(
                              "No entries today",
                              style: GoogleFonts.manrope(
                                color: onCardDim,
                                fontSize: Responsive.font(ctx, 13),
                              ),
                            )
                          else
                            // cap the list height so it doesn't push everything else off screen
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(ctx).size.height * 0.28,
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    // Reversed so newest entry appears at top
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
                                          vertical: Responsive.height(ctx, 10),
                                        ),
                                        child: Row(
                                          children: [
                                            HugeIcon(
                                              icon: HugeIcons
                                                  .strokeRoundedDroplet,
                                              color: onCardDim,
                                              size: Responsive.scale(ctx, 15),
                                            ),
                                            SizedBox(
                                              width: Responsive.width(ctx, 10),
                                            ),
                                            Expanded(
                                              child: Text(
                                                isImperial
                                                    ? "${UnitConverter.displayWater(entries[i], imperial: isImperial)} oz"
                                                    : "${entries[i]} ml",
                                                style: GoogleFonts.manrope(
                                                  color: onCard,
                                                  fontSize: Responsive.font(
                                                    ctx,
                                                    14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () async {
                                                final confirmed =
                                                    await showFrostedAlertDialog<
                                                      bool
                                                    >(
                                                      context: ctx,
                                                      title: "Remove Entry",
                                                      content: Text(
                                                        isImperial
                                                            ? "Remove ${UnitConverter.displayWater(entries[i], imperial: isImperial)} oz from ${labelFor(selectedDate).toLowerCase()}?"
                                                            : "Remove ${entries[i]} ml from ${labelFor(selectedDate).toLowerCase()}?",
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
                                                            "Remove",
                                                            style:
                                                                dialogButtonStyle(
                                                                  confirm: true,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                if (confirmed == true) {
                                                  entries.removeAt(i);
                                                  await userManager
                                                      .updateWaterLog(
                                                        dateKey,
                                                        entries,
                                                      );
                                                  try {
                                                    setSheet(() {
                                                      feedback = 'deleted';
                                                      lastFeedback = 'deleted';
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
                                                size: Responsive.scale(ctx, 18),
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
                      // Pill anchored top-right, always in the tree so AnimatedOpacity/AnimatedSlide
                      // can transition smoothly. Visibility driven by opacity, not conditional render
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
                                    feedback == 'error'
                                        ? Icons.wifi_off
                                        : Icons.check,
                                    color: onCard,
                                    size: Responsive.scale(ctx, 13),
                                  ),
                                  SizedBox(width: Responsive.width(ctx, 5)),
                                  Text(
                                    lastFeedback == 'error'
                                        ? "No connection"
                                        : lastFeedback == 'deleted'
                                        ? "Removed"
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
                      ),
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
