# Document the public bindings provided by modules

To document a Guice module, a good strategy is to describe the public bindings
that that module installs, for example:

```java
/**
 * Provides {@link FooServiceClient} and derived bindings.
 *
 * [...]
 *
 * <p>The following bindings are provided:
 *
 * <ul>
 *   <li>{@link FooServiceClient}
 *   <li>{@link FooServiceClientAuthenticator}
 * </ul>
 */
public final class FooServiceClientModule extends AbstractModule {
  // ...
}
```


