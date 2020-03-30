---
title: 'Mocking sealed classes in C#'
createdAt: 2020-03-26 
excerpt: 'How to wrap sealed classes with custom classes that implement mockable interface'
tags:
    - 'C#'
    - Azure
    - 'Unit test'
    - Mocking
    - 'Dependency injection'
postedBy: codernr
---

> Roses are red  
> violets are blue  
> mocking a sealed class  
> is painful in Azure

So you decided to start a new Azure project and you swear this time you won't skip writing unit tests, using dependency injection and all the fancy shit cool programmers do, right? Then you run into the realities of some Azure SDK like me (_or any other_) and realize that most of the classes are sealed and they don't even implement a public interface. This is a problem, since most of the mocking frameworks can mock only interfaces.

===

Let's see an example with an imaginary SDK class, and a property-injected utility class that uses it:

```csharp
public sealed class SDKClass
{
	public void DoSomeAwesomeSDKStuff()
	{
		Console.WriteLine("I'm doing some Awesome SDK stuff!");
	}
}

public class UtilityClass
{
	public SDKClass SDKTool { get; set; }
	
	public void UsingSDK()
	{
		this.SDKTool.DoSomeAwesomeSDKStuff();
	}
}
```

If you want to unit test your `UsingSDK` method you have to mock `SDKClass` property somehow. Since it doesn't implement any (public) interface, you can only achieve this by creating a wrapper class and defining an interface that your wrapper implements. This way you can type your SDKTool property as the implemented interface:

```csharp
// the interface to be implemented
public interface ISDKInterface
{
	void DoSomeAwesomeSDKStuff();
}

// the wrapper class that implements the interface
public class SDKWrapper : ISDKInterface
{
	private SDKClass wrappedInstance;

	public void SDKWrapper()
	{
		this.wrappedInstance = new SDKClass();
	}

	public void DoSomeAwesomeSDKStuff()
	{
		this.wrappedInstance.DoSomeAwesomeSDKStuff();
	}
}

// typing SDKTool property as ISDKInterface
public class UtilityClass
{
    public ISDKInterface SDKTool { get; set; }

    public void UsingSDK()
    {
        this.SDKTool.DoSomeAwesomeSDKStuff();
    }
}
``` 

So this time when you property inject `UtilityClass`, you have to inject an instance of `SDKWrapper` instead of `SDKClass`. And during unit testing, you can mock the ISDKInterface!