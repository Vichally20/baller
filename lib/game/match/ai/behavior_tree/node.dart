/// The execution state returned by a Behavior Tree node.
enum NodeStatus {
  success,
  failure,
  running,
}

/// Base class for all nodes in the Behavior Tree.
abstract class BTNode<T> {
  const BTNode();

  /// Evaluates this node against the current [context].
  NodeStatus tick(T context);
}
