import 'package:flutter/material.dart';

import '../../data/models/drug_info.dart';
import 'theme.dart';

/// 식약처 낱알 사진. 없거나 못 받으면 알약 아이콘.
class DrugThumbnail extends StatelessWidget {
  const DrugThumbnail({
    super.key,
    required this.drug,
    required this.imageUrl,
    this.size = 48,
  });

  final DrugSummary drug;
  final String Function(String itemSeq) imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.medication_rounded,
      color: AppColors.inkMuted,
      size: size * 0.5,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceSunken,
        alignment: Alignment.center,
        child: drug.hasImage
            ? Image.network(
                imageUrl(drug.itemSeq),
                width: size,
                height: size,
                fit: BoxFit.cover,
                semanticLabel: '${drug.name} 사진',
                errorBuilder: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

/// 식약처에서 찾은 약 한 줄. 사진, 이름, 업체·생김새.
class DrugTile extends StatelessWidget {
  const DrugTile({
    super.key,
    required this.drug,
    required this.imageUrl,
    required this.onTap,
  });

  final DrugSummary drug;
  final String Function(String itemSeq) imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [?drug.company, if (drug.looks.isNotEmpty) drug.looks];
    return ListTile(
      leading: DrugThumbnail(drug: drug, imageUrl: imageUrl),
      title: Text(drug.name),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      onTap: onTap,
    );
  }
}
