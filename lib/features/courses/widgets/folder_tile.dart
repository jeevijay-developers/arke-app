import 'package:flutter/material.dart';
import '../data/models/folder.dart';

const _indigo  = Color(0xFF5B4BF5);
const _textSub = Color(0xFF64748B);
const _surface = Color(0xFFFFFFFF);
const _border  = Color(0xFFE5E7EB);

class FolderTile extends StatelessWidget {
  final CourseFolder folder;
  final VoidCallback onTap;
  const FolderTile({super.key, required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _indigo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_rounded,
                    color: _indigo, size: 26),
              ),
              const Spacer(),
              Text(
                folder.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
              if (folder.itemCount > 0) ...[
                const SizedBox(height: 3),
                Text(
                  '${folder.itemCount} item${folder.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11.5, color: _textSub),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
