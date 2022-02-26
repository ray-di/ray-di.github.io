# Be careful about I/O in Providers

The `Provider` interface is convenient for the caller, but it lacks semantics:

*   **Provider doesn't declare checked exceptions.** If you're writing code that
    needs to recover from specific types of failures, you can't catch
    `TransactionRolledbackException`. `ProvisionException` allows you to recover
    from general provision failures, and you can
    [iterate its causes](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/ProvisionException.html#getErrorMessages\(\)),
    but you can't specify what those causes may be.
*   **Provider doesn't support a timeout.**
*   **Provider doesn't define a retry-strategy.** When a value is unavailable,
    calling `get()` multiple times may cause multiple failed provisions.

[ThrowingProviders](ThrowingProviders) is a Guice extension that implements an
exception-throwing provider. It allows failures to be scoped, so a failed lookup
only happens once per request or session.
