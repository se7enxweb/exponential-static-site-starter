# Exponential static site starter

Put a free, fast, static copy of an [Exponential](https://github.com/se7enxweb/exponential) site on GitHub Pages,
built by GitHub Actions on every push. Editors keep working in Exponential; the public site is plain HTML pages and
files, with no PHP and no database behind them.

This repository is a template. Click **Use this template**, add your site, switch Pages to GitHub Actions and push.

## How it works

The workflow `.github/workflows/static-site.yml` runs `scripts/build-static-site.sh`, which:

1. installs Exponential with Composer (`se7enxweb/exponential`; static publishing is new in 6.0.15, so until that
   release is out the starter installs the main branch);
2. brings in your site: a database from `data/` plus the code and settings of `site/`, or, when `data/` holds no
   database, a site package installed with `exp:install`;
3. serves the site on `127.0.0.1` with PHP's built-in web server;
4. builds the static copy with `exp:static:build`: every page as `<path>/index.html`, the files the pages use,
   `404.html`, `robots.txt`, `sitemap.xml` and `.nojekyll`, with links that work below `/<repository>/`;
5. checks every link of the copy with `exp:static:diff --check-links`, at `/` and below the base path;
6. hands the copy to GitHub's own Pages actions, which publish it. No token and no `gh-pages` branch are needed.

## Use it

1. Click **Use this template** and create your repository. On the free plan it must be public for Pages.
2. In your repository, open **Settings > Pages** and set **Source** to **GitHub Actions**.
3. Add your site (see below), or leave `data/` empty to publish the default site package first.
4. Push to `main`, or run the workflow from the **Actions** tab. After a few minutes the site is at
   `https://<owner>.github.io/<repository>/`.

### Your site from a database and code

| Path | What goes there |
|---|---|
| `data/database.sqlite` | Your site's SQLite database (or `data/database.sql`, a dump made with `sqlite3 <db> .dump`) |
| `data/storage.tar.gz` | Your site's storage folder (`var/<site>/storage`: images and files), packed with `tar -czf storage.tar.gz storage` inside `var/<site>`; or the folder itself as `data/storage/` |
| `site/settings/override/` | Your `site.ini.append.php` (with `Database=` naming the SQLite file and `VarDir=`) and the other overrides |
| `site/settings/siteaccess/` | Your siteaccesses |
| `site/extension/`, `site/design/` | Your own extensions and designs |

Everything in `site/` is copied over the Exponential installation before the build. Large databases and storage
belong in [Git LFS](https://docs.github.com/repositories/working-with-files/managing-large-files); the checkout
fetches LFS files.

Other databases (MySQL, MariaDB, PostgreSQL) work too: add the database as a
[service container](https://docs.github.com/actions/using-containerized-services) to the workflow, load your dump
into it and name it in `site/settings/override/site.ini.append.php`. The starter itself uses SQLite, the default
database of Exponential, because it needs no server.

**Never commit a password, token or key.** The repository is public. A SQLite site needs no database password; for
anything else use [GitHub Actions secrets](https://docs.github.com/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions).

### Your site from a package

With no database in `data/`, the build installs a site package with `exp:install` on SQLite. Set `SITE_PACKAGE` in
the workflow to choose one; empty takes the installer's default.

### Settings

The `env:` block of the workflow holds the settings:

| Setting | Default | Meaning |
|---|---|---|
| `EXPONENTIAL_VERSION` | `dev-main` | Composer constraint of Exponential: the main branch until 6.0.15 is released, then pin `^6.0.15` |
| `PHP_VERSION` | `8.3` | PHP of the build |
| `SITE_PACKAGE` | empty | The site package to install when `data/` holds no database |
| `SITE_ACCESS` | `site` | The front siteaccess that is published |
| `LIVE_URL` | empty | A live installation: links to search, login and forms go there |

The static publishing target is written for you (`[Target_pages]` in `settings/override/staticcache.ini.append.php`).
To set it yourself, put your own `site/settings/override/staticcache.ini.append.php` with a target named `pages`;
[Static publishing](https://github.com/se7enxweb/exponential/blob/main/doc/eng-us/features/6.0/static-publishing.md)
lists every setting (exclusions, search, redirects, minify and more).

## Build it on your own computer

You need PHP 8.0 or newer with the `sqlite3`, `pdo_sqlite`, `gd`, `intl`, `mbstring`, `xsl`, `curl` and `sodium`
extensions, Composer and the `sqlite3` command.

```bash
bash scripts/build-static-site.sh
php -S 127.0.0.1:8090 -t build/site     # the copy, served at the root
```

`BASE_PATH=/` builds for the root of a host (a custom domain); the default on your computer is `/`.

## What GitHub Pages allows

- A published site of at most 1 GB, and files of at most 100 MB (Git refuses larger ones).
- About 100 GB of traffic a month.
- A public repository on GitHub Free; private repositories need GitHub Pro, Team or Enterprise.
- No server-side code: search, login, forms, comments and the shop do not work in the copy. The build leaves them
  out or links them to `LIVE_URL`.
- Use as GitHub's [Pages terms](https://docs.github.com/pages/getting-started-with-github-pages/github-pages-limits)
  allow: not for a commercial shop or a software-as-a-service.

The build warns at 90 % of the size limits.

## Learn more

- [Host static sites on GitHub Pages with Exponential 6.0.15+](https://github.com/se7enxweb/exponential/blob/main/doc/eng-us/guides/host-static-sites-on-github-pages.md),
  the step-by-step guide
- [Static publishing](https://github.com/se7enxweb/exponential/blob/main/doc/eng-us/help/static-publishing/README.md)
  in the help center, with the administration screens (Setup > Static publishing)
- [Exponential](https://github.com/se7enxweb/exponential) and its [documentation](https://github.com/se7enxweb/exponential/tree/main/doc/eng-us)

## License

GNU General Public License v2.0 or later, as Exponential: see [LICENSE](LICENSE). The content you publish is yours
and keeps its own license.
