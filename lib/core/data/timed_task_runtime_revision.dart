import 'package:flutter_riverpod/legacy.dart';

const timedTaskPatchEntities = <String>{
  'logistics_transfer',
  'arge_research',
  'building_construction',
  'building_upgrade',
  'building_boost',
  'tender_delivery',
};

bool isTimedTaskPatchEntity(String entity) {
  return timedTaskPatchEntities.contains(entity);
}

final timedTaskRuntimeRevisionProvider = StateProvider<int>((ref) => 0);
