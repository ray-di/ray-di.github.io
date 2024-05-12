require 'fileutils'

file_list = [
    "Motivation",
    "GettingStarted",
    "MentalModel",
    "Scopes",
    "Bindings",
    "LinkedBindings",
    "BindingAttributes",
    "InstanceBindings",
    "ProviderBindings",
    "UntargetedBindings",
    "ConstructorBindings",
    "BuiltinBindings",
    "Multibindings",
    "ContextualBindings",
    "NullObjectBinding",
    "Injections",
    "InjectingProviders",
    "ObjectLifeCycle",
    "AOP",
    "BestPractices",
    "Grapher",
    "Integration",
    "PerformanceBoost",
    "BackwardCompatibility",
    "Tutorial1"
]

file_list.each_with_index do |filename, i|
    old_file_path = "#{filename}.md"
    new_file_path = "#{(i+1)*10}.#{filename}.md"
    FileUtils.mv(old_file_path, new_file_path)
end
