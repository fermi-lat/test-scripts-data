# test-scripts-data

Reference data for the Fermitools test suites, packaged as
`fermitools-test-scripts-data`.  Each `outrefFiles/<package>/` directory is
installed into `$CONDA_PREFIX/share/fermitools/data/<package>/outref/`.

## Building

From the top level of the repo:

```bash
conda build recipe
```

## Notes on the data

* Large files are not stored in git.  The Likelihood suite's FITS inputs are
  hosted separately and downloaded by `recipe/build.sh` from `likelihood_url`;
  the files fetched are listed in `likelihood_files` there.
* `MANIFEST.sha256` records the SHA-256 of every Likelihood input (downloaded
  and in-tree); `payload.list` lists their names.
* Source model XML files refer to the installed data as
  `$(CONDA_PREFIX)/share/fermitools/data/Likelihood/outref/...`.
