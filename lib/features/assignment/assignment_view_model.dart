import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import 'reviewed_bill_data.dart';

/// Estado de "quién consumió qué" — un ítem puede tener varias personas
/// asignadas (ítem compartido, ej. una entrada entre 3). La calculadora de
/// Fase 5 divide el costo del ítem entre sus asignados.
class AssignmentViewModel extends ChangeNotifier {
  final ReviewedBillData bill;
  final List<PeopleData> people;
  final List<Set<int>> _assignmentsByItemIndex;

  // initialAssignments: al editar una factura ya guardada, precarga quién
  // tenía asignado cada ítem en vez de arrancar todo vacío. Se filtra contra
  // `people` (los seleccionados en ESTA sesión de edición) porque si alguien
  // se desmarcó en la pantalla anterior, dejar su id suelto en el mapa haría
  // que el cálculo lo siguiera contando como asignado (divide el costo del
  // ítem entre más gente de la que en verdad participa) sin marcarlo nunca
  // como "sin asignar".
  AssignmentViewModel({required this.bill, required this.people, Map<int, Set<int>>? initialAssignments})
      : _assignmentsByItemIndex = List.generate(
          bill.items.length,
          (i) => initialAssignments?[i]
                  ?.where((id) => people.any((p) => p.id == id))
                  .toSet() ??
              <int>{},
        );

  Set<int> assigneesFor(int itemIndex) => _assignmentsByItemIndex[itemIndex];

  bool isAssigned(int itemIndex, int personId) => _assignmentsByItemIndex[itemIndex].contains(personId);

  void toggle(int itemIndex, int personId) {
    final set = _assignmentsByItemIndex[itemIndex];
    if (set.contains(personId)) {
      set.remove(personId);
    } else {
      set.add(personId);
    }
    notifyListeners();
  }

  /// Índices de ítems sin ninguna persona asignada — bloquea el avance a
  /// Resumen porque, si se ignoran, ese costo desaparecería silenciosamente
  /// del total de todos.
  List<int> get unassignedItemIndexes {
    final result = <int>[];
    for (var i = 0; i < _assignmentsByItemIndex.length; i++) {
      if (_assignmentsByItemIndex[i].isEmpty) result.add(i);
    }
    return result;
  }

  bool get allItemsAssigned => unassignedItemIndexes.isEmpty;

  Map<int, Set<int>> get assignmentsSnapshot => {
        for (var i = 0; i < _assignmentsByItemIndex.length; i++) i: Set.of(_assignmentsByItemIndex[i]),
      };
}
