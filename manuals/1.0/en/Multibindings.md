---
layout: docs-en
title: Multibindings
category: Manual
permalink: /manuals/1.0/en/multibindings.html
---
# Multibindings

_Overview of Multibinder, MapBinder and OptionalBinder_

**NOTE**: Since [Guice 4.2](Guice42), multibindings support has moved to Guice
core. Before that, you need to depend on the `guice-multibindings` extension.


[Multibinder](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/multibindings/Multibinder.html)
and
[MapBinder](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/multibindings/MapBinder.html)
are intended for plugin-type architectures, where you've got several modules
contributing Servlets, Actions, Filters, Components or even just names.

[OptionalBinder](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/multibindings/OptionalBinder.html)
is intended to be used by frameworks to:

*   define an injection point that may or may not be bound by users.
*   supply a default value that can be changed by users.

## Multibinding

Using `Multibinder` or `MapBinder` to host plugins.

### Multibinder

Multibindings make it easy to support plugins in your application. Made popular
by [IDEs](http://www.eclipseplugincentral.com) and
[browsers](https://addons.mozilla.org/en-US/firefox/), this pattern exposes APIs
for extending the behaviour of an application.

Neither the plugin consumer nor the plugin author need write much setup code for
extensible applications with Guice. Simply define an interface, bind
implementations, and inject sets of implementations! Any module can create a new
Multibinder to contribute bindings to a set of implementations. To illustrate,
we'll use plugins to summarize ugly URIs like `http://bit.ly/1mzgW1` into
something readable on Twitter.

First, we define an interface that plugin authors can implement. This is usually
an interface that lends itself to several implementations. For this example, we
would write a different implementation for each website that we could summarize.

```java
interface UriSummarizer {
  /**
   * Returns a short summary of the URI, or null if this summarizer doesn't
   * know how to summarize the URI.
   */
  String summarize(URI uri);
}
```

Next, we'll get our plugin authors to implement the interface. Here's an
implementation that shortens Flickr photo URLs:

```java
class FlickrPhotoSummarizer implements UriSummarizer {
  private static final Pattern PHOTO_PATTERN
      = Pattern.compile("http://www\\.flickr\\.com/photos/[^/]+/(\\d+)/");

  public String summarize(URI uri) {
    Matcher matcher = PHOTO_PATTERN.matcher(uri.toString());
    if (!matcher.matches()) {
      return null;
    } else {
      String id = matcher.group(1);
      Photo photo = lookupPhoto(id);
      return photo.getTitle();
    }
  }
}
```

The plugin author registers their implementation using a multibinder. Some
plugins may bind multiple implementations, or implementations of several
extension-point interfaces.

```java
public class FlickrPluginModule extends AbstractModule {
  public void configure() {
    Multibinder<UriSummarizer> uriBinder = Multibinder.newSetBinder(binder(), UriSummarizer.class);
    uriBinder.addBinding().to(FlickrPhotoSummarizer.class);

    ... // bind plugin dependencies, such as our Flickr API key
  }
}
```

Now we can consume the services exposed by our plugins. In this case, we're
summarizing tweets:

```java
public class TweetPrettifier {

  private final Set<UriSummarizer> summarizers;
  private final EmoticonImagifier emoticonImagifier;

  @Inject TweetPrettifier(Set<UriSummarizer> summarizers,
      EmoticonImagifier emoticonImagifier) {
    this.summarizers = summarizers;
    this.emoticonImagifier = emoticonImagifier;
  }

  public Html prettifyTweet(String tweetMessage) {
    ... // split out the URIs and call prettifyUri() for each
  }

  public String prettifyUri(URI uri) {
    // loop through the implementations, looking for one that supports this URI
    for (UrlSummarizer summarizer : summarizers) {
      String summary = summarizer.summarize(uri);
      if (summary != null) {
        return summary;
      }
    }

    // no summarizer found, just return the URI itself
    return uri.toString();
  }
}
```

_**Note:** The method `Multibinder.newSetBinder(binder, type)` can be confusing.
This operation creates a new binder, but doesn't override any existing bindings.
A binder created this way contributes to the existing Set of implementations for
that type. It would create a new set only if one is not already bound._

Finally we must register the plugins themselves. The simplest mechanism to do so
is to list them programatically:

```java
public class PrettyTweets {
  public static void main(String[] args) {
    Injector injector = Guice.createInjector(
        new GoogleMapsPluginModule(),
        new BitlyPluginModule(),
        new FlickrPluginModule()
        ...
    );

    injector.getInstance(Frontend.class).start();
  }
}
```

If it is infeasible to recompile each time the plugin set changes, the list of
plugin modules can be loaded from a configuration file.

Note that this mechanism cannot load or unload plugins while the system is
running. If you need to hot-swap application components, investigate
[Guice's OSGi](OSGi).

#### Duplicate elements in `Multibinder`

By default `Multibinder` does not allow duplicates and a `DUPLICATE_ELEMENT`
error will be thrown when duplicate elements are added to the `Multibinder`.
Note that Guice itself deduplicates if you bind the same constant value twice,
this error is only thrown if a duplicate is encountered during provisioning,
e.g. when two providers return the same value. To allow duplicates, you can use
`permitDuplicates` API on `Multibinder`:

```java
public class FlickrPluginModule extends AbstractModule {
  @Override
  protected void configure() {
    Multibinder<UriSummarizer> uriBinder =
        Multibinder.newSetBinder(binder(), UriSummarizer.class);
    uriBinder.permitDuplicates();
  }
}
```

### MapBinder

The previous example shows how to bind a `Set<UrlSummarizer>` with multiple
modules using `Multibinder`. Guice also supports binding `Map<K, V>` using
`MapBinder` (e.g a `Map<String, UrlSummarizer`>):

```java
public class FlickrPluginModule extends AbstractModule {
  public void configure() {
    MapBinder<String, UriSummarizer> uriBinder =
        MapBinder.newMapBinder(binder(), String.class, UriSummarizer.class);
    uriBinder.addBinding("Flickr").to(FlickrPhotoSummarizer.class);

    ... // bind plugin dependencies, such as our Flickr API key
  }
}
```

Applications then can inject `Map<String, UriSummarizer>` like:

```java
public class TweetPrettifier {

  private final Map<String, UriSummarizer> summarizers;

  @Inject TweetPrettifier(Map<String, UriSummarizer> summarizers) {
    this.summarizers = summarizers;
    ...
  }
}
```

#### Duplicate keys in `MapBinder`

Like `Multibinder`, `MapBinder` by default does not allow duplicates and a
`DUPLICATE_ELEMENT` error will be thrown when duplicate elements are added to
the `MapBinder`. However, unlike `Multibinder`, the uniqueness requirement is on
the **key** of the entry and not the value.

To allow duplicates, you can use `permitDuplicates` API on `MapBinder`. When
there are duplicate keys, the actual value that ends up in the final `Map` is
unspecified:

```java
public final class FooModule extends AbstractModule {
  @Override
  protected void configure() {
    MapBinder.newMapBinder(binder(), String.class, String.class)
        .permitDuplicates();
  }
}

public final class BarModule extends AbstractModule {
  @ProvidesIntoMap
  @StringMapKey("letter")
  String provideKeyValue() {
    return "a";
  }
}

public final class BazModule extends AbstractModule {
  @ProvidesIntoMap
  @StringMapKey("letter")
  String provideKeyValue() {
    return "b";
  }
}
```

In the above example, the key `letter` in the final `Map<String, String>` may
have value `a` or `b`.

## OptionalBinder

`OptionalBinder` can be used to provide optional bindings.

Frameworks often expose configuration APIs for application developers to
customize the framework's behavior. `OptionalBinder` can make requiring optional
binding easy when Guice bindings are used to customize this type of
configurations.

For example, a web framework might have an API for application to supply an
optional `RequestLogger` to log request and response:

```java
 public class FrameworkLoggingModule extends AbstractModule {
   protected void configure() {
     OptionalBinder.newOptionalBinder(binder(), RequestLogger.class);
   }
 }
```

With this module, an `Optional<RequestLogger>` can be injected by the framework
code to log the request and response after processing a request:

```java
public class RequestHandler {
  private final Optional<RequestLogger> requestLogger;

  @Inject
  RequestHandler(Optional<RequestLogger> requestLogger) {
    this.requestLogger = requestLogger;
  }

  void handleRequest(Request request) {
    Response response = ...;
    if (requestLogger.isPresent()) {
      requestLogger.get().logRequest(request, response);
    }
  }
}
```

When the application doesn't provide a `RequestLogger`, no logging is done. If
the application installs a module like:

```java
public class ConsoleLoggingModule extends AbstractModule {
  @Provides
  RequestLogger provideRequestLogger() {
    return new ConsoleLogger(System.out);
  }
}
```

The framework code will get a present value that contains an instance of
`ConsoleLogger` to log the request and response.

### OptionalBinder with a default

In the above example, a `RequestLogger` is optional to the framework but that is
not always the case. When a binding is required, the framework can use
`OptionalBinder` to set a default binding that can be overidden by the
application:

```java
public class FrameworkLoggingModule extends AbstractModule {
 protected void configure() {
   OptionalBinder.newOptionalBinder(binder(), RequestLogger.class)
       .setDefault()
       .to(DefaultRequestLoggerImpl.class);
 }
}
```

With the above module, the framework's default `DefaultRequestLoggerImpl` is
used when no application binding for `RequestLogger` is supplied.

### Overriding the default

If one module uses `setDefault` the only way to override the default is to use
`setBinding`. It is an error for a user to specify the binding without using
`OptionalBinder` if `setDefault` or `setBinding` are called.

So to override the framework's default logger binding, application can install a
module like:

```java
public class ConsoleLoggingModule extends AbstractModule {
  @Override
  protected void configure() {
    OptionalBinder.newOptionalBinder(binder(), RequestLogger.class)
        .setBinding()
        .to(ConsoleLogger.class);
  }
}
```

## Using @Provides-like methods

Besides using the `Multibinder` and `MapBinder` to create multibindings in a
module's `configure` method, you can also use @Provides-like methods to add
bindings to a `Multibinder`, `MapBinder` or `OptionalBinder`.

### ProvidesIntoSet

```java
public class FlickrPluginModule extends AbstractModule {
  @ProvidesIntoSet
  UriSummarizer provideFlickerUriSummarizer() {
    return new FlickrPhotoSummarizer(...);
  }
}
```

### ProvidesIntoMap

```java
public class FlickrPluginModule extends AbstractModule {
  @StringMapKey("Flickr")
  @ProvidesIntoMap
  UriSummarizer provideFlickrUriSummarizer() {
    return new FlickrPhotoSummarizer(...);
  }
}
```

`@ProvidesIntoMap` requires an extra annotation to specify the key associated
with the binding. The above example uses `@StringMapKey` annotation, which is
one of the built-in annotations that can be used with `@ProvidesIntoMap`, to
associate the binding provided by `provideFlickerUriSummarizer` with the key
`"Flickr"`.

You can create custom annotation that can be used with `@ProvidesIntoMap` by
annotating an annotation with `MapKey` annotation like:

```java
@MapKey(unwrapValue=true)
@Retention(RUNTIME)
public @interface MyCustomEnumKey {
  MyCustomEnum value();
}
```

If `unwrapValue = true`, then the value of the custom annotation is used as the
key of the map, otherwise the whole annotation is used as the key. The above
example of `MyCustomEnumKey` has `unwrapValue = true`, so the corresponding
`MapBinder` uses `MyCustomEnum` as the key instead of `MyCustomEnumKey` itself.

### ProvidesIntoOptional

Framework code can use
`@ProvidesIntoOptional(ProvidesIntoOptional.Type.DEFAULT)` to provide a default
binding and application code can use
`@ProvidesIntoOptional(ProvidesIntoOptional.Type.ACTUAL)` to override the
default binding.

```java
public class FrameworkModule extends AbstractModule {
  @ProvidesIntoOptional(ProvidesIntoOptional.Type.DEFAULT)
  @Singleton
  RequestLogger provideConsoleLogger() {
    return new DefaultRequestLoggerImpl();
  }
}
```

```java
public class RequestLoggingModule extends AbstractModule {
  @ProvidesIntoOptional(ProvidesIntoOptional.Type.ACTUAL)
  @Singleton
  RequestLogger provideConsoleLogger() {
    return new ConsoleLogger(System.out);
  }
}
```

**NOTE**: Currently `@ProvidesIntoOptional` can't be used to create an
absent/empty optional binding and `OptionalBinder.newOptionalBinder` must be
used instead.

## Limitations

When you use `PrivateModule`s with multibindings, all of the elements must be
bound in the same environment. You cannot create collections whose elements span
private modules. Otherwise injector creation will fail.

## Inspecting Multibindings

_(new in Guice 3.0)_

Sometimes you need to inspect the elements that make up a Multibinder or
MapBinder. For example, you may need a test that strips all elements of a
MapBinder out of a series of modules. You can visit a binding with a
[MultibindingsTargetVisitor](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/multibindings/MultibindingsTargetVisitor.html)
to get details about Multibindings or MapBindings. After you have an instance of
a
[MapBinderBinding](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/multibindings/MapBinderBinding.html)
or a
[MultibinderBinding](http://google.github.io/guice/api-docs/latest/javadoc/com/google/inject/multibindings/MultibinderBinding.html)
you can learn more.

```java
   // Find the MapBinderBinding and use it to remove elements within it.
   Module stripMapBindings(Key<?> mapKey, Module... modules) {
     MapBinderBinding<?> mapBinder = findMapBinder(mapKey, modules);
     List<Element> allElements = Lists.newArrayList(Elements.getElements(modules));
     if (mapBinder != null) {
       List<Element> mapElements = getMapElements(mapBinder, modules);
       allElements.removeAll(mapElements);
     }
     return Elements.getModule(allElements);
  }

  // Look through all Elements in the module and, if the key matches,
  // then use our custom MultibindingsTargetVisitor to get the MapBinderBinding
  // for the matching binding.
  MapBinderBinding<?> findMapBinder(Key<?> mapKey, Module... modules) {
    for(Element element : Elements.getElements(modules)) {
      MapBinderBinding<?> binding =
          element.acceptVisitor(new DefaultElementVisitor<MapBinderBinding<?>>() {
            MapBinderBinding<?> visit(Binding<?> binding) {
              if(binding.getKey().equals(mapKey)) {
                return binding.acceptTargetVisitor(new Visitor());
              }
              return null;
            }
          });
      if (binding != null) {
        return binding;
      }
    }
    return null;
  }

  // Get all elements in the module that are within the MapBinderBinding.
  List<Element> getMapElements(MapBinderBinding<?> binding, Module... modules) {
    List<Element> elements = Lists.newArrayList();
    for(Element element : Elements.getElements(modules)) {
      if(binding.containsElement(element)) {
        elements.add(element);
      }
    }
    return elements;
  }

  // A visitor that just returns the MapBinderBinding for the binding.
  class Visitor
      extends DefaultBindingTargetVisitor<Object, MapBinderBinding<?>>
      implements MultibindingsTargetVisitor<Object, MapBinderBinding<?>> {
    MapBinderBinding<?> visit(MapBinderBinding<?> mapBinder) {
      return mapBinder;
    }

    MapBinderBinding<?> visit(MultibinderBinding<?> multibinder) {
      return null;
    }
  }
```
