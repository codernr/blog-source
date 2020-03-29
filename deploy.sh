#!/bin/bash

latest_data=$(curl -s "https://api.github.com/repos/codernr/bloggen-net/releases/latest")
download_url=$(egrep -oh -m 1 "(https://github.com/codernr/bloggen-net/releases/download/v[0-9]\.[0-9]\.[0-9]/v[0-9]\.[0-9]\.[0-9]\.tar\.gz)" <<< $latest_data)

curl -L $download_url --output bloggen-net.tar.gz

tar -zxvf band-page-genarator.tar.gz

cd deploy

dotnet Bloggen.Net.dll -s ../ -o bloggen-output

git clone git@github.com:codernr/codernr.github.io.git

rm -rf codernr.github.io/* !(".git")

cp -r bloggen-output/ codernr.github.io/

cd codernr.github.io

git add --all

git commit -am "Automatic github pages update from blog-source CI"

# TODO: git push with token