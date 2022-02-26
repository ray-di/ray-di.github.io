# Inject only direct dependencies

Avoid injecting an object only as a means to get at another object. For example,
don't inject a `Customer` as a means to get at an `Account`:

```java
public class ShowBudgets {
   private final Account account;

   @Inject
   ShowBudgets(Customer customer) {
     account = customer.getPurchasingAccount();
   }
```

Instead, inject the dependency directly. This makes testing easier; the test
case doesn't need to concern itself with the customer. Use an `@Provides` method
in your `Module` to create the binding for `Account` that uses the binding for
`Customer`:

```java
public class CustomersModule extends AbstractModule {
  @Override public void configure() {
    ...
  }

  @Provides
  Account providePurchasingAccount(Customer customer) {
    return customer.getPurchasingAccount();
  }
```

By injecting the dependency directly, our code is simpler.

```java
public class ShowBudgets {
   private final Account account;

   @Inject
   ShowBudgets(Account account) {
     this.account = account;
   }
```
