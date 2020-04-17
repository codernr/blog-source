---
title: 'Render Razor view from a dotnet core 3 console app'
createdAt: '2020-04-17 12:45'
excerpt: 'Razor views a strongly coupled to aspnet core mvc but you can use them in a console app with this minimum setup.'
postedBy: codernr
tags:
  - 'dotnet core'
  - 'razor'
  - 'aspnet mvc'
  - 'console application'
---

My colleague and I were wondering how we could use our existing, predefined Razor views in a console application that is ran to do some background job. Typical use case: automated regular email sending. We were searching for the solution but all we found were examples of this case in __dotnet core 2.1__. So we had to do some investigation on how to upgrade to __netcoreapp3.1__.

The example project was one of the [aspnet entropy](https://github.com/aspnet/Entropy) experimental repository: https://github.com/aspnet/Entropy/tree/master/samples/Mvc.RenderViewToString

You can find the source of the updated project in my repo: https://github.com/codernr/dotnet-mvc-renderviewtostring

### Differences

Long story short, you can see all the changes needed to be made [in this commit](https://github.com/codernr/dotnet-mvc-renderviewtostring/commit/b852f6d48f65dcb608f3bb007934117a6e41bc05). But let's see the inside:

#### The .csproj file

As the [documentation says](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/target-aspnetcore?view=aspnetcore-3.1&tabs=visual-studio#razor-views-or-razor-pages), _A project that includes Razor views or Razor Pages must use the Microsoft.NET.Sdk.Razor SDK._ In addition you have to set `AddRazorSupportForMvc` property to `true` and include the `FrameworkReference` for the [1shared framework](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/metapackage-app?view=aspnetcore-3.1). The whole .csproj file looks like this:

```xml
<Project Sdk="Microsoft.NET.Sdk.Razor">

  <PropertyGroup>
    <OutputType>exe</OutputType>
    <TargetFramework>netcoreapp3.1</TargetFramework>
    <AddRazorSupportForMvc>true</AddRazorSupportForMvc>
  </PropertyGroup>

  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
  </ItemGroup>

</Project>
```

#### The main program

The way you can configure `RazorViewEngine` has changed since dotnet core 2.1, now you can't set the `FileProvider` through `RazorViewEngineOptions`. This is set through `IWebHostEnvironment.ContentRootFileProvider`, where `IWebHostEnvironment` is the dependency that replaces the old `IHostingEnvironment` (you can check the diff [here](https://github.com/codernr/dotnet-mvc-renderviewtostring/commit/b852f6d48f65dcb608f3bb007934117a6e41bc05#diff-34cffdae1474e839ffac88fe019a0155L74)). Since the implementing classes are internal, you have to create a custom implementation and add it to the service collection.

There are two other changes in the DI configuration that are needed for the `RazorViewEngine` to work:

* A `DiagnosticListener`
* And insted of `services.AddMvc()` it is enough to use `services.AddMvcCore().AddRazorViewEngine()` so you can reduce the registered services

See the whole dependency injection container setup here:

```cs
private static void ConfigureDefaultServices(IServiceCollection services, string customApplicationBasePath)
{
    string applicationName;
    string rootPath;

    if (!string.IsNullOrEmpty(customApplicationBasePath))
    {
        applicationName = Path.GetFileName(customApplicationBasePath);
        rootPath = customApplicationBasePath;
    }
    else
    {
        applicationName = Assembly.GetEntryAssembly().GetName().Name;
        rootPath = Directory.GetCurrentDirectory();
    }

    var fileProvider = new PhysicalFileProvider(rootPath);

    var environment = new CustomHostingEnvironment
    {
        WebRootFileProvider = fileProvider,
        ApplicationName = applicationName,
        ContentRootPath = rootPath,
        WebRootPath = rootPath,
        EnvironmentName = "DEVELOPMENT",
        ContentRootFileProvider = fileProvider
    };

    services.AddSingleton<IWebHostEnvironment>(environment);

    var diagnosticSource = new DiagnosticListener("Microsoft.AspNetCore");
    services.AddSingleton<ObjectPoolProvider, DefaultObjectPoolProvider>();
    services.AddSingleton<DiagnosticSource>(diagnosticSource);
    services.AddSingleton<DiagnosticListener>(diagnosticSource);
    services.AddLogging();
    services.AddMvcCore()
        .AddRazorViewEngine();
    services.AddTransient<RazorViewToStringRenderer>();
}
```

Happy email sending!