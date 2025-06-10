import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? actionButton; // NEW: Optional action button

  const UserCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.icon,
    this.onTap,
    this.actionButton, // NEW: Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                Text(
                  trailing!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
              // NEW: Display the action button if provided
              if (actionButton != null) ...[
                const SizedBox(width: 8),
                actionButton!,
              ],
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
