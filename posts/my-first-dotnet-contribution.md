---
title: 'My first dotnet contribution'
createdAt: '2020-07-03 15:30'
excerpt: "I posted a pull request fixing a default value in dotnet api docs and it got accepted and merged. It ain't much, but it's honest work."
postedBy: codernr
tags:
  - 'dotnet core'
  - 'github'
  - 'contribution'
  - 'open source'
  - 'SignedXml'
  - 'SHA'
metaProperties:
  - property: 'og:image'
    content: '/assets/img/posts/pull-request.png'
---

Recently I built a SOAP communication layer in dotnet core. I had to create a signed SAML request so I used [SignedXml](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.xml.signedxml) class tu build the signature. [References](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.xml.reference) had to be added with `SHA1` [DigestMethod](https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.xml.reference.digestmethod), and, as the documentation said, it was the default value of the property.

Then I got an error response from the server that the digest methods of references are invalid. After some debugging I realized that default value is `SHA256` indeed. I made some research and [found the commit](https://github.com/dotnet/runtime/commit/f628235e536cf488f8c0356942ff8b949551fc62) that changed the default from `SHA1` to `SHA256`. It was a bit surprising that the commit was pushed more than 2 years ago but nobody noticed the documentation inconsistency. So I read the [contribution guideline](https://docs.microsoft.com/en-us/contribute/dotnet/dotnet-contribute), forked the [docs repository](https://github.com/dotnet/dotnet-api-docs) and opened a [pull request](https://github.com/dotnet/dotnet-api-docs/pull/4320) to fix it. And then it got reviewed and accepted. YAAAY!

<p class="text-center"><img src="/assets/img/posts/pull-request.png" alt="It ain't much, but it's honest work" class="img-fluid"></p>
