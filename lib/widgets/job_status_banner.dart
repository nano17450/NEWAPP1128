import 'package:flutter/material.dart';

class JobStatusBanner extends StatelessWidget {
  final bool isAdmin;

  const JobStatusBanner({Key? key, this.isAdmin = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isAdmin) return SizedBox.shrink();

    // Placeholder values (replace with real data where needed)
  final status = 'CLOCK IN';
  final timer = '02:15:30';
  // TODO: compute 'exceeded' based on actual elapsed time. Use accent color accordingly.
  final Color accent = Colors.orange.shade600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 6,
            height: 80,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            ),
          ),
          SizedBox(width: 12),
          // Icon + main info
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: accent.withOpacity(0.15),
                  child: Icon(Icons.work, color: accent, size: 20),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JOB', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Status: ', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        SizedBox(width: 12),
                        Text('Timer: ', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        Text(timer, style: TextStyle(fontSize: 12, fontFamily: 'RobotoMono')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
