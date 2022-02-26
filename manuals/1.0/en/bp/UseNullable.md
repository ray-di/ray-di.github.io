# Use `@Nullable`

To eliminate `NullPointerExceptions` in your codebase, you must be disciplined
about null references. We've been successful at this by following and enforcing
a simple rule:

**Every injected parameter is non-null unless explicitly specified.**

The
[Guava: Google Core Libraries for Java](http://code.google.com/p/guava-libraries/)
and [JSR-305](https://github.com/amaembo/jsr-305) have simple APIs to get a
nulls under control. `Preconditions.checkNotNull` can be used to fast-fail if a
null reference is found, and `@Nullable` can be used to annotate a parameter
that permits the `null` value:

```java
import static com.google.common.base.Preconditions.checkNotNull;
import javax.annotation.Nullable;

public class Person {
  ...

  public Person(String firstName, String lastName, @Nullable Phone phone) {
    this.firstName = checkNotNull(firstName, "firstName");
    this.lastName = checkNotNull(lastName, "lastName");
    this.phone = phone;
  }
```

## Guice forbids `null` by default

Guice checks for nulls during injection - not during the creation of the
injector. So if something tries to supply `null` for an object, Guice will
refuse to inject it and throw a
[`NULL_INJECTED_INTO_NON_NULLABLE`](NULL_INJECTED_INTO_NON_NULLABLE)
`ProvisionException` error instead. If `null` is permissible by your class, you
can annotate the field or parameter with `@Nullable`.

### Note on `null` injected into `@Provides` method

Due to an oversight, Guice allowed `null` to be injected into
[@Provides methods](ProvidesMethods) in the
past. When this oversight was fixed, an option to control the enforcement level
was added to avoid breaking existing code:

*   `IGNORE`: `null` is allowed to be injected into `@Provides` methods
*   `WARN`: a warning is logged when `null` is injected into a `@Provides`
    method
*   `ERROR`: an error is thrown when when `null` is injected into a `@Provides`
    method

`ERROR` level enforcement is recommended so that:

*   Guice consistently rejects `null` unless `@Nullable` is used
*   `NullPointerException`s are caught early by Guice in all types of injections

Guice by default uses `ERROR` so you don't need to do anything to configure
this. However, if for some reason that you need to relax this enforcement level,
you can do so by setting the JVM property
"-Dguice_check_nullable_provides_params" to either `WARN` or `IGNORE`.

## Supported `@Nullable` annotations

Guice recognizes any `@Nullable` annotation that targets `ElementType.PARAMETER`
(for parameters), `ElementType.FIELD` (for fields), or `TYPE_USE` like
`edu.umd.cs.findbugs.annotations.Nullable`, `javax.annotation.Nullable` or
`org.checkerframework.checker.nullness.qual.Nullable`.

If you've already annotated the injection site with `@Nullable` and still
getting error then it's likely that you are using a type of `@Nullable`
annotation that is not supported by Guice. Consider switching to one of the
supported types.
