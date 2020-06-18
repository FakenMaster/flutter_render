import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
abstract class Key {
  const factory Key(String value) = ValueKey<String>;

  @protected
  const Key.empty();
}

abstract class LocalKey extends Key {
  const LocalKey() : super.empty();
}

class ValueKey<T> extends LocalKey {
  const ValueKey(this.value);

  final T value;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ValueKey<T> && other.value == value;
  }

  @override
  int get hashCode => hashValues(runtimeType, value);

  @override
  String toString() {
    final String valueString = T == String ? "<'$value'>" : '<$value>';
    if (runtimeType == _TypeLiteral<ValueKey<T>>().type) {
      return '[$valueString]';
    }
    return '[$T $valueString]';
  }
}

class _TypeLiteral<T> {
  Type get type => T;
}

class UniqueKey extends LocalKey {
  UniqueKey();

  @override
  String toString() {
    return '[#${shortHash(this)}]';
  }
}

class ObjectKey extends LocalKey {
  const ObjectKey(this.value);
  final Object value;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ObjectKey && identical(other.value, value);
  }

  @override
  int get hashCode => hashValues(runtimeType, identityHashCode(value));

  @override
  String toString() {
    if (runtimeType == ObjectKey) {
      return '[${describeIdentity(value)}]';
    }
    return '[${objectRuntimeType(this, 'ObjectKey')} ${describeIdentity(value)}]';
  }
}
