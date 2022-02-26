---
layout: docs-en
title: Keep constructors hidden
category: Manual
permalink: /manuals/1.0/en/bp/keep_constructors_hidden.html
---
### Keep constructors on Guice-instantiated classes as hidden as possible.

Consider this simple interface:

```java
public interface DataReader {

  Data readData(DataSource dataSource);
}
```

It's a common reflex to implement this interface with a public class:

```java
public class DatabaseDataReader implements DataReader {

   private final ConnectionManager connectionManager;

   @Inject
   public DatabaseDataReader(
      ConnectionManager connectionManager) {
     this.connectionManager = connectionManager;
   }

   @Override
   public Data readData(DataSource dataSource) {
      // ... read data from the database
      return Data.of(readInData, someMetaData);
   }
}
```

A quick inspection of this code reveals nothing faulty about this
implementation. Unfortunately, such an inspection excludes the dimension of time
and the inevitability of an unguarded code base to become more tightly coupled
within itself over time.

Similar to the old axiom,
[Nothing good happens after midnight](http://www.google.com/webhp#hl=en&q=nothing+good+happens+after+midnight),
we also know that Nothing good happens after making a constructor public: A
public constructor _will_ have illicit uses introduced within a code base. These
uses necessarily will:

*   make refactoring more difficult.
*   break the interface-implementation abstraction barrier.
*   introduce tighter coupling within a codebase.

Perhaps worst of all, any direct use of a constructor circumvents Guice's object
instantiation.

As a correction, simply limit the visibility of both your implementation
classes, and their constructors. Typically package private is preferred for
both, as this facilitates:

*   binding the class within a `Module` in the same package
*   unit testing the class through means of direct instantiation

As a simple, mnemonic remember that `public` and `@Inject` are like
[Elves and Dwarfs](http://en.wikipedia.org/wiki/Dwarf_\(Middle-earth\)): they
_can_ work together, but in an ideal world, they would coexist independently.
