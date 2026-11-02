# data/

The content of your site. Leave it empty to publish the default site package instead.

- `database.sqlite` (or `database.db`): the SQLite database of your site; or `database.sql`, a dump made with
  `sqlite3 <database> .dump > database.sql`
- `storage.tar.gz`: the storage folder of your site (`var/<site>/storage`), made inside `var/<site>` with
  `tar -czf storage.tar.gz storage`; or the folder itself as `storage/`

Big files belong in Git LFS (`git lfs track "data/*.sqlite" "data/*.tar.gz"`).
