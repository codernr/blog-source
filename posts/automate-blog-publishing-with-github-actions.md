---
title: 'Automate blog publishing with Github Actions'
createdAt: '2020-04-08 13:00'
excerpt: "I've created a set of github workflows to automate the process of publishing new posts to my static github pages blog."
postedBy: codernr
tags:
  - 'static site generator'
  - 'github pages'
  - 'github actions'
  - 'CI/CD'
---

[In my previous post](/posts/this-post-is-generated-by-the-subject-of-this-post) I presented how I built a simple static blog generator from the ground up. My goal was to use it when writing my own blog as a replacement for the default Github Pages generator, Jekyll. I wanted to make publishing a new post as simple as a git push so I've created some CI/CD workflows in Github Actions.

### The release

First, I wanted my generator software to be released every time when I push a tag with a `v*.*.*` schema. For that purpose I needed two predefined action:

* [setup-dotnet](https://github.com/actions/setup-dotnet): this is used for dotnet build
* [action-gh-release](https://github.com/softprops/action-gh-release): for easy release publish

You can see the [whole workflow](https://github.com/codernr/bloggen-net/blob/develop/.github/workflows/dotnetcore.yml) file on the project github, I'd only highlight some key steps from it.

#### Trigger runs on specific tags

This part esures that workflow is only triggered when a tag is pushed with a semantic version number prefixed with 'v'.


```yml
on:
  push:
    tags:
      - 'v*.*.*'
```

#### Extract the tag name from ref

Github actions have only a `$GIHUB_REF` environment variable that contains the full ref path so you have to get the substring of it:

```yml
  - name: Set env
    run: echo ::set-env name=RELEASE_VERSION::${GITHUB_REF:10}
```

That way the pure tag name can be used as `env.RELEASE_VERSION` later.

### The source

Since user pages must be [published from master branch](https://help.github.com/en/github/working-with-github-pages/about-github-pages) I chose to host my blog source in a [separate repository](https://github.com/codernr/blog-source) and automate it to render the blog html-s when an update is pushed to it. I also made a [separate repository](https://github.com/codernr/startbootstrap-clean-blog) for the template that can trigger a blog build when updated through a `repository_dispatch` event with curl.

You can see the full code [here](https://github.com/codernr/blog-source/blob/master/.github/workflows/main.yml).

This is the trigger part:

```yml
on:
  push:
    branches: [ master ]
  repository_dispatch:
    types: trigger-ci
```

#### 1. Clone the template

This line clones the template repository to the directory defined by config.

```yml
- name: Checkout clean-blog template
  shell: bash
  run: git clone https://github.com/codernr/startbootstrap-clean-blog.git templates/clean-blog
```

#### 2. Download latest Bloggen.Net generator

This script reads the latest release url from Github API, then downloads unpacks it.

```yml
- name: Download latest Bloggen.Net
  shell: bash
  run: |
    latest_data=$(curl -s "https://api.github.com/repos/codernr/bloggen-net/releases/latest")
    download_url=$(egrep -oh -m 1 "(https://github.com/codernr/bloggen-net/releases/download/v[0-9]\.[0-9]\.[0-9]/v[0-9]\.[0-9]\.[0-9]\.tar\.gz)" <<< $latest_data)
    curl -L $download_url --output bloggen-net.tar.gz
    tar -zxvf bloggen-net.tar.gz
```

#### 3. Generate site with the downloaded software

This part creates the html site in the `bloggen-output` folder.

```yml
- name: Generate site
  shell: bash
  run: |
    cd deploy
    dotnet Bloggen.Net.dll -s "${PWD}/../" -o bloggen-output
```

#### 4. Check out user page repo and update

This part clones the main user page repository, overwrites the files in it with the new generated ones and pushes to the master branch of https://codernr.github.io repository.

```yml
- name: Update blog repository
    shell: bash
    env:
      GITHUB_TOKEN: ${{ secrets.GithubToken }}
      USER_MAIL: ${{ secrets.Mail }}
    run: |
      cd deploy
      git clone "https://codernr:${GITHUB_TOKEN}@github.com/codernr/codernr.github.io.git"
      rm -rf codernr.github.io/*/ codernr.github.io/*.html
      cp -rf bloggen-output/* codernr.github.io/
      cd codernr.github.io
      git config user.name codernr
      git config user.email $USER_MAIL
      git add --all
      git commit -am "Automatic github pages update from blog-source CI"
      git push
```

And that's it, the page is published!

### The template

I'm constantly developing the generator software and the template along with it so I also wanted an automation mechanism to update the blog when I update the template. So I made the `repository_dispatch` trigger for the workflow described in the previous section, that is triggered by the [template action](https://github.com/codernr/startbootstrap-clean-blog/blob/master/.github/workflows/main.yml) when changes are pushed to master. It then posts the proper json to Github API to trigger the specified event (`trigger-ci`).

[You can read more about this event here.](https://developer.github.com/v3/repos/#create-a-repository-dispatch-event)

And this is the workflow that sends the event:

```yml
name: CI

on:
  push:
    branches: [ master ]

jobs:
  webhook:
    runs-on: ubuntu-latest
    steps:
    - name: Dispatch update event
      shell: bash
      env:
        GITHUB_TOKEN: ${{ secrets.BlogSourceToken }}
      run: |
        curl -H "Accept: application/vnd.github.everest-preview+json" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        --request POST \
        --data '{"event_type": "trigger-ci"}' \
        https://api.github.com/repos/codernr/blog-source/dispatches
```

If you have any interesting experiences or questions about this field, let me know in the comments!