# Avoid Circular Dependencies

## What are circular dependencies?

Say that your application has a few classes including a `Store`, a `Boss`, and a
`Clerk`.

```java
public class Store {
  private final Boss boss;
  //...

  @Inject public Store(Boss boss) {
     this.boss = boss;
     //...
  }

  public void incomingCustomer(Customer customer) {...}
  public Customer getNextCustomer() {...}
}

public class Boss {
  private final Clerk clerk;
  @Inject public Boss(Clerk clerk) {
    this.clerk = clerk;
  }
}

public class Clerk {
  // Nothing interesting here
}
```

Right now, the dependency chain is all good: constructing a `Store` results in
constructing a `Boss`, which results in constructing a `Clerk`. However, to get
the `Clerk` to get a `Customer` to do the selling, it will need a reference to
the `Store` to get those customer:

```java
public class Store {
  private final Boss boss;
  //...

  @Inject public Store(Boss boss) {
     this.boss = boss;
     //...
  }
  public void incomingCustomer(Customer customer) {...}
  public Customer getNextCustomer() {...}
}

public class Boss {
  private final Clerk clerk;
  @Inject public Boss(Clerk clerk) {
    this.clerk = clerk;
  }
}

public class Clerk {
  private final Store shop;
  @Inject Clerk(Store shop) {
    this.shop = shop;
  }

  void doSale() {
    Customer sucker = shop.getNextCustomer();
    //...
  }
}
```

which leads to a cycle: `Clerk` -> `Store` -> `Boss` -> `Clerk`. In trying to
construct a `Clerk`, an `Store` will be constructed, which needs a `Boss`, which
needs a `Clerk` again!

## Ways to avoid circular dependencies

### Eliminate the cycle (Recommended)

Cycles often reflect insufficiently granular decomposition. To eliminate such
cycles, extract the Dependency Case into a separate class.

Take the above `Store` example, the work of managing the incoming customers can
be extracted into another class, say `CustomerLine`, and that can be injected
into the `Clerk` and `Store`.

```java
public class Store {
  private final Boss boss;
  private final CustomerLine line;
  //...

  @Inject public Store(Boss boss, CustomerLine line) {
     this.boss = boss;
     this.line = line;
     //...
  }

  public void incomingCustomer(Customer customer) { line.add(customer); }
}

public class Clerk {
  private final CustomerLine line;

  @Inject Clerk(CustomerLine line) {
    this.line = line;
  }

  void doSale() {
    Customer sucker = line.getNextCustomer();
    //...
  }
}
```

While both `Store` and `Clerk` depend on the `CustomerLine`, there's no cycle in
the dependency graph (although you may want to make sure that the `Store` and
`Clerk` both use the same `CustomerLine` instance). This also means that your
`Clerk` will be able to sell cars when your shop has a big tent sale: just
inject a different `CustomerLine`.

### Break the cycle with a Provider

[Injecting a Guice provider](InjectingProviders)
will allow you to add a _seam_ in the dependency graph. The `Clerk` will still
depend on the `Store`, but the `Clerk` doesn't look at the `Store` until it
needs a `Store`.

```java
public class Clerk {
  private final Provider<Store> shopProvider;
  @Inject Clerk(Provider<Store> shopProvider) {
    this.shopProvider = shopProvider;
  }

  void doSale() {
    Customer sucker = shopProvider.get().getNextCustomer();
    //...
  }
}
```

Note here, that unless `Store` is bound as a
[`Singleton`](Scopes#singleton) or in some
other scope to be reused, the `shopProvider.get()` call will end up constructing
a new `Store`, which will construct a new `Boss`, which will construct a new
`Clerk` again!

### Use factory methods to tie two objects together

When your dependencies are tied together a bit closer, untangling them with the
above methods won't work. Situations like this come up when using something like
a [View/Presenter](https://en.wikipedia.org/wiki/Model-view-presenter) paradigm:

```java
public class FooPresenter {
  @Inject public FooPresenter(FooView view) {
    //...
  }

  public void doSomething() {
    view.doSomethingCool();
  }
}

public class FooView {
  @Inject public FooView(FooPresenter presenter) {
    //...
  }

  public void userDidSomething() {
    presenter.theyDidSomething();
  }
  //...
}
```

Each of those objects needs the other object. Here, you can use
[AssistedInject](AssistedInject) to get
around it:

```java
public class FooPresenter {
  private final FooView view;
  @Inject public FooPresenter(FooView.Factory viewMaker) {
    view = viewMaker.create(this);
  }

  public void doSomething() {
  //...
    view.doSomethingCool();
  }
}

public class FooView {
  @Inject public FooView(@Assisted FooPresenter presenter) {...}

  public void userDidSomething() {
    presenter.theyDidSomething();
  }

  public static interface Factory {
    FooView create(FooPresenter presenter)
  }
}
```

Such situations also come up when attempting to use Guice to manifest business
object models, which may have cycles that reflect different types of
relationships.
[AssistedInject](AssistedInject) is also
quite good for such cases.

## Circular proxy feature

In cases where one of the dependencies in the circular chain is an interface
type, Guice can work around the circular dependency chain by generating a proxy
at runtime to break the cycle. However, this support is really limited and can
break unexpectedly if the type is changed to a non-interface type.

To prevent unexpected circular dependency chains in your code, we recommend that
you disable Guice's circular proxy feature. To do so, install a module that
calls `binder().disableCircularProxies()`:

```java {.good}
final class ApplicationModule extends AbstractModule {
  @Override
  protected void configure() {
    ...

    binder().disableCircularProxies();
  }
}
```

TIP: You can also install `Modules.disableCircularProxiesModule()` to disable
circular proxy in Guice.
