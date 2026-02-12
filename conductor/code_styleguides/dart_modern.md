# Modern Dart Style Guide (3.10+)

This guide supplements the base `dart.md` with idiomatic patterns for features introduced in Dart 3.0 and beyond, focusing on Records, Patterns, and modern Collection features.

## 1. Records

Records are anonymous, immutable, aggregate types that allow bundling multiple values without defining a formal class.

- **PREFER** using records to return multiple values from a function instead of using "out" parameters or creating one-off classes.
- **DO** use named fields in records for clarity when the purpose of the values isn't immediately obvious from their type or order.
- **DO** use record destructuring to access fields concisely.
- **AVOID** using records as long-lived domain models; use classes for objects with identity and behavior.

```dart
// Good: Using a record for multiple return values
(double lat, double lon) getLocation() => (40.7128, -74.0060);

// Good: Using named fields for clarity
({int width, int height}) getDimensions() => (width: 1920, height: 1080);
```

## 2. Patterns

Patterns can match values against a structure, deconstruct values, or both.

### 2.1. Matching and Switching
- **PREFER** switch expressions over switch statements when the primary goal is to produce a value.
- **DO** use exhaustive switch expressions to ensure all possible cases (especially for sealed classes and enums) are handled.
- **DO** use `if-case` statements for concise single-pattern matching and deconstruction.
- **PREFER** using logical operators (`&&`, `||`) within patterns for complex matching logic.

```dart
// Good: Switch expression
String describe(Object color) => switch (color) {
  Color.red || Color.orange => 'Warm',
  Color.blue || Color.purple => 'Cool',
  _ => 'Neutral',
};

// Good: if-case for deconstruction
if (pair case [var a, var b]) {
  print('Found $a and $b');
}
```

### 2.2. Destructuring
- **DO** use patterns in variable declarations to destructure records and collections.
- **DO** use object patterns to deconstruct properties of an object concisely.

```dart
// Good: Destructuring a record
var (name, age) = getUserInfo();

// Good: Object pattern matching
if (shape case Square(size: var s)) {
  print('Square with size $s');
}
```

## 3. Modern Collections

Modern Dart allows for complex, declarative collection building using control flow and spreads.

### 3.1. Collection For and If
- **PREFER** using `for` elements in collection literals over `map()` followed by `toList()` or `addAll()` when the logic is simple.
- **DO** use `if` elements to conditionally include items in a collection, avoiding manual `if` blocks with `add()`.
- **PREFER** null-aware spreads (`...?`) when expanding a potentially null collection.

```dart
// Good: Using for and if elements
var nav = [
  'Home',
  'Furniture',
  'Plants',
  if (isLoggedIn) 'Logout',
  for (var i in items) 'Item $i',
];
```

## 4. Class Modifiers

Dart 3.0 introduced class modifiers to give library authors more control over how types are used.

- **PREFER** `sealed` for class hierarchies where all subtypes are known, enabling exhaustive pattern matching.
- **DO** use `final` for classes that should not be extended or implemented outside the current library.
- **DO** use `interface` for classes that define a contract but shouldn't be extended.
- **DO** use `base` to require subclasses to also use `base`, `final`, or `sealed`, preserving the base class's guarantees.
