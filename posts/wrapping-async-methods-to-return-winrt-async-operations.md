---
title: 'Wrapping async methods to return WinRT async operations'
createdAt: '2019-09-21 14:00'
postedBy: codernr
tags:
    - WinRT
    - 'Universal Windows Platform'
    - 'C#'
    - async
    - threading
---

If you've ever developed any **Universal Windows Platform** app, you may have run into an exception during building it (**WME1038**) that says your public class exposes an async operation that is not compatible with the Windows runtime environment.
The easiest way to avoid this message is to make your class internal instead of public. This is OK if you don't want to expose its functionality outside your app, but what if you're writing a Public API or a shared class library?

If you take a look at some WinRT compatible SDK-s, you can see that the awaitable operations all implement one of the following interfaces: **IAsyncAction**, **IAsyncActionWithProgress&lt;TProgress&gt;**, **IAsyncOperation&lt;TResult&gt;**, or **IAsyncOperationWithProgress&lt;TResult,TProgress&gt;**.

Let's assume you have a simple class with a simple async operation:

```csharp
using System.Threading.Tasks;

public class SimpleClass
{
    public async Task SimpleAction()
    {
		await Task.Delay(1000);
		Debug.WriteLine("Waited one second!");
	}
}
```

How can you make this SimpleAction return the corresponding IAsyncWhatever instead of Task? The solution is the **AsyncInfo** class from the _System.Runtime.InteropServices.WindowsRuntime_ namespace! As the [documentation](https://msdn.microsoft.com/en-us/library/system.runtime.interopservices.windowsruntime.asyncinfo(v=vs.110).aspx) says:

> Provides factory methods to construct representations of managed tasks that are compatible with Windows Runtime asynchronous actions and operations.

The **AsyncInfo.Run** method has four overloads for the above mentioned four types, you have to use the first one for this "void" SimpleAction method. This overload takes one delegate parameter to a function that takes a cancellation token as an argument, so using it you can convert your code this way:

```csharp
using System.Threading.Tasks;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;

public class SimpleClass
{
    public IAsyncAction SimpleAction()
    {
	    return AsyncInfo.Run(async (ct) =>
	    {
			await Task.Delay(1000);
			Debug.WriteLine("Waited one second!");
		});
	}
}
```

Or without using lambda, making your original method private with a CancellationToken parameter and passing it to the new public method as a delegate:

```csharp
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;

public class SimpleClass
{
    public IAsyncAction SimpleAction()
    {
	    return AsyncInfo.Run(this.OriginalSimpleAction);
	}

	private async Task OriginalSimpleAction(CancellationToken ct)
	{
		await Task.Delay(1000);
		Debug.WriteLine("Waited one second!");
	}
}
```

If you want to read a more detailed post about the topic, [you can find an MSDN blog post here](https://blogs.msdn.microsoft.com/windowsappdev/2012/06/14/exposing-net-tasks-as-winrt-asynchronous-operations/).