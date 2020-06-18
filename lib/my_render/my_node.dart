import 'package:flutter/widgets.dart';

class AbstractNode {
  int get depth => _depth;
  int _depth = 0;

  @protected
  void redepthChild(AbstractNode child) {
    if (child._depth <= _depth) {
      child._depth = _depth + 1;
      child.redepthChildren();
    }
  }

  void redepthChildren() {}

  Object get owner => _owner;
  Object _owner;

  bool get attached => _owner != null;

  @mustCallSuper
  void attach(covariant Object owner) {
    _owner = owner;
  }

  @mustCallSuper
  void detach() {
    _owner = null;
  }

  AbstractNode get parent => _parent;
  AbstractNode _parent;

  @protected
  @mustCallSuper
  void adoptChild(covariant AbstractNode child) {
    child._parent = this;
    if (attached) {
      child.attach(_owner);
    }
    redepthChild(child);
  }

  @protected
  @mustCallSuper
  void dropChild(covariant AbstractNode child) {
    child._parent = null;
    if (attached) {
      child.detach();
    }
  }
}
