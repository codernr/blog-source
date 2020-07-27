---
title: 'Execute queue with ASP.NET core timed hosted service'
createdAt: '2020-07-27 12:30'
excerpt: 'This post shows how to create a hosted background service that polls a database for queued jobs on a regular basis and executes them, one at a time.'
postedBy: codernr
tags:
  - 'dotnet core'
  - 'asp.net core'
  - 'hosted service'
  - 'background service'
  - 'queue'
metaProperties:
  - property: 'og:image'
    content: '/assets/img/posts/execute-queue-with-aspnet-core-timed-hosted-service.png'
---

The best way to execute long running tasks in the background using ASP.NET Core is creating hosted services. There is a [great documentation](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-3.1&tabs=visual-studio) of how you can achieve this on Microsoft docs, but I took these basic examples a bit further.

> To see the working example check out my repository: https://github.com/codernr/timed-hosted-service-example

### The problem

There is a job queue that is represented by a database table. Items are randomly pushed to this table by another application. I want to check this queue regularly and if I find a new job, I want to execute it. (Always one at a time, no concurrency.)

### The program flow

I need some kind of timer that fires regularly, regardless of any circumstance. When the timer fires, a piece of code has to be run that executes a job if it finds one in the database table. Since I want to avoid concurrency it also has to check if there is any job still running. So here are the tasks of this piece of code:

1. Check if there is a running job, if there is one, returns.
2. Check the database if there are new jobs, if it finds nothing, returns.
3. Take one job and start to execute it.

### What we already have

The [aforementioned documentation page](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-3.1&tabs=visual-studio) gives me almost all the information that is needed to achieve this so I just summarize it if you're lazy to read it (don't be):

To implement a hosted service you have to create a class that implements `IHostedService` interface. It has two methods: `StartAsync` that contains the logic to start the background task, and `StopAsync` that is triggered when the host is performing a graceful shutdown. This is the place where you can stop your remaining operations. Then you can register this class as a hosted service in your application's `Program.cs` (for details see the docs). And that's it.

#### BackgroundTask

There is an abstract class called `BackgroundTask` as part of the runtime ([see source code here](https://github.com/dotnet/runtime/blob/master/src/libraries/Microsoft.Extensions.Hosting.Abstractions/src/BackgroundService.cs)). If your service extends this class you can avoid writing boilerplate code you should write if you implemented the interface only. You just have to override `ExecuteAsync`, put your long running logic there and it will be run in the background. The problem with it is that I can't execute something regularly in this method, because it is one long running task. Executing a job then waiting for a fixed time with `Task.Delay` wouldn't be truly regular because the length of each interval would depend on the length of each executed job.

#### Timed background tasks example

There is also a [working example](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-3.1&tabs=visual-studio#timed-background-tasks) of a regularly called method but that one is executed synchronously and it doesn't take into account that one job execution may be longer than the interval itself.

#### Consuming a scoped service in a background task

This [example in the docs](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-3.1&tabs=visual-studio#consuming-a-scoped-service-in-a-background-task) is not about the hosted service itself but the way you can access a scoped service like `DbContext` from the hosted service. First you have to inject the `IServiceProvider` into the constructor of the hosted service then you can create a new scope in your method and get the required service from the service provider of that scope. That will be useful when I want to access my database table through `DbContext`.

### Putting it together

To achieve my goal and also handle graceful shutdown I have to merge the concepts of the `BackgroundTask` and the timed example and use the scoped service provider in the part that will be used regularly. I used the source of `BackgroundTask` as a starting point. Let's see it!

#### Constructor

```cs
public TimedHostedService(IServiceProvider services, ILogger<TimedHostedService> logger) =>
  (this.services, this.logger) = (services, logger);
```

Nothing special, I inject the service provider to get `DbContext` later plus a logger to be able to follow the execution on the console.

#### StartAsync

```cs
public Task StartAsync(CancellationToken cancellationToken)
{
  this._stoppingCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);

  this._timer = new Timer(this.FireTask, null, TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(30));

  this.logger.LogInformation("Started timer");

  return Task.CompletedTask;
}
```

First I create a linked token source that fires when the original one and save it in a private field. (Same code as in `BackgroundTask`). Then I create a timer that calls `FireTask` method in every 30 seconds. (Before the first call it waits 10 seconds.) This is the part that I took from the timer example.

#### FireTask

```cs
private void FireTask(object state)
{
  if (this._executingTask == null || this._executingTask.IsCompleted)
  {
    this.logger.LogInformation("No task is running, check for new job");
    this._executingTask = this.ExecuteNextJobAsync(this._stoppingCts.Token);
  }
  else
  {
    this.logger.LogInformation("There is a task still running, wait for next cycle");
  }
}
```

This is the method that gets called periodically. It checks if there is no previous task running and then kicks off `ExecuteNextJobAsync` task passing it the cancellation token and storing it in the `_executingTask` private field.

#### ExecuteNextJobAsync

```cs
private async Task ExecuteNextJobAsync(CancellationToken cancellationToken)
{
  using var scope = this.services.CreateScope();

  var context = scope.ServiceProvider.GetRequiredService<JobDbContext>();

  // whatever logic to retrieve the next job
  var nextJobData = await context.JobDatas.FirstOrDefaultAsync();

  if (nextJobData == null)
  {
    // no next job
    this.logger.LogInformation("No new job found, wait for next cycle");
    return;
  }

  // simulate long running job
  this.logger.LogInformation("Execute job with Id: {0} Delay: {1}", nextJobData.Id, nextJobData.Delay);

  await Task.Delay(TimeSpan.FromSeconds(nextJobData.Delay));

  this.logger.LogInformation("Job execution finished (Id: {0})", nextJobData.Id);

  // remove executed job from queue
  context.Remove(nextJobData);
  await context.SaveChangesAsync();
}
```

This is the actual long running method that retrieves the job data and executes it. This async task is stored in `_executingTask` that is checked if ready before the next interval fires `ExecuteNextJobAsync` again through `FireTask`. This example uses a simulation that calls a `Task.Delay` with seconds based on job data.

#### StopAsync / Dispose

```cs
public async Task StopAsync(CancellationToken cancellationToken)
{
  this._timer.Change(Timeout.Infinite, 0);

  if (this._executingTask == null || this._executingTask.IsCompleted)
  {
    return;
  }

  try
  {
    this._stoppingCts.Cancel();
  }
  finally
  {
    await Task.WhenAny(this._executingTask, Task.Delay(Timeout.Infinite, cancellationToken))
  }
}

public void Dispose()
{
  this._timer.Dispose();
  this._stoppingCts?.Cancel();
}
```

Basically this code is the same as the one you find in the `BackgroundService` source plus stopping the timer but I think it needs some explanation. This method gets called when the system starts a graceful shutdown. The process:

1. stop the timer
2. If there was no task or the last one has finished, everything's fine, we can shut down and return
3. `_executingTask` is still running so let's signal the cancellation with `_stoppingCts` of which token is passed in `ExecuteNextJobAsync`
4. Finally wait for the first of `_executingTask` and `cancellationToken` to finish/fire. Note that `cancellationToken` here signals the end of the graceful shutdown process so you have to return when it is fired no matter what.

### Try it out

You can check how the code works if you check out my [exmple project from github](https://github.com/codernr/timed-hosted-service-example).

To set your project up after git clone, you have to:

* run `dotnet restore`
* run `dotnet ef database update` (`dotnet-ef` tool has to be installed)
* add different jobs to the created table to test functionality