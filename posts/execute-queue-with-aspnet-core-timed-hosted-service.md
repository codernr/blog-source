---
title: 'Execute queue with ASP.NET core timed hosted service'
createdAt: '2020-07-16 15:30'
excerpt: 'This post shows how to create a hosted background service that polls a database for queued jobs on a regular basis and executes them, one at a time.'
postedBy: codernr
tags:
  - 'dotnet core'
  - 'asp.net core'
  - 'hosted service'
  - 'background service'
  - 'queue'
---

The best way to execute long running tasks in the background using ASP.NET Core is creating hosted services. There is a [great documentation](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-3.1&tabs=visual-studio) of how you can achieve this on Microsoft docs, but I took these basic examples a bit further.

### The problem

There is a job queue that is represented by a database table. Items are randomly pushed to this table by another application. I want to regularly check this queue and if I find a new job, I want to execute it. (Always one at a time, no concurrency.)

### The program flow

I need some kind of timer that fires regularly, regardless of any circumstance. When the timer fires, a piece of code has to be run that executes a job if it finds one in the database table. Since I want to avoid concurrency it also has to check if there is any job that is still running. So here are the tasks of this piece of code:

1. Check if there is a running job, if there is one, returns.
2. Check the database if there are new jobs, if it finds nothing, returns.
3. Take one job and start to execute it.

### What we already have

The [aforementioned documentation page](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-3.1&tabs=visual-studio) gives me almost all the information that is needed to achieve this so I just summarize it if you're lazy to read it (don't be):

To implement a hosted service you have to create a class that implements `IHostedService` interface. It has two methods: `StartAsync` that contains the logic to start the background task, and `StopAsync` that is triggered when the host is performing a graceful shutdown. That is the place where you can stop your remaining operations. Then you can register this class as a hosted service in your application's `Program.cs` (for details see the docs). And that's it.

#### BackgroundTask

There is an abstract class called `BackgroundTask` as part of the runtime ([see source code here](https://github.com/dotnet/runtime/blob/master/src/libraries/Microsoft.Extensions.Hosting.Abstractions/src/BackgroundService.cs)). If your service extends this class you can avoid writing boilerplate code you should write if you implement the interface only. You just have to override `ExecuteAsync`, put your long running logic there and it will be run in the background. The problem with it is that I can't execute something regularly in this method, because it is one long running task. Executing a job then waiting for a fixed time with `Task.Delay` wouldn't be truly regular because the length of each interval would depend on the length of each executed job.

#### Timed background tasks example

There is also a [working example](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-3.1&tabs=visual-studio#timed-background-tasks) of a regularly called method but that one is executed synchronously and it doesn't take into account that one job execution may be longer than the interval itself.