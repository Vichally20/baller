import 'package:baller/game/match/ai/behavior_tree/node.dart';

/// SELECTOR (OR): Evaluates children sequentially.
///
/// If any child returns [NodeStatus.success], it stops immediately and returns [NodeStatus.success].
/// If all children return [NodeStatus.failure], it returns [NodeStatus.failure].
class Selector<T> extends BTNode<T> {
  const Selector(this.children);

  final List<BTNode<T>> children;

  @override
  NodeStatus tick(T context) {
    for (final child in children) {
      final status = child.tick(context);
      if (status == NodeStatus.success) {
        return NodeStatus.success;
      }
      if (status == NodeStatus.running) {
        return NodeStatus.running;
      }
    }
    return NodeStatus.failure;
  }
}

/// SEQUENCE (AND): Evaluates children sequentially.
///
/// If any child returns [NodeStatus.failure], it stops immediately and returns [NodeStatus.failure].
/// If all children return [NodeStatus.success], it returns [NodeStatus.success].
class Sequence<T> extends BTNode<T> {
  const Sequence(this.children);

  final List<BTNode<T>> children;

  @override
  NodeStatus tick(T context) {
    for (final child in children) {
      final status = child.tick(context);
      if (status != NodeStatus.success) {
        return status;
      }
    }
    return NodeStatus.success;
  }
}

