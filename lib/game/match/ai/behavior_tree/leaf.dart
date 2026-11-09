import 'package:baller/game/match/ai/behavior_tree/node.dart';

/// CONDITION (Leaf): Checks a boolean condition against the context.
class Condition<T> extends BTNode<T> {
  const Condition(this.predicate, {this.label});

  final bool Function(T context) predicate;
  final String? label;

  @override
  NodeStatus tick(T context) =>
      predicate(context) ? NodeStatus.success : NodeStatus.failure;

  @override
  String toString() => label != null ? 'Condition($label)' : 'Condition()';
}

/// ACTION (Leaf): Executes a side-effect or state mutation on the context.
class BTAction<T> extends BTNode<T> {
  const BTAction(this.execute, {this.label});

  final void Function(T context) execute;
  final String? label;

  @override
  NodeStatus tick(T context) {
    execute(context);
    return NodeStatus.success;
  }

  @override
  String toString() => label != null ? 'Action($label)' : 'Action()';
}

