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

There are tons of articles about why you should avoid inheritance when you can, how hard it makes maintainability of large projects, and how you can substitute it with, for example, using composition or decorator pattern. The subject of this post is not to discuss these topics but to show how you can use decorator pattern in ASP.NET Core, especially in its dependency injection container.