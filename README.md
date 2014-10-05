# HiveBBS

***ENTERPRISE QUALITY BBS***

Notable features:
- Posting messages
- Reading messages

## Installation

Make sure you have Ruby 1.9.3 at least. 2.0.0+ is recommended.

#### Get the source

Download and extract a release tarball or clone the git repository:

`git clone https://github.com/desuwa/hivebbs.git`

#### Install core dependencies

`gem install rake bcrypt erubis escape_utils sequel sinatra hive_markup`

#### Pick a database adapter

**For a MySQL database:**

Install the MySQL client dev package if you don't already have it:

`sudo apt-get install libmysqlclient-dev`

Then install the gem:

`gem install mysql2`

**For PostgreSQL:**

Install the PostgreSQL client dev package if you don't already have it:

`sudo apt-get install libpq-dev`

Then install the gem:

`gem install pg`

**For SQLite:**

Install the SQLite dev package if you don't already have it:

`sudo apt-get install libsqlite3-dev`

Then install the gem:

`gem install sqlite3`

#### Pick a webserver

Just get Puma:

`gem install puma`

or don't, and use some other Rack-compatible server, like *Unicorn* or *thin*.

#### Configuration

Assuming your database server is up and running and you have created a database for your HiveBBS installation (unless you are using SQLite).

Get into the directory where you extracted or cloned the sources.

**Configure the database**

Copy `config/db.rb.sample` to `config/db.rb` and edit it.

Set the `adapter` to `mysql2` for MySQL, `postgres` for PostgreSQL, `sqlite` for SQLite

`database` is the name of the database you created or the path to the SQLite database file.

**Migrate the database**

`rake db:migrate`

This will create the necessary tables. You can run it every time you need to upgrade the schema.

**Create the admin account**

`rake db:init`
or
`rake db:init[volunteer]`
if you want to use *volunteer* as username instead of the default *admin*.

**Generate the tripcode key file**

This will create a `config/trip.key` file containing a random key which will be used to generate tripcodes.

`rake gentripkey`
or
`rake gentripkey[512]`
if you want to change the size of the key in bytes. It's 256 by default.

At this point you should be able to start HiveBBS in development mode:

`./hive.rb`

It will be available at `http://127.0.0.1:4567`

The manager (admin) route is `/manage`

**Configure Puma**

You picked Puma, right?

`rake puma:init`

This will create a `puma-hive.rb` file

You might want to adjust the `threads` and `workers` parameters. Check the Puma [documentation](https://github.com/puma/puma) for that.

`rake puma:start` starts Puma.  
`rake puma:reload` does a [phased-restart](https://github.com/puma/puma#normal-vs-hot-vs-phased-restart).  
`rake puma:restart` restarts Puma.  
`rake puma:stop` stops Puma.  

**Configure what's in front of Puma**

For nginx, you can add something like this to your site's .conf file:

```
upstream puma_hive {
  server unix:///var/www/hivebbs/tmp/puma.sock;
}
```

Replace `/var/www/hivebbs/tmp/puma.sock` with the path to the puma socket file.
By default it's `{your_hivebbs_folder}/tmp/puma.sock`.

Then, inside the `server` block:

```
  try_files $uri @puma;
  
  location @puma {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://puma_hive;
  }
```

#### File uploads

File uploads are disabled by default. You need [ImageMagick](http://www.imagemagick.org/script/install-source.php) to handle image files and [FFmpeg](https://trac.ffmpeg.org/wiki/CompilationGuide) for webm.

#### The End

If your server isn't accessible through HTTPS, you'll need to set the `secure_cookies` option to `false` inside `config/config.rb`, otherwise you won't be able to log in.
You really should use HTTPS, though.

## Running tests

`gem install rack-test minitest`

Get the [sample data](https://github.com/desuwa/hivebbs_spec_data) if you want to test ImageMagick and FFmpeg. Put it inside the `spec` directory so to have the sample files inside `spec/data`.

Create `config/db_test.rb` and a new database.

`rake -T` to see all test tasks.

## License

[MIT](http://www.opensource.org/licenses/MIT)
