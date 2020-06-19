import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart' hide Key, AbstractNode;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Key;
import 'package:flutter_render/my_render/my_key.dart';
import 'package:flutter_render/my_render/my_node.dart';

///    author : linchenpeng
///    date   : 2020/6/18 9:37 AM
///    desc   :

/// Widget
@immutable
abstract class Widget {
  const Widget({this.key});

  final Key key;

  @protected
  Element createElement();

  @override
  bool operator ==(Object other) => super == other;

  @override
  int get hashCode => super.hashCode;

  static bool canUpdate(Widget oldWidget, Widget newWidget) {
    return oldWidget.runtimeType == newWidget.runtimeType &&
        oldWidget.key == newWidget.key;
  }
}

/// ProxyWidget
abstract class ProxyWidget extends Widget {
  const ProxyWidget({Key key, @required this.child}) : super(key: key);
  final Widget child;
}

/// ParentDataWidget
abstract class ParentDataWidget<T extends ParentData> extends ProxyWidget {
  const ParentDataWidget({Key key, Widget child})
      : super(key: key, child: child);

  @override
  ParentDataElement<T> createElement() => ParentDataElement<T>(this);

  @protected
  void applyParentData(RenderObject renderObject);

  @protected
  bool debugCanApplyOutOfTurn() => false;
}

/// InheritedWidget
abstract class InheritedWidget extends ProxyWidget {
  const InheritedWidget({Key key, Widget child})
      : super(key: key, child: child);

  @override
  InheritedElement createElement() => InheritedElement(this);

  @protected
  bool updateShouldNotify(covariant InheritedWidget oldWidget);
}

/// RenderObjectWidget
abstract class RenderObjectWidget extends Widget {
  const RenderObjectWidget({Key key}) : super(key: key);

  @override
  // @factory
  RenderObjectElement createElement();

  @protected
  // @factory
  RenderObject createRenderObject(BuildContext context);

  @protected
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject);

  @protected
  void didUnmountRenderObject(covariant RenderObject renderObject) {}
}

/// LeafRenderObjectWidget
abstract class LeafRenderObjectWidget extends RenderObjectWidget {
  const LeafRenderObjectWidget({Key key}) : super(key: key);

  @override
  LeafRenderObjectElement createElement() => LeafRenderObjectElement(this);
}

/// SingleChildRenderObjectWidget
abstract class SingleChildRenderObjectWidget extends RenderObjectWidget {
  const SingleChildRenderObjectWidget({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  SingleChildRenderObjectElement createElement() =>
      SingleChildRenderObjectElement(this);
}

abstract class MultiChildRenderObjectWidget extends RenderObjectWidget {
  final List<Widget> children;

  MultiChildRenderObjectWidget({Key key, this.children = const <Widget>[]})
      : super(key: key);

  @override
  MultiChildRenderObjectElement createElement() =>
      MultiChildRenderObjectElement(this);
}

/// StatelessWidget
abstract class StatelessWidget extends Widget {
  const StatelessWidget({Key key}) : super(key: key);

  @override
  StatelessElement createElement() => StatelessElement(this);

  @protected
  Widget build(BuildContext context);
}

/// StatefulWidget
abstract class StatefulWidget extends Widget {
  const StatefulWidget({Key key}) : super(key: key);

  @override
  StatefulElement createElement() => StatefulElement(this);

  @protected
  State createState();
}

typedef StateSetter = void Function(VoidCallback fn);

/// State
@optionalTypeArgs
abstract class State<T extends StatefulWidget> {
  T get widget => _widget;
  T _widget;

  BuildContext get context => _element;
  StatefulElement _element;

  bool get mounted => _element != null;

  @protected
  @mustCallSuper
  void initState() {}

  @mustCallSuper
  @protected
  void didUpdateWidget(covariant T oldWidget) {}

  @mustCallSuper
  @protected
  void reassemble() {}

  @protected
  void setState(VoidCallback fn) {
    final dynamic result = fn() as dynamic;
    _element.markNeedsBuild();
  }

  @mustCallSuper
  @protected
  void deactivate() {}

  @mustCallSuper
  @protected
  void dispose() {}

  @protected
  Widget build(BuildContext context);

  @mustCallSuper
  @protected
  void didChangeDependencies() {}
}

/// Element
abstract class Element implements BuildContext {
  Element(Widget widget) : _widget = widget;

  Element _parent;

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => _cachedHash;
  final int _cachedHash = _nextHashCode = (_nextHashCode + 1) % 0xffffff;
  static int _nextHashCode = 1;

  dynamic get slot => _slot;
  dynamic _slot;

  int get depth => _depth;
  int _depth;

  static int _sort(Element a, Element b) {
    if (a.depth < b.depth) {
      return -1;
    }
    if (b.depth < a.depth) {
      return 1;
    }

    if (b.dirty && !a.dirty) {
      return -1;
    }

    if (a.dirty && !b.dirty) {
      return 1;
    }
    return 0;
  }

  @override
  Widget get widget => _widget;
  Widget _widget;

  @override
  BuildOwner get owner => _owner;
  BuildOwner _owner;

  bool _active = false;

  @mustCallSuper
  @protected
  void reassemble() {
    markNeedsBuild();
    visitChildren((Element child) {
      child.reassemble();
    });
  }

  RenderObject get renderObject {
    RenderObject result;
    void visit(Element element) {
      if (element is RenderObjectElement) {
        result = element.renderObject;
      } else {
        element.visitChildren(visit);
      }
    }

    visit(this);
    return result;
  }

  void visitChildren(ElementVisitor visitor) {}

  @override
  void visitChildElements(ElementVisitor visitor) {
    visitChildren(visitor);
  }

  @protected
  Element updateChild(Element child, Widget newWidget, dynamic newSlot) {
    if (newWidget == null) {
      if (child != null) {
        deactivateChild(child);
      }
      return null;
    }

    Element newChild;
    if (child != null) {
      bool hasSameSuperclass = true;
      if (hasSameSuperclass && child.widget == newWidget) {
        if (child.slot != newSlot) {
          updateSlotForChild(child, newSlot);
        }
        newChild = child;
      } else if (hasSameSuperclass &&
          Widget.canUpdate(child.widget, newWidget)) {
        if (child.slot != newSlot) {
          updateSlotForChild(child, newSlot);
        }
        child.update(newWidget);
        newChild = child;
      } else {
        deactivateChild(child);
        newChild = inflateWidget(newWidget, newSlot);
      }
    } else {
      newChild = inflateWidget(newWidget, newSlot);
    }

    return newChild;
  }

  @mustCallSuper
  void mount(Element parent, dynamic newSlot) {
    _parent = parent;
    _slot = newSlot;

    /// 根节点的深度是1
    _depth = _parent != null ? _parent.depth + 1 : 1;
    _active = true;
    if (parent != null) {
      _owner = parent.owner;
    }
    final Key key = widget.key;
    if (key is GlobalKey) {
      key._register(this);
    }
    _updateInheritance();
  }

  @mustCallSuper
  void update(covariant Widget newWidget) {
    _widget = newWidget;
  }

  @protected
  void updateSlotForChild(Element child, dynamic newSlot) {
    void visit(Element element) {
      element._updateSlot(newSlot);
      if (element is! RenderObjectElement) {
        element.visitChildren(visit);
      }
    }

    visit(child);
  }

  void _updateSlot(dynamic newSlot) {
    _slot = newSlot;
  }

  void _updateDepth(int parentDepth) {
    final int expectedDepth = parentDepth + 1;
    if (_depth < expectedDepth) {
      _depth = expectedDepth;
      visitChildren((Element child) {
        child._updateDepth(expectedDepth);
      });
    }
  }

  void detachRenderObject() {
    visitChildren((Element child) {
      child.detachRenderObject();
    });
    _slot = null;
  }

  void attachRenderObject(dynamic newSlot) {
    visitChildren((Element child) {
      child.attachRenderObject(newSlot);
    });
    _slot = newSlot;
  }

  Element _retakeInactiveElement(GlobalKey key, Widget newWidget) {
    final Element element = key._currentElement;
    if (element == null) {
      return null;
    }
    if (!Widget.canUpdate(element.widget, newWidget)) {
      return null;
    }

    final Element parent = element._parent;
    if (parent != null) {
      parent.forgetChild(element);
      parent.deactivateChild(element);
    }

    owner._inactiveElements.remove(element);
    return element;
  }

  @protected
  Element inflateWidget(Widget newWidget, dynamic newSlot) {
    final Key key = newWidget.key;

    if (key is GlobalKey) {
      final Element newChild = _retakeInactiveElement(key, newWidget);
      if (newChild != null) {
        newChild._activateWithParent(this, newSlot);
        final Element updatedChild = updateChild(newChild, newWidget, newSlot);
        return updatedChild;
      }
    }

    final Element newChild = newWidget.createElement();
    newChild.mount(this, newSlot);
    return newChild;
  }

  @protected
  void deactivateChild(Element child) {
    child._parent = null;
    child.detachRenderObject();
    owner._inactiveElements.add(child);
  }

  @protected
  @mustCallSuper
  void forgetChild(Element child) {}

  void _activateWithParent(Element parent, dynamic newSlot) {
    _parent = parent;
    _updateDepth(_parent.depth);
    _activateRecursively(this);
    attachRenderObject(newSlot);
  }

  static void _activateRecursively(Element element) {
    element.activate();
    element.visitChildren(_activateRecursively);
  }

  @mustCallSuper
  void activate() {
    final bool hadDependencies =
        (_dependencies != null && _dependencies.isNotEmpty) ||
            _hadUnsatisfiedDependencies;
    _active = true;
    _dependencies?.clear();
    _hadUnsatisfiedDependencies = false;
    _updateInheritance();

    if (_dirty) {
      owner.scheduleBuildFor(this);
    }
    if (hadDependencies) {
      didChangeDependencies();
    }
  }

  @mustCallSuper
  void deactivate() {
    if (_dependencies != null && _dependencies.isNotEmpty) {
      for (final InheritedElement dependency in _dependencies) {
        dependency._dependents.remove(this);
      }
    }
    _inheritedWidgets = null;
    _active = false;
  }

  @mustCallSuper
  void unmount() {
    final Key key = _widget.key;
    if (key is GlobalKey) {
      key._unregister(this);
    }
  }

  @override
  RenderObject findRenderObject() => renderObject;

  @override
  Size get size {
    final RenderObject renderObject = findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.size;
    }
    return null;
  }

  Map<Type, InheritedElement> _inheritedWidgets;
  Set<InheritedElement> _dependencies;
  bool _hadUnsatisfiedDependencies = false;

  @override
  InheritedWidget dependOnInheritedElement(InheritedElement ancestor,
      {Object aspect}) {
    _dependencies ??= HashSet<InheritedElement>();
    _dependencies.add(ancestor);
    ancestor.updateDependencies(this, aspect);
    return ancestor.widget;
  }

  @override
  T dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
      {Object aspect}) {
    final InheritedElement ancestor =
        _inheritedWidgets == null ? null : _inheritedWidgets[T];

    if (ancestor != null) {
      return dependOnInheritedElement(ancestor);
    }
    _hadUnsatisfiedDependencies = true;
    return null;
  }

  @override
  InheritedElement
      getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() {
    final InheritedElement ancestor =
        _inheritedWidgets == null ? null : _inheritedWidgets[T];
    return ancestor;
  }

  void _updateInheritance() {
    _inheritedWidgets = _parent?._inheritedWidgets;
  }

  @override
  T findAncestorWidgetOfExactType<T extends Widget>() {
    Element ancestor = _parent;
    while (ancestor != null && ancestor.widget.runtimeType != T) {
      ancestor = ancestor._parent;
    }
    return ancestor?.widget as T;
  }

  /// 找到最靠近的State
  @override
  T findAncestorStateOfType<T extends State>() {
    Element ancestor = _parent;
    while (ancestor != null) {
      if (ancestor is StatefulElement && ancestor.state is T) {
        break;
      }
      ancestor = ancestor._parent;
    }

    final StatefulElement statefulElement = ancestor as StatefulElement;
    return statefulElement?.state as T;
  }

  /// 找到最顶层的State
  @override
  T findRootAncestorStateOfType<T extends State>() {
    Element ancestor = _parent;
    StatefulElement statefulAncestor;
    while (ancestor != null) {
      if (ancestor is StatefulElement && ancestor.state is T) {
        statefulAncestor = ancestor;
      }
      ancestor = ancestor._parent;
    }
    return statefulAncestor?.state as T;
  }

  @override
  T findAncestorRenderObjectOfType<T extends RenderObject>() {
    Element ancestor = _parent;
    while (ancestor != null) {
      if (ancestor is RenderObjectElement && ancestor.renderObject is T) {
        return ancestor.renderObject as T;
      }
      ancestor = ancestor._parent;
    }
    return null;
  }

  @override
  void visitAncestorElements(bool visitor(Element element)) {
    Element ancestor = _parent;
    while (ancestor != null && visitor(ancestor)) {
      ancestor = ancestor._parent;
    }
  }

  @mustCallSuper
  void didChangeDependencies() {
    markNeedsBuild();
  }

  bool get dirty => _dirty;
  bool _dirty = true;

  bool _inDirtyList = false;

  void markNeedsBuild() {
    if (!_active) {
      return;
    }
    if (dirty) {
      return;
    }

    _dirty = true;
    owner.scheduleBuildFor(this);
  }

  void rebuild() {
    if (!_active || !_dirty) {
      return;
    }

    performRebuild();
  }

  @protected
  void performRebuild();
}

/// ComponentElement
abstract class ComponentElement extends Element {
  ComponentElement(Widget widget) : super(widget);

  Element _child;

  @override
  void mount(Element parent, newSlot) {
    super.mount(parent, newSlot);
    _firstBuild();
  }

  void _firstBuild() {
    rebuild();
  }

  @override
  void performRebuild() {
    Widget built;
    built = build();
    _dirty = false;

    _child = updateChild(_child, built, slot);
  }

  @protected
  Widget build();

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child);
    }
  }

  @override
  void forgetChild(Element child) {
    _child = null;
    super.forgetChild(child);
  }
}

/// ProxyElement
abstract class ProxyElement extends ComponentElement {
  ProxyElement(ProxyWidget widget) : super(widget);

  @override
  ProxyWidget get widget => super.widget as ProxyWidget;

  @override
  Widget build() => widget.child;

  @override
  void update(Widget newWidget) {
    final ProxyWidget oldWidget = widget;
    super.update(newWidget);
    updated(oldWidget);
    _dirty = true;
    rebuild();
  }

  @protected
  void updated(covariant ProxyWidget oldWidget) {
    notifyClients(oldWidget);
  }

  @protected
  void notifyClients(covariant ProxyWidget oldWidget);
}

/// InheritedElement
class InheritedElement extends ProxyElement {
  InheritedElement(InheritedWidget widget) : super(widget);

  @override
  InheritedWidget get widget => super.widget as InheritedWidget;

  final Map<Element, Object> _dependents = HashMap<Element, Object>();

  @override
  void _updateInheritance() {
    final Map<Type, InheritedElement> incomingWidgets =
        _parent?._inheritedWidgets;
    if (incomingWidgets != null) {
      _inheritedWidgets = HashMap<Type, InheritedElement>.from(incomingWidgets);
    } else {
      _inheritedWidgets = HashMap<Type, InheritedElement>();
    }
    _inheritedWidgets[widget.runtimeType] = this;
  }

  @protected
  Object getDependencies(Element dependent) {
    return _dependents[dependent];
  }

  @protected
  void setDependencies(Element dependent, Object value) {
    _dependents[dependent] = value;
  }

  @protected
  void updateDependencies(Element dependent, Object aspect) {
    setDependencies(dependent, null);
  }

  @protected
  void notifyDependent(covariant InheritedWidget oldWidget, Element dependent) {
    dependent.didChangeDependencies();
  }

  @override
  void updated(InheritedWidget oldWidget) {
    if (widget.updateShouldNotify(oldWidget)) {
      super.updated(oldWidget);
    }
  }

  @override
  void notifyClients(InheritedWidget oldWidget) {
    for (final Element dependent in _dependents.keys) {
      notifyDependent(oldWidget, dependent);
    }
  }
}

/// RenderObjectElement
abstract class RenderObjectElement extends Element {
  RenderObjectElement(RenderObjectWidget widget) : super(widget);

  @override
  RenderObjectWidget get widget => super.widget as RenderObjectWidget;

  @override
  RenderObject get renderObject => _renderObject;
  RenderObject _renderObject;

  RenderObjectElement _ancestorRenderObjectElement;

  RenderObjectElement _findAncestorRenderObjectElement() {
    Element ancestor = _parent;
    while (ancestor != null && ancestor is! RenderObjectElement) {
      ancestor = ancestor._parent;
    }
    return ancestor as RenderObjectElement;
  }

  ParentDataElement<ParentData> _findAncesotrParentDataElement() {
    Element ancestor = _parent;
    ParentDataElement<ParentData> result;
    while (ancestor != null && ancestor is! RenderObjectElement) {
      if (ancestor is ParentDataElement<ParentData>) {
        result = ancestor as ParentDataElement<ParentData>;
        break;
      }
      ancestor = ancestor._parent;
    }
    return result;
  }

  @override
  void mount(Element parent, newSlot) {
    super.mount(parent, newSlot);
    _renderObject = widget.createRenderObject(this);

    attachRenderObject(newSlot);
    _dirty = false;
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    super.update(newWidget);

    widget.updateRenderObject(this, renderObject);
    _dirty = false;
  }

  @override
  void performRebuild() {
    widget.updateRenderObject(this, renderObject);
    _dirty = false;
  }

  @protected
  List<Element> updateChildren(
      List<Element> oldChildren, List<Widget> newWidgets,
      {Set<Element> forgottenChildren}) {
    Element replaceWithNullIfForgotten(Element child) {
      return forgottenChildren != null && forgottenChildren.contains(child)
          ? null
          : child;
    }

    // This attempts to diff the new child list (newWidgets) with
    // the old child list (oldChildren), and produce a new list of elements to
    // be the new list of child elements of this element. The called of this
    // method is expected to update this render object accordingly.

    // The cases it tries to optimize for are:
    //  - the old list is empty
    //  - the lists are identical
    //  - there is an insertion or removal of one or more widgets in
    //    only one place in the list
    // If a widget with a key is in both lists, it will be synced.
    // Widgets without keys might be synced but there is no guarantee.

    // The general approach is to sync the entire new list backwards, as follows:
    // 1. Walk the lists from the top, syncing nodes, until you no longer have
    //    matching nodes.
    // 2. Walk the lists from the bottom, without syncing nodes, until you no
    //    longer have matching nodes. We'll sync these nodes at the end. We
    //    don't sync them now because we want to sync all the nodes in order
    //    from beginning to end.
    // At this point we narrowed the old and new lists to the point
    // where the nodes no longer match.
    // 3. Walk the narrowed part of the old list to get the list of
    //    keys and sync null with non-keyed items.
    // 4. Walk the narrowed part of the new list forwards:
    //     * Sync non-keyed items with null
    //     * Sync keyed items with the source if it exists, else with null.
    // 5. Walk the bottom of the list again, syncing the nodes.
    // 6. Sync null with any items in the list of keys that are still
    //    mounted.

    int newChildrenTop = 0;
    int oldChildrenTop = 0;
    int newChildrenBottom = newWidgets.length - 1;
    int oldChildrenBottom = oldChildren.length - 1;

    final List<Element> newChildren = oldChildren.length == newWidgets.length
        ? oldChildren
        : List<Element>(newWidgets.length);

    Element previousChild;

    // Update the top of the list.
    while ((oldChildrenTop <= oldChildrenBottom) &&
        (newChildrenTop <= newChildrenBottom)) {
      final Element oldChild =
          replaceWithNullIfForgotten(oldChildren[oldChildrenTop]);
      final Widget newWidget = newWidgets[newChildrenTop];
      if (oldChild == null || !Widget.canUpdate(oldChild.widget, newWidget))
        break;
      final Element newChild = updateChild(oldChild, newWidget,
          IndexedSlot<Element>(newChildrenTop, previousChild));
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    // Scan the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) &&
        (newChildrenTop <= newChildrenBottom)) {
      final Element oldChild =
          replaceWithNullIfForgotten(oldChildren[oldChildrenBottom]);
      final Widget newWidget = newWidgets[newChildrenBottom];
      if (oldChild == null || !Widget.canUpdate(oldChild.widget, newWidget))
        break;
      oldChildrenBottom -= 1;
      newChildrenBottom -= 1;
    }

    // Scan the old children in the middle of the list.
    final bool haveOldChildren = oldChildrenTop <= oldChildrenBottom;
    Map<Key, Element> oldKeyedChildren;
    if (haveOldChildren) {
      oldKeyedChildren = <Key, Element>{};
      while (oldChildrenTop <= oldChildrenBottom) {
        final Element oldChild =
            replaceWithNullIfForgotten(oldChildren[oldChildrenTop]);
        if (oldChild != null) {
          if (oldChild.widget.key != null)
            oldKeyedChildren[oldChild.widget.key] = oldChild;
          else
            deactivateChild(oldChild);
        }
        oldChildrenTop += 1;
      }
    }

    // Update the middle of the list.
    while (newChildrenTop <= newChildrenBottom) {
      Element oldChild;
      final Widget newWidget = newWidgets[newChildrenTop];
      if (haveOldChildren) {
        final Key key = newWidget.key;
        if (key != null) {
          oldChild = oldKeyedChildren[key];
          if (oldChild != null) {
            if (Widget.canUpdate(oldChild.widget, newWidget)) {
              // we found a match!
              // remove it from oldKeyedChildren so we don't unsync it later
              oldKeyedChildren.remove(key);
            } else {
              // Not a match, let's pretend we didn't see it for now.
              oldChild = null;
            }
          }
        }
      }
      final Element newChild = updateChild(oldChild, newWidget,
          IndexedSlot<Element>(newChildrenTop, previousChild));
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
    }

    // We've scanned the whole list.
    newChildrenBottom = newWidgets.length - 1;
    oldChildrenBottom = oldChildren.length - 1;

    // Update the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) &&
        (newChildrenTop <= newChildrenBottom)) {
      final Element oldChild = oldChildren[oldChildrenTop];
      final Widget newWidget = newWidgets[newChildrenTop];
      final Element newChild = updateChild(oldChild, newWidget,
          IndexedSlot<Element>(newChildrenTop, previousChild));
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    // Clean up any of the remaining middle nodes from the old list.
    if (haveOldChildren && oldKeyedChildren.isNotEmpty) {
      for (final Element oldChild in oldKeyedChildren.values) {
        if (forgottenChildren == null || !forgottenChildren.contains(oldChild))
          deactivateChild(oldChild);
      }
    }

    return newChildren;
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void unmount() {
    super.unmount();
    widget.didUnmountRenderObject(renderObject);
  }

  void _updateParentData(ParentDataWidget<ParentData> parentDataWidget) {
    parentDataWidget.applyParentData(renderObject);
  }

  @override
  void _updateSlot(newSlot) {
    super._updateSlot(newSlot);
    _ancestorRenderObjectElement.moveChildRenderObject(renderObject, slot);
  }

  @override
  void attachRenderObject(dynamic newSlot) {
    _slot = newSlot;
    _ancestorRenderObjectElement = _findAncestorRenderObjectElement();
    _ancestorRenderObjectElement?.insertChildRenderObject(
        renderObject, newSlot);
    final ParentDataElement<ParentData> parentDataElement =
        _findAncesotrParentDataElement();
    if (parentDataElement != null) {
      _updateParentData(parentDataElement.widget);
    }
  }

  @override
  void detachRenderObject() {
    if (_ancestorRenderObjectElement != null) {
      _ancestorRenderObjectElement.removeChildRenderObject(renderObject);
      _ancestorRenderObjectElement = null;
    }
    _slot = null;
  }

  @protected
  void insertChildRenderObject(
      covariant RenderObject child, covariant dynamic slot);

  @protected
  void moveChildRenderObject(
      covariant RenderObject child, covariant dynamic slot);

  @protected
  void removeChildRenderObject(covariant RenderObject child);
}

/// LeafRenderObjectElement
class LeafRenderObjectElement extends RenderObjectElement {
  LeafRenderObjectElement(LeafRenderObjectWidget widget) : super(widget);

  @override
  void insertChildRenderObject(RenderObject child, slot) {}

  @override
  void moveChildRenderObject(RenderObject child, slot) {}

  @override
  void removeChildRenderObject(RenderObject child) {}
}

/// SingleChildRenderObjectElement
class SingleChildRenderObjectElement extends RenderObjectElement {
  SingleChildRenderObjectElement(SingleChildRenderObjectWidget widget)
      : super(widget);

  @override
  SingleChildRenderObjectWidget get widget =>
      super.widget as SingleChildRenderObjectWidget;

  Element _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child);
    }
  }

  @override
  void forgetChild(Element child) {
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _child = updateChild(_child, widget.child, null);
  }

  @override
  void update(SingleChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    _child = updateChild(_child, widget.child, null);
  }

  @override
  void insertChildRenderObject(RenderObject child, slot) {
    final RenderObjectWithChildMixin<RenderObject> renderObject =
        this.renderObject as RenderObjectWithChildMixin<RenderObject>;
    renderObject.child = child;
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    final RenderObjectWithChildMixin<RenderObject> renderObject =
        this.renderObject as RenderObjectWithChildMixin<RenderObject>;
    renderObject.child = null;
  }

  @override
  void moveChildRenderObject(RenderObject child, slot) {}
}

mixin RenderObjectWithChildMixin<ChildType extends RenderObject>
    on RenderObject {
  ChildType _child;

  /// The render object's unique child
  ChildType get child => _child;

  set child(ChildType value) {
    if (_child != null) dropChild(_child);
    _child = value;
    if (_child != null) adoptChild(_child);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_child != null) _child.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    if (_child != null) _child.detach();
  }

  @override
  void redepthChildren() {
    if (_child != null) redepthChild(_child);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_child != null) visitor(_child);
  }
}

class MultiChildRenderObjectElement extends RenderObjectElement {
  /// Creates an element that uses the given widget as its configuration.
  MultiChildRenderObjectElement(MultiChildRenderObjectWidget widget)
      : super(widget);

  @override
  MultiChildRenderObjectWidget get widget =>
      super.widget as MultiChildRenderObjectWidget;

  /// The current list of children of this element.
  ///
  /// This list is filtered to hide elements that have been forgotten (using
  /// [forgetChild]).
  @protected
  @visibleForTesting
  Iterable<Element> get children =>
      _children.where((Element child) => !_forgottenChildren.contains(child));

  List<Element> _children;

  // We keep a set of forgotten children to avoid O(n^2) work walking _children
  // repeatedly to remove children.
  final Set<Element> _forgottenChildren = HashSet<Element>();

  @override
  void insertChildRenderObject(RenderObject child, IndexedSlot<Element> slot) {
    final ContainerRenderObjectMixin<RenderObject,
            ContainerParentDataMixin<RenderObject>> renderObject =
        this.renderObject as ContainerRenderObjectMixin<RenderObject,
            ContainerParentDataMixin<RenderObject>>;
    renderObject.insert(child, after: slot?.value?.renderObject);
  }

  @override
  void moveChildRenderObject(RenderObject child, IndexedSlot<Element> slot) {
    final ContainerRenderObjectMixin<RenderObject,
            ContainerParentDataMixin<RenderObject>> renderObject =
        this.renderObject as ContainerRenderObjectMixin<RenderObject,
            ContainerParentDataMixin<RenderObject>>;
    renderObject.move(child, after: slot?.value?.renderObject);
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    final ContainerRenderObjectMixin<RenderObject,
            ContainerParentDataMixin<RenderObject>> renderObject =
        this.renderObject as ContainerRenderObjectMixin<RenderObject,
            ContainerParentDataMixin<RenderObject>>;
    renderObject.remove(child);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final Element child in _children) {
      if (!_forgottenChildren.contains(child)) visitor(child);
    }
  }

  @override
  void forgetChild(Element child) {
    _forgottenChildren.add(child);
    super.forgetChild(child);
  }

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _children = List<Element>(widget.children.length);
    Element previousChild;
    for (int i = 0; i < _children.length; i += 1) {
      final Element newChild = inflateWidget(
          widget.children[i], IndexedSlot<Element>(i, previousChild));
      _children[i] = newChild;
      previousChild = newChild;
    }
  }

  @override
  void update(MultiChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    _children = updateChildren(_children, widget.children,
        forgottenChildren: _forgottenChildren);
    _forgottenChildren.clear();
  }
}

@immutable
class IndexedSlot<T> {
  /// Creates an [IndexedSlot] with the provided [index] and slot [value].
  const IndexedSlot(this.index, this.value);

  /// Information to define where the child occupying this slot fits in its
  /// parent's child list.
  final T value;

  /// The index of this slot in the parent's child list.
  final int index;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is IndexedSlot && index == other.index && value == other.value;
  }

  @override
  int get hashCode => hashValues(index, value);
}

/// ParentDataElement
class ParentDataElement<T extends ParentData> extends ProxyElement {
  ParentDataElement(ParentDataWidget<T> widget) : super(widget);

  @override
  ParentDataWidget get widget => super.widget as ParentDataWidget<T>;

  void _applyParentData(ParentDataWidget<T> widget) {
    void applyParentDataToChild(Element child) {
      if (child is RenderObjectElement) {
        child._updateParentData(widget);
      } else {
        child.visitChildren(applyParentDataToChild);
      }
    }

    visitChildren(applyParentDataToChild);
  }

  void applyWidgetOutOfTurn(ParentDataWidget<T> newWidget) {
    _applyParentData(newWidget);
  }

  @override
  void notifyClients(ParentDataWidget<T> oldWidget) {
    _applyParentData(widget);
  }
}

class ParentData {
  @protected
  @mustCallSuper
  void detach() {}

  @override
  String toString() => '<none>';
}

/// StatelessElement
class StatelessElement extends ComponentElement {
  StatelessElement(Widget widget) : super(widget);

  @override
  StatelessWidget get widget => super.widget as StatelessWidget;

  @override
  Widget build() => widget.build(this);

  @override
  void update(Widget newWidget) {
    super.update(newWidget);
    _dirty = true;
    rebuild();
  }
}

/// StatefulElement
class StatefulElement extends ComponentElement {
  StatefulElement(StatefulWidget widget)
      : _state = widget.createState(),
        super(widget) {
    _state._element = this;
    _state._widget = widget;
  }

  @override
  Widget build() => _state.build(this);

  State<StatefulWidget> get state => _state;
  State<StatefulWidget> _state;

  @override
  void reassemble() {
    state.reassemble();
    super.reassemble();
  }

  @override
  void _firstBuild() {
    _state.initState();
    _state.didChangeDependencies();
    super._firstBuild();
  }

  @override
  void performRebuild() {
    if (_didChangeDependencies) {
      _state.didChangeDependencies();
      _didChangeDependencies = false;
    }
    super.performRebuild();
  }

  @override
  void update(StatefulWidget newWidget) {
    super.update(newWidget);
    final StatefulWidget oldWidget = _state.widget;

    _dirty = true;
    _state._widget = widget as StatefulWidget;

    _state.didUpdateWidget(oldWidget);
    rebuild();
  }

  @override
  void activate() {
    super.activate();
    markNeedsBuild();
  }

  @override
  void deactivate() {
    _state.deactivate();
    super.deactivate();
  }

  @override
  void unmount() {
    super.unmount();
    _state.dispose();
    _state._element = null;
    _state = null;
  }

  @override
  InheritedWidget dependOnInheritedElement(Element ancestor, {Object aspect}) {
    return super
        .dependOnInheritedElement(ancestor as InheritedElement, aspect: aspect);
  }

  bool _didChangeDependencies = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _didChangeDependencies = true;
  }
}

/// RenderObject
abstract class RenderObject extends AbstractNode implements HitTestTarget {
  /// Initializes internal fields for subclasses.
  RenderObject() {
    _needsCompositing = isRepaintBoundary || alwaysNeedsCompositing;
  }

  void reassemble() {
    markNeedsLayout();
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
    visitChildren((RenderObject child) {
      child.reassemble();
    });
  }

  ParentData parentData;

  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! ParentData) child.parentData = ParentData();
  }

  @override
  void adoptChild(RenderObject child) {
    setupParentData(child);
    markNeedsLayout();
    markNeedsCompositingBitsUpdate();
    markNeedsSemanticsUpdate();
    super.adoptChild(child);
  }

  @override
  void dropChild(RenderObject child) {
    child._cleanRelayoutBoundary();
    child.parentData.detach();
    child.parentData = null;
    super.dropChild(child);
    markNeedsLayout();
    markNeedsCompositingBitsUpdate();
    markNeedsSemanticsUpdate();
  }

  void visitChildren(RenderObjectVisitor visitor) {}

  @override
  PipelineOwner get owner => super.owner as PipelineOwner;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_needsLayout && _relayoutBoundary != null) {
      _needsLayout = false;
      markNeedsLayout();
    }
    if (_needsCompositingBitsUpdate) {
      _needsCompositingBitsUpdate = false;
      markNeedsCompositingBitsUpdate();
    }
    if (_needsPaint && _layer != null) {
      _needsPaint = false;
      markNeedsPaint();
    }
    if (_needsSemanticsUpdate && _semanticsConfiguration.isSemanticBoundary) {
      _needsSemanticsUpdate = false;
      markNeedsSemanticsUpdate();
    }
  }

  bool _needsLayout = true;

  RenderObject _relayoutBoundary;
  bool _doingThisLayoutWithCallback = false;

  @protected
  Constraints get constraints => _constraints;
  Constraints _constraints;

  void markNeedsLayout() {
    if (_needsLayout) {
      return;
    }
    if (_relayoutBoundary != this) {
      markParentNeedsLayout();
    } else {
      _needsLayout = true;
      if (owner != null) {
        owner._nodesNeedingLayout.add(this);
        owner.requestVisualUpdate();
      }
    }
  }

  @protected
  void markParentNeedsLayout() {
    _needsLayout = true;
    final RenderObject parent = this.parent as RenderObject;
    if (!_doingThisLayoutWithCallback) {
      parent.markNeedsLayout();
    } else {}
  }

  void markNeedsLayoutForSizedByParentChange() {
    markNeedsLayout();
    markParentNeedsLayout();
  }

  void _cleanRelayoutBoundary() {
    if (_relayoutBoundary != this) {
      _relayoutBoundary = null;
      _needsLayout = true;
      visitChildren(_cleanChildRelayoutBoundary);
    }
  }

  // Reduces closure allocation for visitChildren use cases.
  static void _cleanChildRelayoutBoundary(RenderObject child) {
    child._cleanRelayoutBoundary();
  }

  void scheduleInitialLayout() {
    _relayoutBoundary = this;
    owner._nodesNeedingLayout.add(this);
  }

  void _layoutWithoutResize() {
    performLayout();
    markNeedsSemanticsUpdate();
    _needsLayout = false;
    markNeedsPaint();
  }

  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    RenderObject relayoutBoundary;
    if (!parentUsesSize ||
        sizedByParent ||
        constraints.isTight ||
        parent is! RenderObject) {
      relayoutBoundary = this;
    } else {
      relayoutBoundary = (parent as RenderObject)._relayoutBoundary;
    }
    if (!_needsLayout &&
        constraints == _constraints &&
        relayoutBoundary == _relayoutBoundary) {
      return;
    }
    _constraints = constraints;
    if (_relayoutBoundary != null && relayoutBoundary != _relayoutBoundary) {
      visitChildren(_cleanChildRelayoutBoundary);
    }
    _relayoutBoundary = relayoutBoundary;
    if (sizedByParent) {
      performResize();
    }
    performLayout();
    markNeedsSemanticsUpdate();
    _needsLayout = false;
    markNeedsPaint();
  }

  @protected
  bool get sizedByParent => false;

  @protected
  void performResize();

  @protected
  void performLayout();

  @protected
  void invokeLayoutCallback<T extends Constraints>(LayoutCallback<T> callback) {
    _doingThisLayoutWithCallback = true;
    try {
      owner._enableMutationsToDirtySubtrees(() {
        callback(constraints as T);
      });
    } finally {
      _doingThisLayoutWithCallback = false;
    }
  }

  /// Rotate this render object (not yet implemented).
  void rotate({
    int oldAngle, // 0..3
    int newAngle, // 0..3
    Duration time,
  }) {}

  bool get isRepaintBoundary => false;

  @protected
  bool get alwaysNeedsCompositing => false;

  @protected
  ContainerLayer get layer {
    assert(!isRepaintBoundary || (_layer == null || _layer is OffsetLayer));
    return _layer;
  }

  @protected
  set layer(ContainerLayer newLayer) {
    _layer = newLayer;
  }

  ContainerLayer _layer;

  bool _needsCompositingBitsUpdate = false; // set to true when a child is added
  void markNeedsCompositingBitsUpdate() {
    if (_needsCompositingBitsUpdate) return;
    _needsCompositingBitsUpdate = true;
    if (parent is RenderObject) {
      final RenderObject parent = this.parent as RenderObject;
      if (parent._needsCompositingBitsUpdate) return;
      if (!isRepaintBoundary && !parent.isRepaintBoundary) {
        parent.markNeedsCompositingBitsUpdate();
        return;
      }
    }
    // parent is fine (or there isn't one), but we are dirty
    if (owner != null) owner._nodesNeedingCompositingBitsUpdate.add(this);
  }

  bool _needsCompositing; // initialized in the constructor
  bool get needsCompositing {
    return _needsCompositing;
  }

  void _updateCompositingBits() {
    if (!_needsCompositingBitsUpdate) return;
    final bool oldNeedsCompositing = _needsCompositing;
    _needsCompositing = false;
    visitChildren((RenderObject child) {
      child._updateCompositingBits();
      if (child.needsCompositing) _needsCompositing = true;
    });
    if (isRepaintBoundary || alwaysNeedsCompositing) _needsCompositing = true;
    if (oldNeedsCompositing != _needsCompositing) markNeedsPaint();
    _needsCompositingBitsUpdate = false;
  }

  bool _needsPaint = true;

  void markNeedsPaint() {
    if (_needsPaint) return;
    _needsPaint = true;
    if (isRepaintBoundary) {
      if (owner != null) {
        owner._nodesNeedingPaint.add(this);
        owner.requestVisualUpdate();
      }
    } else if (parent is RenderObject) {
      final RenderObject parent = this.parent as RenderObject;
      parent.markNeedsPaint();
    } else {
      if (owner != null) owner.requestVisualUpdate();
    }
  }

  // Called when flushPaint() tries to make us paint but our layer is detached.
  // To make sure that our subtree is repainted when it's finally reattached,
  // even in the case where some ancestor layer is itself never marked dirty, we
  // have to mark our entire detached subtree as dirty and needing to be
  // repainted. That way, we'll eventually be repainted.
  void _skippedPaintingOnLayer() {
    AbstractNode ancestor = parent;
    while (ancestor is RenderObject) {
      final RenderObject node = ancestor as RenderObject;
      if (node.isRepaintBoundary) {
        if (node._layer == null)
          break; // looks like the subtree here has never been painted. let it handle itself.
        if (node._layer.attached)
          break; // it's the one that detached us, so it's the one that will decide to repaint us.
        node._needsPaint = true;
      }
      ancestor = node.parent;
    }
  }

  /// Bootstrap the rendering pipeline by scheduling the very first paint.
  ///
  /// Requires that this render object is attached, is the root of the render
  /// tree, and has a composited layer.
  ///
  /// See [RenderView] for an example of how this function is used.
  void scheduleInitialPaint(ContainerLayer rootLayer) {
    _layer = rootLayer;
    owner._nodesNeedingPaint.add(this);
  }

  /// Replace the layer. This is only valid for the root of a render
  /// object subtree (whatever object [scheduleInitialPaint] was
  /// called on).
  ///
  /// This might be called if, e.g., the device pixel ratio changed.
  void replaceRootLayer(OffsetLayer rootLayer) {
    // use scheduleInitialPaint the first time
    _layer.detach();
    _layer = rootLayer;
    markNeedsPaint();
  }

  void _paintWithContext(PaintingContext context, Offset offset) {
    // If we still need layout, then that means that we were skipped in the
    // layout phase and therefore don't need painting. We might not know that
    // yet (that is, our layer might not have been detached yet), because the
    // same node that skipped us in layout is above us in the tree (obviously)
    // and therefore may not have had a chance to paint yet (since the tree
    // paints in reverse order). In particular this will happen if they have
    // a different layer, because there's a repaint boundary between us.
    if (_needsLayout) return;

    _needsPaint = false;
    paint(context, offset);
  }

  Rect get paintBounds;

  void paint(PaintingContext context, Offset offset) {}

  void applyPaintTransform(covariant RenderObject child, Matrix4 transform) {
    assert(child.parent == this);
  }

  Matrix4 getTransformTo(RenderObject ancestor) {
    final bool ancestorSpecified = ancestor != null;
    if (ancestor == null) {
      final AbstractNode rootNode = owner.rootNode;
      if (rootNode is RenderObject) ancestor = rootNode;
    }
    final List<RenderObject> renderers = <RenderObject>[];
    for (RenderObject renderer = this;
        renderer != ancestor;
        renderer = renderer.parent as RenderObject) {
      renderers.add(renderer);
    }
    if (ancestorSpecified) renderers.add(ancestor);
    final Matrix4 transform = Matrix4.identity();
    for (int index = renderers.length - 1; index > 0; index -= 1) {
      renderers[index].applyPaintTransform(renderers[index - 1], transform);
    }
    return transform;
  }

  Rect describeApproximatePaintClip(covariant RenderObject child) => null;

  /// Returns a rect in this object's coordinate system that describes
  /// which [SemanticsNode]s produced by the `child` should be included in the
  /// semantics tree. [SemanticsNode]s from the `child` that are positioned
  /// outside of this rect will be dropped. Child [SemanticsNode]s that are
  /// positioned inside this rect, but outside of [describeApproximatePaintClip]
  /// will be included in the tree marked as hidden. Child [SemanticsNode]s
  /// that are inside of both rect will be included in the tree as regular
  /// nodes.
  ///
  /// This method only returns a non-null value if the semantics clip rect
  /// is different from the rect returned by [describeApproximatePaintClip].
  /// If the semantics clip rect and the paint clip rect are the same, this
  /// method returns null.
  ///
  /// A viewport would typically implement this method to include semantic nodes
  /// in the semantics tree that are currently hidden just before the leading
  /// or just after the trailing edge. These nodes have to be included in the
  /// semantics tree to implement implicit accessibility scrolling on iOS where
  /// the viewport scrolls implicitly when moving the accessibility focus from
  /// a the last visible node in the viewport to the first hidden one.
  Rect describeSemanticsClip(covariant RenderObject child) => null;

  // SEMANTICS

  /// Bootstrap the semantics reporting mechanism by marking this node
  /// as needing a semantics update.
  ///
  /// Requires that this render object is attached, and is the root of
  /// the render tree.
  ///
  /// See [RendererBinding] for an example of how this function is used.
  void scheduleInitialSemantics() {
    owner._nodesNeedingSemantics.add(this);
    owner.requestVisualUpdate();
  }

  /// Report the semantics of this node, for example for accessibility purposes.
  ///
  /// This method should be overridden by subclasses that have interesting
  /// semantic information.
  ///
  /// The given [SemanticsConfiguration] object is mutable and should be
  /// annotated in a manner that describes the current state. No reference
  /// should be kept to that object; mutating it outside of the context of the
  /// [describeSemanticsConfiguration] call (for example as a result of
  /// asynchronous computation) will at best have no useful effect and at worse
  /// will cause crashes as the data will be in an inconsistent state.
  ///
  /// {@tool snippet}
  ///
  /// The following snippet will describe the node as a button that responds to
  /// tap actions.
  ///
  /// ```dart
  /// abstract class SemanticButtonRenderObject extends RenderObject {
  ///   @override
  ///   void describeSemanticsConfiguration(SemanticsConfiguration config) {
  ///     super.describeSemanticsConfiguration(config);
  ///     config
  ///       ..onTap = _handleTap
  ///       ..label = 'I am a button'
  ///       ..isButton = true;
  ///   }
  ///
  ///   void _handleTap() {
  ///     // Do something.
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  @protected
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    // Nothing to do by default.
  }

  /// Sends a [SemanticsEvent] associated with this render object's [SemanticsNode].
  ///
  /// If this render object has no semantics information, the first parent
  /// render object with a non-null semantic node is used.
  ///
  /// If semantics are disabled, no events are dispatched.
  ///
  /// See [SemanticsNode.sendEvent] for a full description of the behavior.
  void sendSemanticsEvent(SemanticsEvent semanticsEvent) {
    if (owner.semanticsOwner == null) return;
    if (_semantics != null && !_semantics.isMergedIntoParent) {
      _semantics.sendEvent(semanticsEvent);
    } else if (parent != null) {
      final RenderObject renderParent = parent as RenderObject;
      renderParent.sendSemanticsEvent(semanticsEvent);
    }
  }

  // Use [_semanticsConfiguration] to access.
  SemanticsConfiguration _cachedSemanticsConfiguration;

  SemanticsConfiguration get _semanticsConfiguration {
    if (_cachedSemanticsConfiguration == null) {
      _cachedSemanticsConfiguration = SemanticsConfiguration();
      describeSemanticsConfiguration(_cachedSemanticsConfiguration);
    }
    return _cachedSemanticsConfiguration;
  }

  /// The bounding box, in the local coordinate system, of this
  /// object, for accessibility purposes.
  Rect get semanticBounds;

  bool _needsSemanticsUpdate = true;
  SemanticsNode _semantics;

  /// The semantics of this render object.
  ///
  /// Exposed only for testing and debugging. To learn about the semantics of
  /// render objects in production, obtain a [SemanticsHandle] from
  /// [PipelineOwner.ensureSemantics].
  ///
  /// Only valid in debug and profile mode. In release builds, always returns
  /// null.
  SemanticsNode get debugSemantics {
    if (!kReleaseMode) {
      return _semantics;
    }
    return null;
  }

  /// Removes all semantics from this render object and its descendants.
  ///
  /// Should only be called on objects whose [parent] is not a [RenderObject].
  ///
  /// Override this method if you instantiate new [SemanticsNode]s in an
  /// overridden [assembleSemanticsNode] method, to dispose of those nodes.
  @mustCallSuper
  void clearSemantics() {
    _needsSemanticsUpdate = true;
    _semantics = null;
    visitChildren((RenderObject child) {
      child.clearSemantics();
    });
  }

  /// Mark this node as needing an update to its semantics description.
  ///
  /// This must be called whenever the semantics configuration of this
  /// [RenderObject] as annotated by [describeSemanticsConfiguration] changes in
  /// any way to update the semantics tree.
  void markNeedsSemanticsUpdate() {
    if (!attached || owner._semanticsOwner == null) {
      _cachedSemanticsConfiguration = null;
      return;
    }

    // Dirty the semantics tree starting at `this` until we have reached a
    // RenderObject that is a semantics boundary. All semantics past this
    // RenderObject are still up-to date. Therefore, we will later only rebuild
    // the semantics subtree starting at the identified semantics boundary.

    final bool wasSemanticsBoundary = _semantics != null &&
        _cachedSemanticsConfiguration?.isSemanticBoundary == true;
    _cachedSemanticsConfiguration = null;
    bool isEffectiveSemanticsBoundary =
        _semanticsConfiguration.isSemanticBoundary && wasSemanticsBoundary;
    RenderObject node = this;

    while (!isEffectiveSemanticsBoundary && node.parent is RenderObject) {
      if (node != this && node._needsSemanticsUpdate) break;
      node._needsSemanticsUpdate = true;

      node = node.parent as RenderObject;
      isEffectiveSemanticsBoundary =
          node._semanticsConfiguration.isSemanticBoundary;
      if (isEffectiveSemanticsBoundary && node._semantics == null) {
        // We have reached a semantics boundary that doesn't own a semantics node.
        // That means the semantics of this branch are currently blocked and will
        // not appear in the semantics tree. We can abort the walk here.
        return;
      }
    }
    if (node != this && _semantics != null && _needsSemanticsUpdate) {
      // If `this` node has already been added to [owner._nodesNeedingSemantics]
      // remove it as it is no longer guaranteed that its semantics
      // node will continue to be in the tree. If it still is in the tree, the
      // ancestor `node` added to [owner._nodesNeedingSemantics] at the end of
      // this block will ensure that the semantics of `this` node actually gets
      // updated.
      // (See semantics_10_test.dart for an example why this is required).
      owner._nodesNeedingSemantics.remove(this);
    }
    if (!node._needsSemanticsUpdate) {
      node._needsSemanticsUpdate = true;
      if (owner != null) {
        owner._nodesNeedingSemantics.add(node);
        owner.requestVisualUpdate();
      }
    }
  }

  /// Updates the semantic information of the render object.
  void _updateSemantics() {
    if (_needsLayout) {
      // There's not enough information in this subtree to compute semantics.
      // The subtree is probably being kept alive by a viewport but not laid out.
      return;
    }
    final _SemanticsFragment fragment = _getSemanticsForParent(
      mergeIntoParent: _semantics?.parent?.isPartOfNodeMerging ?? false,
    );
    final _InterestingSemanticsFragment interestingFragment =
        fragment as _InterestingSemanticsFragment;
    final SemanticsNode node = interestingFragment
        .compileChildren(
          parentSemanticsClipRect: _semantics?.parentSemanticsClipRect,
          parentPaintClipRect: _semantics?.parentPaintClipRect,
          elevationAdjustment: _semantics?.elevationAdjustment ?? 0.0,
        )
        .single;
  }

  /// Returns the semantics that this node would like to add to its parent.
  _SemanticsFragment _getSemanticsForParent({
    @required bool mergeIntoParent,
  }) {
    final SemanticsConfiguration config = _semanticsConfiguration;
    bool dropSemanticsOfPreviousSiblings =
        config.isBlockingSemanticsOfPreviouslyPaintedNodes;

    final bool producesForkingFragment =
        !config.hasBeenAnnotated && !config.isSemanticBoundary;
    final List<_InterestingSemanticsFragment> fragments =
        <_InterestingSemanticsFragment>[];
    final Set<_InterestingSemanticsFragment> toBeMarkedExplicit =
        <_InterestingSemanticsFragment>{};
    final bool childrenMergeIntoParent =
        mergeIntoParent || config.isMergingSemanticsOfDescendants;

    // When set to true there's currently not enough information in this subtree
    // to compute semantics. In this case the walk needs to be aborted and no
    // SemanticsNodes in the subtree should be updated.
    // This will be true for subtrees that are currently kept alive by a
    // viewport but not laid out.
    bool abortWalk = false;

    visitChildrenForSemantics((RenderObject renderChild) {
      if (abortWalk || _needsLayout) {
        abortWalk = true;
        return;
      }
      final _SemanticsFragment parentFragment =
          renderChild._getSemanticsForParent(
        mergeIntoParent: childrenMergeIntoParent,
      );
      if (parentFragment.abortsWalk) {
        abortWalk = true;
        return;
      }
      if (parentFragment.dropsSemanticsOfPreviousSiblings) {
        fragments.clear();
        toBeMarkedExplicit.clear();
        if (!config.isSemanticBoundary) dropSemanticsOfPreviousSiblings = true;
      }
      // Figure out which child fragments are to be made explicit.
      for (final _InterestingSemanticsFragment fragment
          in parentFragment.interestingFragments) {
        fragments.add(fragment);
        fragment.addAncestor(this);
        fragment.addTags(config.tagsForChildren);
        if (config.explicitChildNodes || parent is! RenderObject) {
          fragment.markAsExplicit();
          continue;
        }
        if (!fragment.hasConfigForParent || producesForkingFragment) continue;
        if (!config.isCompatibleWith(fragment.config))
          toBeMarkedExplicit.add(fragment);
        for (final _InterestingSemanticsFragment siblingFragment
            in fragments.sublist(0, fragments.length - 1)) {
          if (!fragment.config.isCompatibleWith(siblingFragment.config)) {
            toBeMarkedExplicit.add(fragment);
            toBeMarkedExplicit.add(siblingFragment);
          }
        }
      }
    });

    if (abortWalk) {
      return _AbortingSemanticsFragment(owner: this);
    }

    for (final _InterestingSemanticsFragment fragment in toBeMarkedExplicit)
      fragment.markAsExplicit();

    _needsSemanticsUpdate = false;

    _SemanticsFragment result;
    if (parent is! RenderObject) {
      result = _RootSemanticsFragment(
        owner: this,
        dropsSemanticsOfPreviousSiblings: dropSemanticsOfPreviousSiblings,
      );
    } else if (producesForkingFragment) {
      result = _ContainerSemanticsFragment(
        dropsSemanticsOfPreviousSiblings: dropSemanticsOfPreviousSiblings,
      );
    } else {
      result = _SwitchableSemanticsFragment(
        config: config,
        mergeIntoParent: mergeIntoParent,
        owner: this,
        dropsSemanticsOfPreviousSiblings: dropSemanticsOfPreviousSiblings,
      );
      if (config.isSemanticBoundary) {
        final _SwitchableSemanticsFragment fragment =
            result as _SwitchableSemanticsFragment;
        fragment.markAsExplicit();
      }
    }

    result.addAll(fragments);

    return result;
  }

  /// Called when collecting the semantics of this node.
  ///
  /// The implementation has to return the children in paint order skipping all
  /// children that are not semantically relevant (e.g. because they are
  /// invisible).
  ///
  /// The default implementation mirrors the behavior of
  /// [visitChildren] (which is supposed to walk all the children).
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitChildren(visitor);
  }

  /// Assemble the [SemanticsNode] for this [RenderObject].
  ///
  /// If [isSemanticBoundary] is true, this method is called with the `node`
  /// created for this [RenderObject], the `config` to be applied to that node
  /// and the `children` [SemanticsNode]s that descendants of this RenderObject
  /// have generated.
  ///
  /// By default, the method will annotate `node` with `config` and add the
  /// `children` to it.
  ///
  /// Subclasses can override this method to add additional [SemanticsNode]s
  /// to the tree. If new [SemanticsNode]s are instantiated in this method
  /// they must be disposed in [clearSemantics].
  void assembleSemanticsNode(
    CustomPaint
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    // TODO(a14n): remove the following cast by updating type of parameter in either updateWith or assembleSemanticsNode
    node.updateWith(
        config: config,
        childrenInInversePaintOrder: children as List<SemanticsNode>);
  }

  // EVENTS

  /// Override this method to handle pointer events that hit this render object.
  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {}

  void showOnScreen({
    RenderObject descendant,
    Rect rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (parent is RenderObject) {
      final RenderObject renderParent = parent as RenderObject;
      renderParent.showOnScreen(
        descendant: descendant ?? this,
        rect: rect,
        duration: duration,
        curve: curve,
      );
    }
  }
}

typedef RenderObjectVisitor = void Function(RenderObject child);

/// RenderBox
abstract class RenderBox extends RenderObject {}

/// BuildContext
abstract class BuildContext {
  Widget get widget;

  BuildOwner get owner;

  RenderObject findRenderObject();

  Size get size;

  InheritedWidget dependOnInheritedElement(InheritedElement ancestor,
      {Object aspect});

  T dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
      {Object aspect});

  InheritedElement
      getElementForInheritedWidgetOfExactType<T extends InheritedWidget>();

  T findAncestorWidgetOfExactType<T extends Widget>();

  T findAncestorStateOfType<T extends State>();

  T findRootAncestorStateOfType<T extends State>();

  T findAncestorRenderObjectOfType<T extends RenderObject>();

  void visitAncestorElements(bool visitor(Element element));

  void visitChildElements(ElementVisitor visitor);
}

typedef ElementVisitor = void Function(Element element);

/// BuildOwner
class BuildOwner {
  BuildOwner({this.onBuildScheduled});

  VoidCallback onBuildScheduled;

  final _InactiveElements _inactiveElements = _InactiveElements();

  final List<Element> _dirtyElements = <Element>[];
  bool _scheduledFlushDirtyElements = false;

  bool _dirtyElementsNeedsResorting;

  FocusManager focusManager = FocusManager();

  void scheduleBuildFor(Element element) {
    if (element._inDirtyList) {
      _dirtyElementsNeedsResorting = true;
      return;
    }

    if (!_scheduledFlushDirtyElements && onBuildScheduled != null) {
      _scheduledFlushDirtyElements = true;
      onBuildScheduled();
    }

    _dirtyElements.add(element);
    element._inDirtyList = true;
  }

  void lockState(void callback()) {
    callback();
  }

  void buildScope(Element context, [VoidCallback callback]) {
    if (callback == null && _dirtyElements.isEmpty) {
      return;
    }

    try {
      _scheduledFlushDirtyElements = true;
      if (callback != null) {
        _dirtyElementsNeedsResorting = true;
        callback();
      }

      _dirtyElements.sort(Element._sort);
      _dirtyElementsNeedsResorting = false;
      int dirtyCount = _dirtyElements.length;
      int index = 0;
      while (index < dirtyCount) {
        _dirtyElements[index].rebuild();
        index += 1;
        if (dirtyCount < _dirtyElements.length ||
            _dirtyElementsNeedsResorting) {
          _dirtyElements.sort(Element._sort);
          _dirtyElementsNeedsResorting = false;
          dirtyCount = _dirtyElements.length;
          while (index > 0 && _dirtyElements[index - 1].dirty) {
            // It is possible for previously dirty but inactive widgets to move right in the list.
            // We therefore have to move the index left in the list to account for this.
            // We don't know how many could have moved. However, we do know that the only possible
            // change to the list is that nodes that were previously to the left of the index have
            // now moved to be to the right of the right-most cleaned node, and we do know that
            // all the clean nodes were to the left of the index. So we move the index left
            // until just after the right-most clean node.
            index -= 1;
          }
        }
      }
    } finally {
      for (final Element element in _dirtyElements) {
        element._inDirtyList = false;
      }

      _dirtyElements.clear();
      _scheduledFlushDirtyElements = false;
      _dirtyElementsNeedsResorting = null;
    }
  }

  void finalizeTree() {
    lockState(() {
      _inactiveElements._unmountAll();
    });
  }

  void reassemble(Element root) {
    root.reassemble();
  }
}

/// _ElementLifecycle
enum _ElementLifecycle {
  initial,
  active,
  inactive,
  defunct,
}

/// _InactiveElements
class _InactiveElements {
  final Set<Element> _elements = HashSet<Element>();

  void _unmount(Element element) {
    element.visitChildren((Element child) {
      _unmount(child);
    });
    element.unmount();
  }

  void _unmountAll() {
    final List<Element> elements = _elements.toList()..sort(Element._sort);
    _elements.clear();
    elements.reversed.forEach(_unmount);
  }

  static void _deactiveRecursively(Element element) {
    element.deactivate();
    element.visitChildren(_deactiveRecursively);
  }

  void add(Element element) {
    if (element._active) {
      _deactiveRecursively(element);
    }
    _elements.add(element);
  }

  void remove(Element element) {
    _elements.remove(element);
  }
}

/// GlobalKey
@optionalTypeArgs
abstract class GlobalKey<T extends State<StatefulWidget>> extends Key {
  factory GlobalKey({String debugLevel}) => LabeledGlobalKey<T>(debugLevel);

  const GlobalKey.constructor() : super.empty();

  static final Map<GlobalKey, Element> _registry = <GlobalKey, Element>{};

  void _register(Element element) {
    _registry[this] = element;
  }

  void _unregister(Element element) {
    if (_registry[this] == element) {
      _registry.remove(this);
    }
  }

  Element get _currentElement => _registry[this];

  BuildContext get currentContext => _currentElement;

  Widget get currentWidget => _currentElement?.widget;

  T get currentState {
    final Element element = _currentElement;
    if (element is StatefulElement) {
      final StatefulElement statefulElement = element;
      final State state = statefulElement.state;
      if (state is T) {
        return state;
      }
    }
    return null;
  }
}

@optionalTypeArgs
class LabeledGlobalKey<T extends State<StatefulWidget>> extends GlobalKey<T> {
  LabeledGlobalKey(this._debugLevel) : super.constructor();

  final String _debugLevel;

  @override
  String toString() {
    final String label = _debugLevel != null ? ' $_debugLevel' : '';
    if (runtimeType == LabeledGlobalKey) {
      return '[GlobalKey#${shortHash(this)}$label]';
    }
    return '[${describeIdentity(this)}$label]';
  }
}

mixin ContainerParentDataMixin<ChildType extends RenderObject> on ParentData {
  /// The previous sibling in the parent's child list.
  ChildType previousSibling;

  /// The next sibling in the parent's child list.
  ChildType nextSibling;

  /// Clear the sibling pointers.
  @override
  void detach() {
    super.detach();
  }
}

mixin ContainerRenderObjectMixin<ChildType extends RenderObject,
        ParentDataType extends ContainerParentDataMixin<ChildType>>
    on RenderObject {
  int _childCount = 0;

  /// The number of children.
  int get childCount => _childCount;

  ChildType _firstChild;
  ChildType _lastChild;
  void _insertIntoChildList(ChildType child, {ChildType after}) {
    final ParentDataType childParentData = child.parentData as ParentDataType;
    assert(childParentData.nextSibling == null);
    _childCount += 1;
    assert(_childCount > 0);
    if (after == null) {
      // insert at the start (_firstChild)
      childParentData.nextSibling = _firstChild;
      if (_firstChild != null) {
        final ParentDataType _firstChildParentData =
            _firstChild.parentData as ParentDataType;
        _firstChildParentData.previousSibling = child;
      }
      _firstChild = child;
      _lastChild ??= child;
    } else {
      final ParentDataType afterParentData = after.parentData as ParentDataType;
      if (afterParentData.nextSibling == null) {
        // insert at the end (_lastChild); we'll end up with two or more children
        childParentData.previousSibling = after;
        afterParentData.nextSibling = child;
        _lastChild = child;
      } else {
        // insert in the middle; we'll end up with three or more children
        // set up links from child to siblings
        childParentData.nextSibling = afterParentData.nextSibling;
        childParentData.previousSibling = after;
        // set up links from siblings to child
        final ParentDataType childPreviousSiblingParentData =
            childParentData.previousSibling.parentData as ParentDataType;
        final ParentDataType childNextSiblingParentData =
            childParentData.nextSibling.parentData as ParentDataType;
        childPreviousSiblingParentData.nextSibling = child;
        childNextSiblingParentData.previousSibling = child;
      }
    }
  }

  /// Insert child into this render object's child list after the given child.
  ///
  /// If `after` is null, then this inserts the child at the start of the list,
  /// and the child becomes the new [firstChild].
  void insert(ChildType child, {ChildType after}) {
    adoptChild(child);
    _insertIntoChildList(child, after: after);
  }

  /// Append child to the end of this render object's child list.
  void add(ChildType child) {
    insert(child, after: _lastChild);
  }

  /// Add all the children to the end of this render object's child list.
  void addAll(List<ChildType> children) {
    children?.forEach(add);
  }

  void _removeFromChildList(ChildType child) {
    final ParentDataType childParentData = child.parentData as ParentDataType;
    if (childParentData.previousSibling == null) {
      _firstChild = childParentData.nextSibling;
    } else {
      final ParentDataType childPreviousSiblingParentData =
          childParentData.previousSibling.parentData as ParentDataType;
      childPreviousSiblingParentData.nextSibling = childParentData.nextSibling;
    }
    if (childParentData.nextSibling == null) {
      _lastChild = childParentData.previousSibling;
    } else {
      final ParentDataType childNextSiblingParentData =
          childParentData.nextSibling.parentData as ParentDataType;
      childNextSiblingParentData.previousSibling =
          childParentData.previousSibling;
    }
    childParentData.previousSibling = null;
    childParentData.nextSibling = null;
    _childCount -= 1;
  }

  /// Remove this child from the child list.
  ///
  /// Requires the child to be present in the child list.
  void remove(ChildType child) {
    _removeFromChildList(child);
    dropChild(child);
  }

  /// Remove all their children from this render object's child list.
  ///
  /// More efficient than removing them individually.
  void removeAll() {
    ChildType child = _firstChild;
    while (child != null) {
      final ParentDataType childParentData = child.parentData as ParentDataType;
      final ChildType next = childParentData.nextSibling;
      childParentData.previousSibling = null;
      childParentData.nextSibling = null;
      dropChild(child);
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
    _childCount = 0;
  }

  /// Move the given `child` in the child list to be after another child.
  ///
  /// More efficient than removing and re-adding the child. Requires the child
  /// to already be in the child list at some position. Pass null for `after` to
  /// move the child to the start of the child list.
  void move(ChildType child, {ChildType after}) {
    final ParentDataType childParentData = child.parentData as ParentDataType;
    if (childParentData.previousSibling == after) return;
    _removeFromChildList(child);
    _insertIntoChildList(child, after: after);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    ChildType child = _firstChild;
    while (child != null) {
      child.attach(owner);
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void detach() {
    super.detach();
    ChildType child = _firstChild;
    while (child != null) {
      child.detach();
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void redepthChildren() {
    ChildType child = _firstChild;
    while (child != null) {
      redepthChild(child);
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    ChildType child = _firstChild;
    while (child != null) {
      visitor(child);
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  /// The first child in the child list.
  ChildType get firstChild => _firstChild;

  /// The last child in the child list.
  ChildType get lastChild => _lastChild;

  /// The previous child before the given child in the child list.
  ChildType childBefore(ChildType child) {
    final ParentDataType childParentData = child.parentData as ParentDataType;
    return childParentData.previousSibling;
  }

  /// The next child after the given child in the child list.
  ChildType childAfter(ChildType child) {
    final ParentDataType childParentData = child.parentData as ParentDataType;
    return childParentData.nextSibling;
  }
}
