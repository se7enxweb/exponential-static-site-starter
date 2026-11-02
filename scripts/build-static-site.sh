#!/usr/bin/env bash
# Builds a static copy of an Exponential site into build/site, ready for GitHub Pages (or any static host).
#
# It installs Exponential with Composer, brings in the site (a database from data/ plus the code and settings of
# site/, or, when data/ holds no database, a site package installed with exp:install), serves it on 127.0.0.1
# with PHP's built-in web server, builds the static copy with exp:static:build and checks every link with
# exp:static:diff --check-links. The GitHub Actions workflow runs it; it runs the same way on your own computer.
#
# Settings (environment variables, all optional):
#   EXPONENTIAL_VERSION  Composer constraint of se7enxweb/exponential (default dev-main until 6.0.15 is released)
#   SITE_PACKAGE         the site package exp:install installs when data/ holds no database (default: the installer's)
#   SITE_ACCESS          the front siteaccess that is published (default site)
#   SITE_DATABASE_NAME   file name of the SQLite database in var/storage/sqlite3 (default: Database= of
#                        site/settings/override/site.ini.append.php, else exponential.db)
#   BASE_PATH            the path the site is served below (default /<repository>/ on GitHub, / for <owner>.github.io)
#   PUBLIC_URL           the public address of the copy (default https://<owner>.github.io/<repository>/)
#   PAGES_CONFIGURED, PAGES_BASE_PATH, PAGES_BASE_URL  set by the workflow from actions/configure-pages
#   LIVE_URL             a live installation for search, login and forms ('' leaves those links out)
#   MAX_PAGES            the most pages the build stores (default 10000)
#   CRAWL_URL            the address the build reads the site from, on the built-in web server of PHP, which
#                        speaks plain http only (default http://127.0.0.1:<port>/ with a database from data/,
#                        http://127.0.0.1:<port>/<siteaccess>/ for a package, whose siteaccesses go by URL)
#   WORK                 the work folder (default ./build)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-$ROOT/build}
APP=$WORK/exponential
OUT=$WORK/site
PORT=${PORT:-8080}
EXPONENTIAL_VERSION=${EXPONENTIAL_VERSION:-dev-main}
SITE_ACCESS=${SITE_ACCESS:-site}
MAX_PAGES=${MAX_PAGES:-10000}
LIVE_URL=${LIVE_URL:-}

say() { printf '\n== %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

# Where the copy is served: GitHub Pages serves a project site below /<repository>/, a user or organization site
# (<owner>.github.io) and a custom domain at /.
repo=${GITHUB_REPOSITORY:-}
owner=${repo%%/*}
name=${repo#*/}
if [ "${PAGES_CONFIGURED:-}" = true ]; then
    # actions/configure-pages: /<repository> for a project site, '' for a custom domain or <owner>.github.io
    BASE_PATH=${BASE_PATH:-${PAGES_BASE_PATH:-}/}
    PUBLIC_URL=${PUBLIC_URL:-${PAGES_BASE_URL:+$PAGES_BASE_URL/}}
fi
if [ -z "${BASE_PATH:-}" ]; then
    if [ -z "$repo" ] || [ "$(printf '%s' "$name" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$owner" | tr 'A-Z' 'a-z').github.io" ]; then
        BASE_PATH=/
    else
        BASE_PATH=/$name/
    fi
fi
case "$BASE_PATH" in /*) ;; *) BASE_PATH=/$BASE_PATH ;; esac
case "$BASE_PATH" in */) ;; *) BASE_PATH=$BASE_PATH/ ;; esac
if [ -z "${PUBLIC_URL:-}" ] && [ -n "$repo" ]; then
    PUBLIC_URL="https://$(printf '%s' "$owner" | tr 'A-Z' 'a-z').github.io$BASE_PATH"
fi
PUBLIC_URL=${PUBLIC_URL:-http://127.0.0.1:$PORT/}
case "$PUBLIC_URL" in */) ;; *) PUBLIC_URL=$PUBLIC_URL/ ;; esac
echo "Base path $BASE_PATH, public address $PUBLIC_URL, siteaccess $SITE_ACCESS"

ini_value() { # file key: the first key=value of an INI file, '' when there is none
    [ -f "$1" ] || return 0
    sed -n "s/^[[:space:]]*$2=\\(.*\\)\$/\\1/p" "$1" | head -1 | tr -d '\r'
}

say "Exponential $EXPONENTIAL_VERSION"
[ -e "$APP" ] && fail "$APP exists: remove the work folder $WORK first"
mkdir -p "$WORK"
composer create-project "se7enxweb/exponential:$EXPONENTIAL_VERSION" "$APP" --no-interaction --prefer-dist --no-progress
cd "$APP"
php bin/php/console --version

DB_FILE=
for f in "$ROOT/data/database.sqlite" "$ROOT/data/database.db" "$ROOT/data/database.sql"; do
    [ -f "$f" ] && { DB_FILE=$f; break; }
done
SITE_INI="$ROOT/site/settings/override/site.ini.append.php"

CRAWL_URL=${CRAWL_URL:-}
if [ -n "$DB_FILE" ]; then
    CRAWL_URL=${CRAWL_URL:-http://127.0.0.1:$PORT/}
    say "Site from the database $(basename "$DB_FILE") and the settings of site/"
    [ -f "$SITE_INI" ] || fail "data/ holds a database, so site/settings/override/site.ini.append.php must hold the site's settings"
    SITE_DATABASE_NAME=${SITE_DATABASE_NAME:-$(ini_value "$SITE_INI" Database)}
    SITE_DATABASE_NAME=${SITE_DATABASE_NAME:-exponential.db}
    mkdir -p var/storage/sqlite3
    case "$DB_FILE" in
        *.sql) sqlite3 "var/storage/sqlite3/$SITE_DATABASE_NAME" < "$DB_FILE" ;;
        *) cp "$DB_FILE" "var/storage/sqlite3/$SITE_DATABASE_NAME" ;;
    esac
    [ "$(sqlite3 "var/storage/sqlite3/$SITE_DATABASE_NAME" 'PRAGMA quick_check;')" = ok ] || fail "the database does not pass PRAGMA quick_check"
else
    package_name=${SITE_PACKAGE:-}
    [ -n "$package_name" ] || package_name="the default package of the installer"
    say "Site from a package: exp:install, $package_name"
    args=(--apply --db=sqlite --access=url --url="http://127.0.0.1:$PORT" --site-access="$SITE_ACCESS" --random-password --title="${SITE_TITLE:-Exponential static site}")
    [ -n "${SITE_PACKAGE:-}" ] && args+=(--package="$SITE_PACKAGE")
    CRAWL_URL=${CRAWL_URL:-http://127.0.0.1:$PORT/$SITE_ACCESS/}
    php bin/php/console exp:install "${args[@]}"
fi

say "Code and settings of site/"
if [ -d "$ROOT/site" ]; then
    (cd "$ROOT/site" && find . -mindepth 1 -maxdepth 1 ! -name README.md -exec cp -a {} "$APP/" \;)
fi

VAR_DIR=$(ini_value settings/override/site.ini.append.php VarDir)
VAR_DIR=${VAR_DIR:-var/site}
for s in "$ROOT/data/storage.tar.gz" "$ROOT/data/storage"; do
    [ -e "$s" ] || continue
    say "Storage from data/$(basename "$s") into $VAR_DIR/storage"
    mkdir -p "$VAR_DIR"
    if [ -d "$s" ]; then cp -a "$s" "$VAR_DIR/storage"; else tar -xzf "$s" -C "$VAR_DIR"; fi
    break
done

OVERRIDE=settings/override/staticcache.ini.append.php
if [ -f "$ROOT/site/$OVERRIDE" ]; then
    say "Static publishing settings: site/$OVERRIDE (it must define the target pages)"
else
    say "Static publishing settings: the target pages"
    cat > "$OVERRIDE" <<INI
<?php /* #?ini charset="utf-8"?

[StaticPublishSettings]
Enabled=enabled
GitHubAPI=disabled
Push=disabled
TargetList[]
TargetList[]=pages

[Target_pages]
Name=GitHub Pages
SiteAccess=$SITE_ACCESS
Kind=github-pages
Delivery=actions
Links=relative
BasePath=$BASE_PATH
PublicURL=$PUBLIC_URL
CrawlURL=$CRAWL_URL
LiveURL=$LIVE_URL
MaxPages=$MAX_PAGES
ExcludePaths[]
ExcludePaths[]=/user/*
ExcludePaths[]=/shop/*
ExcludePaths[]=/tags/*

*/ ?>
INI
fi

say "Autoloads and caches"
php bin/php/ezpgenerateautoloads.php -e
php bin/php/ezcache.php --clear-all

say "Serving the site on http://127.0.0.1:$PORT/"
php -d memory_limit=1G -S "127.0.0.1:$PORT" -t "$APP" bin/php/velocity-router.php > "$WORK/php-server.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
for i in $(seq 1 30); do
    curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break
    sleep 1
done
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")
[ "$code" = 200 ] || { tail -40 "$WORK/php-server.log"; fail "the start page answers $code"; }

say "exp:static:targets"
php bin/php/console exp:static:targets

say "exp:static:build pages"
php bin/php/console exp:static:build pages --report="$WORK/static-build.json"

say "Link check below / and $BASE_PATH"
mounts=(--mount=/)
[ "$BASE_PATH" != / ] && mounts+=(--mount="$BASE_PATH")
php bin/php/console exp:static:diff pages --verify --check-links "${mounts[@]}"

BUILT=$(find var -maxdepth 4 -type d -path '*/static-publish/pages' | head -1)
[ -n "$BUILT" ] && [ -f "$BUILT/index.html" ] || fail "no build found below var/*/static-publish/pages"
say "Copying $BUILT to $OUT"
mkdir -p "$OUT"
(cd "$BUILT" && tar --exclude=./.git --exclude=./.static-publish -cf - .) | (cd "$OUT" && tar -xf -)
echo "PASS $(find "$OUT" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1) in $OUT"
