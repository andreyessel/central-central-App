import 'package:flutter/material.dart';
import 'package:central_central_new/notifications_page.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String studentName;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onLogoutPressed;

  const AppHeader({
    super.key,
    required this.title,
    required this.studentName,
    this.onMenuPressed,
    this.onNotificationPressed,
    this.onLogoutPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(100.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF732525),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFB8B292), width: 4.0),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed:
                  onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
            ),
            Row(
              children: [
                Image.asset(
                  'assets/images/central_central_logo.png',
                  height: 40,
                  width: 40,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed:
                      onNotificationPressed ??
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsPage(),
                          ),
                        );
                      },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: onLogoutPressed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
