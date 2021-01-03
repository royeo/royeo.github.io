#!/bin/bash

hexo clean
hexo generate

set -ev
export TZ='Asia/Shanghai'

git clone -b master https://github.com/royeo/royeo.github.io.git .deploy_git
mv .deploy_git/.git/ ./public/
cd ./public

git config user.name "royeo" 
git config user.email "ljn6176@163.com" 
git add .
git commit -m "Travis CI Auto Builder at `date +"%Y-%m-%d %H:%M"`"
git push
