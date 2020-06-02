---
title: 'Registering decorators in ASP.NET Core DI'
createdAt: '2020-06-03 12:30'
excerpt: 'This post shows how you can register multiple classes that implement the same interface and decorate each other in ASP.NET Core dependency injection container'
postedBy: codernr
tags:
  - 'asp.net core'
  - 'dependency injection'
  - 'decorator pattern'
  - 'dotnet core'
---

There are tons of articles about [why you should avoid inheritance](https://codeburst.io/inheritance-is-evil-stop-using-it-6c4f1caf5117) when you can, how [hard it makes readability of code and maintainability](http://neethack.com/2017/04/Why-inheritance-is-bad/) of large projects, and how you can substitute it with, for example, using [composition](https://medium.com/better-programming/composition-over-inheritance-b58264af8c21) or [decorator](https://dzone.com/articles/is-inheritance-dead) pattern. The subject of this post is not to discuss these topics but to show how you can use decorator pattern in ASP.NET Core and register multiple classes implementing the same interface (and decorating each other) in its dependency injection container.

### Basic implementation

Let's see a simple example: you have a service that sends an `HttpRequestMessage` to an API, call it `IServiceClient`, and it has a basic implementation that instantiates an HttpClient and sends the message with it then returns the response:

```cs
public interface IServiceClient
{
    Task<HttpResponseMessage> SendAsync(HttpRequestMessage message);
}

public class BasicServiceClient : IServiceClient
{
    private readonly IHttpClientFactory clientFactory;

    public BasicServiceClient(IHttpClientFactory clientFactory) => this.clientFactory = clientFactory;

    public Task<HttpResponseMessage> SendAsync(HttpRequestMessage message)
    {
        var client = this.clientFactory.CreateClient();

        return client.SendAsync(message);
    }
}
```

### When extra functionality is needed

Let's say you have two different environments that need two different authentication method. One uses an api key that is sent in `X-Api-Key` header, the other uses a bearer token in the `Authentication` header. Then numerous headers must be set in each environment with different permutations, so inheritance is not an option to avoid repetiton, you have to use decorators for dynamically set every header. But for the sake of simplicity we use only those two decorators:

```cs
public class ApiKeyServiceClient : IServiceClient
{
    private readonly BasicServiceClient serviceClient;

    public ApiKeyServiceClient(BasicServiceClient serviceClient) => this.serviceClient = serviceClient;

    public Task<HttpResponseMessage> SendAsync(HttpRequestMessage message)
    {
        message.Headers.Add("X-Api-Key", "myapikey");

        return this.serviceClient.SendAsync(message);
    }
}

public class BearerTokenServiceClient : IServiceClient
{
    private readonly BasicServiceClient serviceClient;

    public ApiKeyServiceClient(BasicServiceClient serviceClient) => this.serviceClient = serviceClient;

    public Task<HttpResponseMessage> SendAsync(HttpRequestMessage message)
    {
        message.Headers.Add("Authorization", "Bearer mytoken...");

        return this.serviceClient.SendAsync(message);
    }
}
```

So now you can configure your service collection like this:

```cs
var services = new ServiceCollection();
services.AddHttpClient();
services.AddSingleton<ServiceClient>();

if (isBearerTokenAuthentication)
{
    services.AddSingleton<IServiceClient, BearerTokenServiceClient>();
}
else
{
    services.AddSingleton<IServiceClient, ApiKeyServiceClient>();
}
```

### The problem with direct dependency

The problem with this approach is that you use direct type dependency in your authorization header decorator implementations so they are no better than using inheritance. You can easily fix this by using interfaces as dependencies:

```cs
public class ApiKeyServiceClient : IServiceClient
{
    private readonly IServiceClient serviceClient;

    public ApiKeyServiceClient(IServiceClient serviceClient) => this.serviceClient = serviceClient;

    public Task<HttpResponseMessage> SendAsync(HttpRequestMessage message)
    {
        message.Headers.Add("X-Api-Key", "myapikey");

        return this.serviceClient.SendAsync(message);
    }
}

public class BearerTokenServiceClient : IServiceClient
{
    private readonly IServiceClient serviceClient;

    public ApiKeyServiceClient(IServiceClient serviceClient) => this.serviceClient = serviceClient;

    public Task<HttpResponseMessage> SendAsync(HttpRequestMessage message)
    {
        message.Headers.Add("Authorization", "Bearer mytoken...");

        return this.serviceClient.SendAsync(message);
    }
}
```

Now you can use them in any decorator chain, you could even use them together to add api key and bearer tokens to the same HttpRequestMessage. That doesn't make much sense in real world, but let's say you want all that headers now on the same message. Now you have to register **three** implementations of **the same** interface and you want them to be chained in an exactly defined order. ASP.NET Core dependency injection allows you to register multiple implementations with the same interface but then it won't figure out which to inject in which constructor so you have to explicitly define how they are injected.

### The solution 

Some more complex dependency injection containers like Unity allow named dependencies and other tools to differentiate, but in my opinion these can easily lead to misuse of these containers and accidentally implementing anti-patterns like service locator. Fortunately the .NET Core minimal DI toolset doesn't navigate you in the wrong direction, since you can implement the desired behavior only by using **factory methods**:

```cs
var services = new ServiceCollection();

services.AddHttpClient();

services.AddSingleton<IServiceClient>(
    serviceProvider => new BearerTokenServiceClient(
        new ApiKeyServiceClient(
            new ServiceClient(serviceProvider.GetRequiredService<IHttpClientFactory>()))));
```

As you can see, you can instantiate the decorator chain in the desired order injecting them in each other as you want. Every other dependencies that are registered and needed by them can be reached in the factory method from the service provider.

### Summary

ASP.NET Core dependency injetion allows us to follow good programming practices and build code that can be dynamically configured. I'm convinced that usage of decorator pattern can be a huge benefit even in little projects. Let me know in the comments if you have similar good practices to follow regarding dependency injection.