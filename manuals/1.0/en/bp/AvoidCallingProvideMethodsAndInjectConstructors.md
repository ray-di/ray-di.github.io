# Avoid calling `@Provides` methods or `@Inject` constructors directly

If your injector knows how to create a certain class instance, your production
code should not have the need to manually call its constructor (or its
`@Provides` method, which is just a factory for that class). Doing so, at best,
results in more boilerplate and code that is harder to refactor (e.g. when you
need to change the signature of a constructor); it may also lead to confusion
and outright bugs (e.g. creating an instance manually would bypass the object's
lifecycle management performed by Guice, see [Scopes documentation](Scopes)).

TIP: To avoid leaking those APIs and limit the chances that some other code
might call those APIs directly, make those APIs package private.

Note that you may still want to call the constructors from a unit test for that
class.

Unit-testing an `@Provides` method may also be justifiable (though rarely
necessary since provides-methods should be simple glue code, not business
logic), but it should most likely be done by using an injector.
