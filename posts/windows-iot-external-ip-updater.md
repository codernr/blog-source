---
title: 'Windows IoT external IP updater'
createdAt: '2016-09-30'
excerpt: 'Creating a Windows 10 core IoT background application that periodically checks the external IP and notifies in email if changed'
postedBy: codernr
tags:
    - WinRT
    - 'Universal Windows Platform'
    - 'Raspberry Pi'
    - 'Windows 10 core IoT'
    - 'C#'
---

In my home project I work a lot with **Raspberry Pi**s running **Windows 10 core IoT** system. Recently I put up an RPi at home, and I wanted to be able to manage it remotely via the device portal and powershell, so I wanted to be updated about the external IP of my device. I didn't want to use any backend, neither a dynamic dns provider nor a server with a DB constantly updated so I wrote a little app that runs in the background and regularly checks if the external IP has changed, and notify me in email about it. It came out that this little project can be a field of experiencing and learning a lot!

To make this app work, I created a list of that I'd need for it:

* [creating UWP background task that runs continuosly](#background-task)
* [handling config file locally with JSON](#config)
* [reading the content of a website that displays the external IP](#external-ip)
* [sending an email with SMTP](#email)
* [running the process periodically](#periodic-run)
* [retrying if an exception occurs](#retry)

> You can find the whole source code in my GitHub so I will show only parts of it here
>
> Repository: [https://github.com/codernr/ipwatcher](https://github.com/codernr/ipwatcher)

##### The background task <a id="background-task"></a>

To create a Windows IoT background task, you have to create a class that implements the `IBackgroundTask` interface. To make it run continuosly, you have to take a deferral in the `Run` method from the given `IBackgroundTaskInstance` parameter:

```csharp
using Windows.ApplicationModel.Background;

namespace IPWatcher
{
    public sealed class StartupTask : IBackgroundTask
    {
        private BackgroundTaskDeferral deferral;

        public void Run(IBackgroundTaskInstance taskInstance)
        {
            this.deferral = taskInstance.GetDeferral();
        }
    }
}
```

That's pretty much it!

> Find a complete guide on background tasks on [the microsoft developer portal](https://developer.microsoft.com/en-us/windows/iot/docs/backgroundapplications)

##### The config file <a id="config"></a>

I wrote a tiny singleton `Config` class with a bunch of public properties that were gonna be loaded from a config JSON. I had to create only two methods, `CreateInstance` that deserializes the app's `LocalState/config.json` to these properties and a `SaveInstance` that serializes the modified object back to JSON.

> To easily serialize/deserialize objects from JSON you can use the [Newtonsoft.Json NuGet package](https://www.nuget.org/packages/Newtonsoft.Json/)

I copy only the methods here, you can find the whole source on [GitHub](https://github.com/codernr/ipwatcher/blob/master/IPWatcher/Config.cs)

```csharp
using System;
using System.Threading.Tasks;
using Windows.Storage;

public static async Task CreateInstance()
{
    file = await ApplicationData.Current.LocalFolder.GetFileAsync(fileName);

    var content = await FileIO.ReadTextAsync(file);

    Instance = JsonConvert.DeserializeObject<Config>(content);
}

public static async Task SaveInstance()
{
    var content = JsonConvert.SerializeObject(Instance, Formatting.Indented);

    await FileIO.WriteTextAsync(file, content);
}
```

> Read more about storing and retrieving app data [on the MSDN site](https://msdn.microsoft.com/en-us/windows/uwp/app-settings/store-and-retrieve-app-data)

A sample `config.json` file looks like this:

```json
{
  "DeviceName": "MyDeviceName",
  "UpdateHours": 12,
  "ExternalIPCheckAddress": "http://icanhazip.com/",
  "Recipient": "your.email@address.com",
  "SmtpServer": "smtp.gmail.com",
  "Port": 465,
  "Ssl": true,
  "Username": "sender.email@gmail.com",
  "Password": "sender.password",
  "EmailSubject": "Device IP changed!",
  "EmailBodyFormat": "The IP address of {0} has changed to {1}",
  "RetryCount": 5,
  "RetryBaseSeconds": 3,
  "IpAddress": "0.0.0.0"
}
```

As you can see, all of these parameters are preconfigured except the last one, the `IpAddress` that is going to be changed by the app.

> Important: you have to manually put the config.json to the app LocalState folder, otherwise you will get a FileNotFoundException when instantiating the config object!

##### Reading the external IP <a id="external-ip"></a>

The simplest way to get your external IP is to read a plain text "what's my ip" page like [http://icanhazip.com/](http://icanhazip.com/). To achieve this you can use the `HttpClient` class. I wanted to catch exceptions if there's any and return null so i called `EnsureSuccessStatusCode()` on the response object:

```csharp
using System.Threading.Tasks;
using Windows.Web.Http;

// ...

private async Task<string> GetExternalIP()
{
	HttpClient client = new HttpClient();

	string body;

	try
	{
		var response = await client.GetAsync(new Uri(Config.Instance.ExternalIPCheckAddress));
		response.EnsureSuccessStatusCode();
		body = await response.Content.ReadAsStringAsync();
		body = body.TrimEnd('\n');
	}
	catch (Exception ex)
	{
		Debug.WriteLine(ex.Message);
		body = null;
	}

	return body;
}
```

##### Sending the email <a id="email"></a>

I couldn't use the `System.Net.Mail` namespace in my project since it is not part of the UWP platform. In a mobile UWP app you can only launch the default email app to compose a new message, you can't send it directly inside the app. So I searched for a solution and found the [LightBuzz WinRT SMTP client package](https://github.com/LightBuzz/SMTP-WinRT) that solved my problem:

```csharp
using System.Threading.Tasks;
using LightBuzz.SMTP;
using Windows.ApplicationModel.Email;

// ...

private async Task SendMail(string ip)
{
	using (SmtpClient client = new SmtpClient(Config.Instance.SmtpServer, Config.Instance.Port, Config.Instance.Ssl, Config.Instance.Username, Config.Instance.Password))
	{
		EmailMessage message = new EmailMessage();

		message.To.Add(new EmailRecipient(Config.Instance.Recipient));
		message.Subject = Config.Instance.EmailSubject;
		message.Body = string.Format(Config.Instance.EmailBodyFormat, Config.Instance.DeviceName, ip);

		await client.SendMail(message);
	}
}
```

Just a few lines and I can send emails like Hillary Clinton!

> If you use Gmail SMTP you shoul keep in mind this ([as written on the package GitHub](https://github.com/LightBuzz/SMTP-WinRT)):
>
> Since this does not use OAUTH2, Gmail considers this a "less secure app".  To use this with Gmail, the "Access for less secure apps" setting on the account will have to be changed to "Enable".

##### Running periodically <a id="periodic-run"></a>

The external IP address doesn't change frequently so the it's enough to check it for example every 24 hour (by the way it's configurable through `config.json`). I concatenated the process (check IP / send email if changed) in a `Check` method and set a `ThreadPoolTimer` to run it periodically:

```csharp
using System.Diagnostics;
using System.Threading.Tasks;
using Windows.System.Threading;

// ...

public void Run(IBackgroundTaskInstance taskInstance)
{
	this.deferral = taskInstance.GetDeferral();

	this.Initialize();
}

private async Task Initialize()
{
	// config has to be created asynchronously because of the file read
	await Config.CreateInstance();

	// running check for the first time
	this.Check();

	// and then start the timer to call it periodically
	ThreadPoolTimer.CreatePeriodicTimer(this.Check, TimeSpan.FromHours(Config.Instance.UpdateHours));
}

private async void Check(ThreadPoolTimer timer = null)
{
	var ip = await this.GetExternalIP();

	// no IP address change, no notification
	if (ip == Config.Instance.IpAddress)
	{
		Debug.WriteLine("IP address hasn't changed, returning");
		return;
	}

	await this.SendMail(ip);

	// save new IP to config
	Config.Instance.IpAddress = ip;

	await Config.SaveInstance();
}
```

##### Handling exceptions <a id="retry"></a>

I have two points in the application where it uses network connection, checking the IP and sending the mail. If there is network connection, there is error source so it should be handled. There are a lot of articles about *transient fault handling* [I recommend this MSDN article](https://msdn.microsoft.com/en-us/library/hh680901(v=pandp.50).aspx) if you're new to this topic.

So back to the app, I had two cases where a retry policy is useful if any exception occurs (e.g. no internet connection at the moment). I didn't use the Microsoft Transient Fault Handling Application Block from the above mentioned article, but chose the Polly Nuget package that seems a bit more user friendly to me.

> Visit the Polly GitHub page for documentation: [https://github.com/App-vNext/Polly](https://github.com/App-vNext/Polly)

Let's see the extended `Check` method with Polly:

```csharp
using System.Diagnostics;
using System.Threading.Tasks;
using Polly;

// ...

private async void Check(ThreadPoolTimer timer = null)
{
	var ip = await Policy
		.HandleResult<string>(s => s == null)
		.WaitAndRetryAsync<string>(Config.Instance.RetryCount, this.RetryExponential, this.LogIPRetry)
		.ExecuteAsync(this.GetExternalIP);

	// if the ip is still null after the retries, wait for the next cycle
	if (ip == null)
	{
		Debug.WriteLine("All IP check attempt failed, wait for next cycle");
		return;
	}

	// no IP address change, no notification
	if (ip == Config.Instance.IpAddress)
	{
		Debug.WriteLine("IP address hasn't changed, returning");
		return;
	}

	var policyResult = await Policy
		.Handle<Exception>()
		.WaitAndRetryAsync(Config.Instance.RetryCount, this.RetryExponential, this.LogMailRetry)
		.ExecuteAndCaptureAsync(() => this.SendMail(ip));

	// email send fail, wait for next cycle
	if (policyResult.Outcome == OutcomeType.Failure)
	{
		Debug.WriteLine("All mail send attempt failed, wait for next cycle");
		return;
	}

	// success, save new IP to config
	Config.Instance.IpAddress = ip;

	await Config.SaveInstance();
}

// ...

private TimeSpan RetryExponential(int retryAttempt)
{
	return TimeSpan.FromSeconds(Math.Pow(Config.Instance.RetryBaseSeconds, retryAttempt));
}

private async Task LogIPRetry(DelegateResult<string> result, TimeSpan time, int retryCount, Context onRetry)
{
	Debug.WriteLine("{0}. Failed IP check attempt, retrying in {1}", retryCount, time);
}

private async Task LogMailRetry(Exception ex, TimeSpan time)
{
	Debug.WriteLine("Failed email send attempt, retrying in {0}", time);
}
```

Let's see first the `RetryExponential` method: this is the provider method that tells the retry policy after how much time it has to retry the operation. I implemented a basic exponential back-off strategy meaning that the waiting time grows exponentially after each retrial.

So first I defined the retry policy for my `GetExternalIP` method. There is a try/catch block inside the method so all the exceptions are caught inside it, and the only sign of a failed operation is a null return value. Fortunately Polly has a `HandleResult` method that can check the return value and decide if it is null and if it has to rerun the method. If you disable your internet connection and run the app you can see the retrial process yourself. Assuming that you set 2 seconds for `Config.RetryBaseSeconds` and 4 for `Config.RetryCount` it seems something like this:

1. calling `GetExternalIP`
2. returns null, policy waits for 2^1 = 2 seconds
3. calling `GetExternalIP`
4. returns null, policy waits for 2^2 = 4 seconds
5. calling `GetExternalIP`
6. returns null, policy waits for 2^3 = 8 seconds
7. calling `GetExternalIP`
8. returns null, policy waits for 2^4 = 16 seconds
9. calling `GetExternalIP`

If the last attempt returns null, it is passed to variable `ip` and the `Check` method returns and the app starts waiting for the next `Check` call from `ThreadPoolTimer`.

If the IP was returned properly and it is different, it tries to send the email with the new address. There is no try/catch block in the `SendMail` method so if there any exception, it is thrown directly so here I could use the `HandleException` method to trigger the retry process. Here I have to decide if the process was successful so `ExecuteAndCaptureAsync` instead of `ExecuteAsync` to return a `PolicyResult` object. If even the last retry failed with an exception, it will have the `OutcomeType.Failure` value in it so the `Check` returns and app waits for next cycle. If everything's OK, the mail is sent and the config object can be saved with the new IP.

So this is my little IP-email-updater app, [clone it from GitHub](https://github.com/codernr/ipwatcher) and feel free to use it in your own projects!