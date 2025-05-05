import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final Function() onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom Google G logo
                Container(
                  height: 24.0,
                  width: 24.0,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                    size: const Size(24.0, 24.0),
                    painter: GoogleLogoPainter(),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Calculate relative positions
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    // Draw the white background
    paint.color = Colors.white;
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);

    // Draw the colored sections of the G
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Blue part (top-right)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(centerX, centerY)
      ..lineTo(size.width - 4, 4)
      ..lineTo(size.width - 4, size.height * 0.65)
      ..arcTo(
        Rect.fromLTWH(
            centerX - radius * 0.5, centerY - radius * 0.5, radius, radius),
        0,
        -1.5,
        false,
      )
      ..close();
    canvas.drawPath(bluePath, paint);

    // Red part (left)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(centerX, centerY)
      ..lineTo(4, size.height * 0.25)
      ..lineTo(4, size.height * 0.75)
      ..arcTo(
        Rect.fromLTWH(
            centerX - radius * 0.5, centerY - radius * 0.5, radius, radius),
        -2.5,
        -1.5,
        false,
      )
      ..close();
    canvas.drawPath(redPath, paint);

    // Yellow part (bottom)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(centerX, centerY)
      ..lineTo(4, size.height * 0.75)
      ..lineTo(size.width * 0.35, size.height - 4)
      ..arcTo(
        Rect.fromLTWH(
            centerX - radius * 0.5, centerY - radius * 0.5, radius, radius),
        1.0,
        -1.5,
        false,
      )
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green part (right)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(centerX, centerY)
      ..lineTo(size.width * 0.35, size.height - 4)
      ..lineTo(size.width - 4, size.height * 0.65)
      ..arcTo(
        Rect.fromLTWH(
            centerX - radius * 0.5, centerY - radius * 0.5, radius, radius),
        0.5,
        -1.0,
        false,
      )
      ..close();
    canvas.drawPath(greenPath, paint);

    // White center
    paint.color = Colors.white;
    canvas.drawCircle(Offset(centerX, centerY), radius * 0.5, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
