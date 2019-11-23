# Bank

_It’s a bank, folks._

![Hack Club Bank](hack_club_bank_laser.gif)

## Getting Started

1. Install Docker.
2. Clone this repo.
3. ```sh
    docker-compose build
    docker-compose run web bundle
    docker-compose run web bundle exec rails db:create db:migrate
    docker-compose up
   ```
4. Open [localhost:3000](http://localhost:3000)

Alternatively, you can run `docker-compose run --service-ports web /bin/bash` to open a shell into the container with the right ports bound, and then manually start the Rails app, or just run `docker-compose run web bundle exec rails s -b 0.0.0.0` to start the rails server directly from Docker.

## Admin tasks

### Import database dump from Heroku

    $ heroku pg:backups:capture
    $ heroku pg:backups:download # will save as latest.dump, double check to make sure that file is created
    $ pg_restore --verbose --clean --no-acl --no-owner -h db -U postgres -d bank_development latest.dump

### Running migrations

Currently, migrations are decoupled from deployments. After deploying a patch with a new migration, run:

```
heroku run /bin/bash -a bank-hackclub
rails db:migrate:status
rails db:migrate
```

### Log into the Rails console in production

```
heroku console -a bank-hackclub
```

We can also replace `bank-hackclub` with any other app name (like a review app) to get the console for that app instead.

### Restart periodic / repeating jobs

For example, for the `SyncTransactionsJob`:

```
SyncTransactionsJob.perform_now(repeat: true)
```

