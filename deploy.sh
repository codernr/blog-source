#!/bin/bash

latest_data=$(curl -s "https://api.github.com/repos/codernr/bloggen-net/releases/latest")
download_url=$(egrep -oh -m 1 "(https://github.com/codernr/bloggen-net/releases/download/v[0-9]\.[0-9]\.[0-9]/v[0-9]\.[0-9]\.[0-9]\.tar\.gz)" <<< $latest_data)

curl -L $download_url --output bloggen-net.tar.gz

tar -zxvf band-page-genarator.tar.gz

cd deploy

dotnet Bloggen.Net.dll -s ../ -o bloggen-output

# TODO: git clone page repo; copy contents of bloggen-output to repo root with overwrite