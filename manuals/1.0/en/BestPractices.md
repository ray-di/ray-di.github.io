# Guice Best Practices

*   [Minimize mutability](MinimizeMutability)
*   [Inject only direct dependencies](InjectOnlyDirectDependencies)
*   [Use the Injector as little as possible (preferably only once)](InjectingTheInjector)
*   [Avoid cyclic dependencies](CyclicDependencies)
*   [Avoid static state](AvoidStaticState)
*   [Use `@Nullable`](UseNullable)
*   [Modules should be fast and side-effect free](ModulesShouldBeFastAndSideEffectFree)
*   [Be careful about I/O in Providers](BeCarefulAboutIoInProviders)
*   [Avoid conditional logic in modules](AvoidConditionalLogicInModules)
*   [Keep constructors as hidden as possible](KeepConstructorsHidden)
*   [Avoid binding Closable resources](Avoid-Injecting-Closable-Resources)
*   [Prefer `@Provides` methods over the binding DSL](PreferAtProvides)
*   [Avoid calling `@Provides` methods and `@Inject` constructors directly](AvoidCallingProvideMethodsAndInjectConstructors)
*   [Don't reuse binding annotations (aka `@Qualifiers`)](DontReuseAnnotations)
*   [Organize modules by feature, not by class type](OrganizeModulesByFeature)
*   [Document the public bindings provided by modules](DocumentPublicBindings)

<!-- TODO(xiaomingjia): Add best practices on avoid using anti-patterns in
     Guice, such as Modules.override, PrivateModule etc. -->
