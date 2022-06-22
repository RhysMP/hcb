#!/usr/bin/env bash

# installs all the dependencies for using Hack Club Bank with Docker
# reach out to kunal botla (kunal@hackclub.com) if you have any questions or issues.

echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 0/7: Checking for config/master.key"

if [ ! -e ./config/master.key ]; then
    echo "No config/master.key found; please get one from a Bank dev team member."
    exit 0
fi

echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 1/7: Install Heroku (Quiet)"
if ! command -v heroku &> /dev/null
then
  echo "running|||"
  (curl https://cli-assets.heroku.com/install-ubuntu.sh | sh) > /dev/null 2>&1
fi
echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 2/7: Login to Heroku"
(heroku auth:whoami) > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) Already signed in, skipping login..."
else
  echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) Not signed in, sign in below"
  echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) Use an API key generated from the Heroku Dashboard if you're using MFA"
  heroku login -i
fi
echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 3/7: Connect to the Heroku Project"
heroku git:remote -a bank-hackclub > /dev/null
echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 4/7: Get Heroku Backups"
if ! test -f "./latest.dump"; then
  heroku pg:backups:capture
  heroku pg:backups:download
fi
echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 5/7: Copy .env file"
cp -n .env.docker.example .env.docker
echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 6/7: Build Docker Container"
env $(cat .env.docker) docker-compose build
echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 7/7: Docker Database Setup"
env $(cat .env.docker) docker-compose run --service-ports web bundle exec rails db:test:prepare RAILS_ENV=test
env $(cat .env.docker) docker-compose run --service-ports web bundle exec rails db:prepare
env $(cat .env.docker) docker-compose run --service-ports web pg_restore --verbose --clean --no-acl --no-owner -h db -U postgres -d bank_development latest.dump
echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

if [[ $* == *--with-solargraph* ]]
then
  echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) Step 8/7: Solargraph"
  env $(cat .env.docker) docker-compose -f docker-compose.yml -f docker-compose.solargraph.yml build
  echo "$(tput setaf 9)Hack Club Bank:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
fi

echo "
$(tput setaf 9)Hack Club Bank:$(tput sgr0)
Run 'docker_start.sh' to start the dev server. You can run this command with the --with-solargraph flag to enable Solargraph."

echo "

Thank you for developing Hack Club Bank!

Questions or issues with this script? Contact Kunal Botla (kunal@hackclub.com)"

echo "
     @BANK@@@BANK@
    T             S
  H        $        T
 E       A   N       A
B    B           K    R
U      ©   H   A      T
C      C   K   C      S
K      L   U   B      H
 @    HACKCLUBANK    E
  @                 @
    HACK FOUNDATION

Hack Club Bank, A Hack Club Project
2022 The Hack Foundation
"
