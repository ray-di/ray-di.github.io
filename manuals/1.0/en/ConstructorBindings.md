---
layout: docs-en
title: Constructor Bindings
category: Manual
permalink: /manuals/1.0/en/constructor_bindings.html
---
## Constructor Bindings

When `#[Inject]` attribute cannot be applied to the target constructor or setter method because it is a third party class, Or you simply don't like to use annotations. `Constructor Binding` provide the solution to this problem. By calling your target constructor explicitly, you don't need reflection and its associated pitfalls. But there are limitations of that approach: manually constructed instances do not participate in AOP.

To address this, Ray.Di has `toConstructor` bindings.

```php
$this->bind($interfaceName)
    ->toConstructor(
        $className,       // Class name
        $name,            // Qualifier
        $injectionPoint,  // Setter injection
        $postConstruct    // Initialize method
    );

(new InjectionPoints) 
    ->addMethod('setGuzzle')                 // Setter injection method name
    ->addOptionalMethod('setOptionalToken'); // Optional setter injection method name
```

### Parameter

**class_name**

Class name

**name**

Parameter name binding.

If you want to add an identifier to the argument, specify an array with the variable name as the key and the value as the name of the identifier.


```
[
	[$param_name1 => $binding_name1],
	...
]
```
The following string formats are also supported

`'param_name1=binding_name1&...'`

**setter_injection**

Specify the method name ($methodName) and qualifier ($named) of the setter injector in the `InjectionPoints` object.

```php
(new InjectionPoints)
	->addMethod($methodName1)
	->addMethod($methodName2, $named)
    ->addOptionalMethod($methodName, $named);
```

**postCosntruct**

Ray.Di will invoke that constructor and setter method to satisfy the binding and invoke in `$postCosntruct` method after all dependencies are injected.

### PDO Example

Here is the example for the native [PDO](http://php.net/manual/ja/pdo.construct.php) class.

```php
public PDO::__construct ( string $dsn [, string $username [, string $password [, array $options ]]] )
```

```php
$this->bind(\PDO::class)->toConstructor(
  \PDO::class,
  [
    'dsn' => 'pdo_dsn',
    'username' => 'pdo_username',
    'password' => 'pdo_password'
  ]
)->in(Scope::SINGLETON);
$this->bind()->annotatedWith('pdo_dsn')->toInstance($dsn);
$this->bind()->annotatedWith('pdo_username')->toInstance(getenv('db_user'));
$this->bind()->annotatedWith('pdo_password')->toInstance(getenv('db_password'));
```

Since no argument of PDO has a type, it binds with the `Name Binding` of the second argument of the `toConstructor()` method.
In the above example, the variable `username` is given the identifier `pdo_username`, and `toInstance` binds the value of the environment variable.
