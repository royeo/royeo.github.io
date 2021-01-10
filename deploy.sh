#!/bin/bash

set -ev

hexo clean
hexo generate

git clone git@github.com:royeo/royeo.github.io.git .deploy_git
mv .deploy_git/.git/ ./public/
rm -rf .deploy_git

cd ./public
git config user.name "royeo" 
git config user.email "ljn6176@163.com" 
git add .
git commit -m "Travis CI Auto Builder at `date +"%Y-%m-%d %H:%M"`"
git push
cd ..
rm -rf public
