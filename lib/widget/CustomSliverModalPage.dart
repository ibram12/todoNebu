// import 'package:flutter/material.dart';
// import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
//
// const double _pagePadding = 16.0;
// const double _buttonHeight = 50.0;
//
// class CustomSliverModalPage extends StatelessWidget {
//   final String pageTitleText;
//   final String firstButtonText;
//   final String secondButtonText;
//   final int firstButtonIndex;
//   final int secondButtonIndex;
//   final BuildContext modalSheetContext;
//
//   const CustomSliverModalPage({
//     Key? key,
//     required this.pageTitleText,
//     required this.firstButtonText,
//     required this.secondButtonText,
//     required this.firstButtonIndex,
//     required this.secondButtonIndex,
//     required this.modalSheetContext,
//   }) : super(key: key);
//
//   @override
//   WoltModalSheetPage build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;
//
//     return SliverWoltModalSheetPage(
//       pageTitle: Padding(
//         padding: const EdgeInsets.all(_pagePadding),
//         child: Text(
//           pageTitleText,
//           style:
//               textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
//         ),
//       ),
//       leadingNavBarWidget: IconButton(
//         padding: const EdgeInsets.all(_pagePadding),
//         icon: const Icon(Icons.arrow_back_rounded),
//         onPressed: WoltModalSheet.of(modalSheetContext).showPrevious,
//       ),
//       trailingNavBarWidget: IconButton(
//         padding: const EdgeInsets.all(_pagePadding),
//         icon: const Icon(Icons.close),
//         onPressed: () => Navigator.of(modalSheetContext).pop(),
//       ),
//       stickyActionBar: Padding(
//         padding: const EdgeInsets.all(_pagePadding),
//         child: ElevatedButton(
//           onPressed: () => Navigator.of(modalSheetContext).pop(),
//           child: const SizedBox(
//             height: _buttonHeight,
//             width: double.infinity,
//             child: Center(child: Text('Close')),
//           ),
//         ),
//       ),
//       mainContentSliversBuilder: (context) => [
//         _buildButton(firstButtonText, firstButtonIndex),
//         _buildButton(secondButtonText, secondButtonIndex, bottomPadding: 80),
//       ],
//     );
//   }
//
//   Widget _buildButton(String text, int targetIndex,
//       {double bottomPadding = 0}) {
//     return SliverPadding(
//       padding: EdgeInsets.only(bottom: bottomPadding),
//       sliver: SliverToBoxAdapter(
//         child: Padding(
//           padding: const EdgeInsets.all(_pagePadding),
//           child: InkWell(
//             onTap: () =>
//                 WoltModalSheet.of(modalSheetContext).showAtIndex(targetIndex),
//             child: Card(
//               child: SizedBox(
//                 height: 50,
//                 child: Center(child: Text(text)),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
