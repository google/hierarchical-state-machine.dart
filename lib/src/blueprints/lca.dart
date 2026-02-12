part of '../machine.dart';

/// Given two states, return their lowest common ancestor (LCA) defined as
/// the super state of both source and target.
///
/// Example:
///     left: [A, B, C, D, E, F]
///     right: [A, B, C, G, H, I]
///     LCA: C
///
///     left: [A, B, C]
///     right: [A, B]
///     LCA: A
BaseState<S, E>? lowestCommonAncestor<S, E>(
  BaseState<S, E> left,
  BaseState<S, E> right,
) {
  var iLeft = left.path.iterator;
  var iRight = right.path.iterator;
  BaseState<S, E>? common;
  while (iLeft.moveNext() && iRight.moveNext()) {
    if (iLeft.current != iRight.current) break;
    common = iLeft.current;
  }

  // Make sure to return the ancestor of both.
  if (common == left || common == right) {
    common = common?.parent;
  }

  return common;
}

extension StateLCAExtension<S, E> on List<BaseState<S, E>> {
  /// Finds the Lowest Common Ancestor for a collection of states.
  /// Returns null if the collection is empty.
  BaseState<S, E>? lca() {
    final pathCount = length;
    if (pathCount == 0) return null;
    if (pathCount == 1) return first.parent;

    // Convert to lists once to allow indexed access
    final paths = [for (final state in this) state.path];

    // The shortest path defines the maximum possible depth of the LCA
    int minPathLength = paths.first.length;
    for (int i = 1; i < pathCount; i++) {
      if (paths[i].length < minPathLength) {
        minPathLength = paths[i].length;
      }
    }

    BaseState<S, E>? common;

    for (int i = 0; i < minPathLength; i++) {
      final candidate = paths[0][i];

      // Check if all other paths share this node at depth i
      bool isMatch = true;
      for (int j = 1; j < paths.length; j++) {
        if (paths[j][i] != candidate) {
          isMatch = false;
          break;
        }
      }

      if (isMatch) {
        common = candidate;
      } else {
        // Paths have diverged; we found our LCA in the previous iteration
        break;
      }
    }

    // Strict Ancestor Rule: If the common node is one of the target states,
    // the true common ancestor must be its parent.
    for (int i = 0; i < pathCount; i++) {
      if (identical(this[i], common)) {
        return common?.parent;
      }
    }

    return common;
  }
}
