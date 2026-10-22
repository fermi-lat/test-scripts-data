# Building the `fermitools-test-scripts-data` conda package

> **Superseded (2026-10-22):** the payload no longer lives in Git LFS and is no
> longer installed into `data/test-scripts/`.  It now follows the `outrefFiles/`
> scheme: small files are in `outrefFiles/Likelihood/` and the large FITS inputs
> are hosted outside git and fetched with curl by `recipe/build.sh`, all landing
> in `share/fermitools/data/Likelihood/outref/`.  The LFS budget, gzip storage
> and LFS-pointer sections below are kept for history only.

Working checklist for turning the shell repo at `~/ST/current/test-scripts-data`
(`git@github.com:fermi-lat/test-scripts-data.git`, branch `main`) into a real,
reproducible conda package whose payload lives in Git LFS.

The package installs test-script reference data into
`${CONDA_PREFIX}/share/fermitools/data/test-scripts/`, which is exactly the path
`likelihoodTestSuite.py:90` resolves as `dirs["LOCAL_DATA"]`. It is deliberately
**not** a run dependency of `fermitools` — it is test-only and most users never
need it.

**Four constraints drive everything below:**

1. **Payload = our curated files only.** Version 0.6 ships the 37 files the
   Likelihood suite actually reads (765 MB raw), not the 132-file / 3.82 GB
   legacy set. That is a starting point, not the final scope: further test
   data (much of the legacy `outref/` included) will be added and curated in
   later releases. **1.0 is reserved** for when that is complete.
2. **We stay on the GitHub free plan.** 1 GB LFS storage, 1 GB/month bandwidth.
   Build *very* rarely and let the conda package on anaconda.org be the
   distribution path, so routine use never touches LFS.
3. **The FITS files are stored gzipped in the repo and decompressed during the
   conda build**, so the installed tree is plain uncompressed FITS. This cuts
   the LFS payload from 765 MB to 438 MB. See section 3.
4. **Build fully locally before anything reaches GitHub's LFS.** The package is
   staged, built, installed and run against the Likelihood suite from the local
   working tree first. Only a payload that has passed is committed, and only
   then pushed. Every iteration before that costs zero LFS storage or
   bandwidth. See section 6.

Sizes below are MiB throughout (what `du -h` reports), to stay comparable with
the 1 GB quota.

---

## 1. Where things stand

### The shell repo

```
test-scripts-data/
  README.md
  recipe/build.sh                  <- byte-identical to the published 0.5 build.sh
  recipe/meta.yaml                 <- stale: rendered output from conda-build 3.12.1 (2018)
  recipe/meta.yaml.template        <- disagrees with meta.yaml (version 0.2, wrong source path)
  recipe/conda_build_config.yaml   <- stale: osx-64, python 2.7, clang/gfortran
  share/fermitools/data/test-scripts/placeholder.txt   <- empty, tracked
```

No `.gitattributes`, no `.gitignore`, no CI. `git-lfs` was **not installed** on
this machine (conda-forge has 3.8.0, apt has 3.4.1). Step 0 installed 3.8.0 into
`base` on 2026-10-15.

*(This section describes the starting point. Progress: steps 0–5 done locally
on 2026-10-15, with the push guard in place and nothing pushed.)*

### What is already published

`fermi::fermitools-test-scripts-data 0.5` — `noarch: generic`, 2.5 GB `.conda`,
133 files under `share/fermitools/data/test-scripts/` (plus `outref/`). Its
embedded recipe (`$CONDA_PKGS_DIRS/fermitools-test-scripts-data-0.5-0/info/recipe/`)
shows it was built **2025-10-14** with conda-build 25.9.0 on macOS arm64 from
`/Users/jasercio/Fermi/20251014/fermitools-test-scripts-data` — i.e. from this
same repo layout, with the data present locally but never committed. That build
had `requirements: {}` and `about: {}`, so the `memory_profiler / numpy / scipy /
pyyaml` run deps still sitting in our `recipe/meta.yaml` are from the older 2018
recipe and are **not** in the published package.

Because 0.5 is published, we cannot reuse that version number.

### The payload for 0.6

The payload comes from two places, deliberately:

* **Which files** — `~/ST/testing/likelihood_test_suite/data`, the curated run
  area: 39 files, already clean (no `._*` resource forks, no
  `*:Zone.Identifier` files, no junk duplicates). Two of those 39 are mission
  data belonging to `fermitools-data` and are excluded, leaving **37**.
  (`~/ST/testing/data/tmp/test-scripts`, 132 files / 3.82 GB, is the legacy 0.5
  payload and is **not** what we ship.)
* **The file contents** — an installed `fermitools-test-scripts-data 0.5` tree,
  e.g. `$CONDA_PREFIX/share/fermitools/data/test-scripts/` in the `fermidev`
  env. Those copies already carry the correct `$(CONDA_PREFIX)` path structure
  in the XML models; the run-area copies do not. See "Take the XML models from
  an installed 0.5 tree" below.

Verified: all 37 files are present in an installed 0.5 tree, and the 28
non-XML files are byte-identical between the two sources, so this choice only
affects the 9 XML models.

| | Count | Raw | Stored in repo (gzip -9) |
|---|---|---|---|
| FITS files (LFS, gzipped) | 24 | 764.9 MB | 437.7 MB |
| XML / txt reference files (plain git) | 13 | 168.5 KB | 168.5 KB |
| **Total** | **37** | **765.0 MB** | **437.9 MB** |

Relative to 0.5 this ships 37 of its 133 files and **drops 96**: the entire
`outref/` subdirectory, all the 3C279/3C84/PG1553 inputs, the pulsar data, the
extra livetime cubes, the 1.92 GB `outref/3C279_binned_srcmaps.fits`, and the
two mission templates. Every file we ship is already in 0.5.

### Isotropic templates: what belongs where

Our source directory holds five isotropic spectrum templates. Two of them are
mission files that `fermitools-data` already distributes, verified by SHA-256 as
byte-identical to its copies:

| Template | Home | Status |
|---|---|---|
| `isotropic_iem_v02.txt` | `fermitools-data` → `share/fermitools/refdata/fermi/galdiffuse/` | **Exclude.** In the repo since `e1e696f` (2018-08-01) and in the installed 0.18 package. |
| `iso_P8R3_SOURCE_V3_PSF3_v1.txt` | same | **Exclude.** Added in `6fd6f0a` (2020-05-26, "Add new isotropic templates (P8R3_V3)"). |
| `isotropic_8YP305_P8R3_SOURCE_V2_v7_YB01.txt` | this package | Keep — not a mission release. |
| `isotropic_8YP305_P8R3_SOURCE_V2_PSF3_v7_YB01.txt` | this package | Keep — not a mission release. |
| `isotropic_p8r3_source_v2_zmax80_4years.txt` | this package | Keep — not a mission release. |

**The published 0.5 XMLs already draw this exact line.** They reference the two
mission templates as
`$(CONDA_PREFIX)/share/fermitools/refdata/fermi/galdiffuse/<name>` and the three
custom ones as `$(CONDA_PREFIX)/share/fermitools/data/test-scripts/<name>`. So
the split is already established upstream; our source copies are stale
duplicates.

### Take the XML models from an installed 0.5 tree

The run-area XMLs use **CWD-relative** paths, because
`~/ST/testing/likelihood_test_suite/data` is reached as `./data` from the run
directory:

```
file="data/isotropic_iem_v02.txt"
```

The ScienceTools working copy has no `data/` directory, so staging those
verbatim would ship models that cannot resolve their spectrum files. **The
installed 0.5 copies already have the correct structure** and are what we build
from — no rewriting, no `sed`. They use `$(CONDA_PREFIX)`, which is the right
variable: `$(FERMI_DIR)` is empty in the `fermidev` env, while `CONDA_PREFIX` is
always set.

Nine XMLs are affected, and the installed copies already route each reference to
the right home:

| XML | template referenced | installed 0.5 points it at |
|---|---|---|
| `srcModel_1312.xml-initial` | `iso_P8R3_SOURCE_V3_PSF3_v1.txt` | `…/refdata/fermi/galdiffuse/` |
| `srcModel_1_E1.xml-initial` | `isotropic_iem_v02.txt` | `…/refdata/fermi/galdiffuse/` |
| `srcModel_3_2.xml-initial` | `isotropic_iem_v02.txt` | `…/refdata/fermi/galdiffuse/` |
| `srcModel_4.xml-initial` | `isotropic_iem_v02.txt` | `…/refdata/fermi/galdiffuse/` |
| `srcModel_4_tHb1.xml-initial` | `isotropic_iem_v02.txt` | `…/refdata/fermi/galdiffuse/` |
| `srcModel_1001.xml-border` | `isotropic_8YP305_…_v7_YB01.txt` | `…/data/test-scripts/` |
| `srcModel_1001.xml-initub` | `isotropic_8YP305_…_v7_YB01.txt` | `…/data/test-scripts/` |
| `srcModel_1001_memory.xml` | `isotropic_8YP305_…_PSF3_v7_YB01.txt` | `…/data/test-scripts/` |
| `srcModel_1055_testEBL.xml` | `isotropic_p8r3_source_v2_zmax80_4years.txt` | `…/data/test-scripts/` |

Nothing is lost by preferring the installed copies. Diffed with paths
normalised, eight of the nine are identical to the run-area versions, and the
ninth (`srcModel_1055_testEBL.xml`) differs only in the indentation of line 74 —
a tab in the installed copy where the run area has four spaces. No model content
differs.

A further convenience: the two mission templates are **absent** from the
installed 0.5 tree (they were never part of that package), so staging from it
excludes them automatically — no exclusion rules needed.

Because the models point into `fermitools-data`, this package gains a genuine
runtime dependency on it (D4).

### Who else reads this data — the trim is safe

Audited every consumer in ScienceTools of `share/fermitools/data/test-scripts/`:

* **`likelihoodTestSuite.py:90`** — the only live reader. Covered by the 37 files.
* **`recipe/tests/ST-unit-test`** — defines `test_data_path` (line 41) and
  `test_outref_path` (line 43) and then **never uses either**; they are dead
  variables, and they point at `$CONDA_PREFIX/test-scripts`, a path that does not
  exist in any env anyway. All of its reference data comes from
  `refdata_path = $CONDA_PREFIX/share/fermitools/data/<tool>/outref`, which is
  supplied by **`fermitools-data`**, not by this package.
* **`recipe/tests/ST-AGN-thread-test`** — run in CI by
  `testing-conda-st-unit.yml:83` and `testing-conda-fermipy-all.yml:76`, and the
  one place that used to read `.../test-scripts/outref/`. But commit `394106eb`
  (2025-12-10, jasercion, "Update test data path to use refdata_path")
  repointed it: `test_data_path` is now `$CONDA_PREFIX/share/fermitools/data`
  with the `test-scripts` component commented out (line 39), so
  `test_outref_path` resolves to `.../data/outref`, **which does not exist**, and
  the five `outref = .../test-scripts/outref` locals at lines 227/290/337/391/474
  are now dead. It also wants `L25110610395696BB9F6356_PH00.fits`,
  `L25110610395696BB9F6356_SC00.fits` and `3C279_input_model.xml` under
  `.../data/`, and **none of those exist in any package or anywhere on this
  machine** (0.5 has the differently-named `3C279-input-model.xml` and the older
  `L1504…`/`L1506…` photon files).

**Conclusion:** dropping the 93 legacy files breaks nothing that currently
works. The AGN thread test is mid-migration to a new, unpackaged data set — that
is a separate workstream, and worth confirming with Joe before we delete the
`outref/` files from our side. The 0.5 package stays on anaconda.org regardless,
so nothing is lost permanently.

### How ScienceTools consumes this package

`environments/fermitools-testing.yml:11` **already lists**
`fermi::fermitools-test-scripts-data`, unpinned, alongside
`fermi::fermitools-data`. Two consequences:

* The testing env will jump to 0.6 automatically and silently lose the 96 files.
  Pin it (step 9).
* `memory_profiler` is imported by `likelihoodTestSuite.py` but is in neither
  that env nor the published package's deps. Decide where it goes (D4).

### What `fermitools-data` teaches us

`~/ST/current/fermitools-data` (`fermi-lat/fermitools-data`, branch `master`,
345 MB) is the sibling precedent, and it speaks directly to our constraints:

1. **The recipe lives in a separate repo.** `fermitools-data` is pure data; the
   recipe is at `github.com/fermi-lat/fermitools-data-recipe` (built from commit
   `29b6f08c3da458727c8b15220b230b3df65ab75b`). Our shell already co-locates
   `recipe/` with the data, which is simpler — keep it that way.
2. **It fetches LFS content *inside* the build** rather than using `source:`:
   ```bash
   GIT_SSL_NO_VERIFY=1 git-lfs clone https://github.com/fermi-lat/fermitools-data.git
   ```
   with `requirements: build: [git-lfs 2.6.1]`. This exists because **conda-build
   does not smudge LFS objects** — see section 4. It also means every build
   re-downloads the whole payload, the opposite of what we want on the free plan.
3. **They have already hit the free-plan bandwidth ceiling.** `.gitattributes`
   tracks exactly one file (`gll_iem_v07.fits`), and `.gitignore` says, verbatim:
   > Ignore the large galactic diffuse file to avoid unnecessarily contributing
   > to our git LFS bandwidth limit.

   The 465 MB file in our local checkout is in fact a **134-byte pointer** —
   living proof of how this fails silently.
4. **No CI.** `fermitools-data` has no `.github/`; both data packages are built
   by hand today. That matches "build very, very rarely" (step 8).
5. Channel naming is inconsistent: both installed packages came from `fermi`
   (`noarch`), while the `fermitools-data` README points at `fermi_dev_externals`.
   ScienceTools CI uploads to `user: fermi` — use `fermi`.
6. `fermitools` pins its data dep (`recipe/meta.yaml:79: fermitools-data=0.19`).
   We should **not** add `test-scripts-data` to those run deps.

---

## 2. The free-plan LFS budget

**Storage: 1 GB, counting every version ever pushed.** Gzipped, our payload is
438 MB, leaving ~586 MB of headroom (raw it would be 765 MB, leaving 235 MB).
LFS storage is not a snapshot of the current tree — each revision of a large
file adds its full size again, and deleting a file does not reclaim its storage
(that needs object purging, which on GitHub means recreating the repo or going
through support). With compression we can afford roughly one full re-push of the
two big files before the quota becomes a problem; without it, we could not.
Practical rules:

* Get the payload right *before* the first push.
* Treat any later revision of `ft2_10years_reduced.fits` (229 MB gzipped) or
  `DataE2XWgts_3percent_P305_zmax105_PSF3.fits` (63 MB gzipped) as a budget
  event, not a routine commit.
* The quota is **per account/org**, shared with `fermitools-data` — check what
  `fermi-lat` is already using before pushing.

**Bandwidth: 1 GB/month, consumed by downloads only.** Pushes count against
storage, not bandwidth. So:

* One `git lfs pull` of the full payload is 438 MB ≈ **43% of the monthly
  allowance** (765 MB ≈ 75% uncompressed). The initial build needs no pull at
  all, because it is built from the staged tree before anything is pushed.
  After that, pull once per machine, keep the working tree, and build from it
  repeatedly.
* A CI job that checks out with `lfs: true` spends that 438 MB *per run*. This is
  why step 8 recommends no automatic CI.

**Per-file limit: not a concern.** The 2 GB free/pro per-file cap mattered for
the legacy 1.92 GB `outref/3C279_binned_srcmaps.fits`; our largest stored object
is now 229 MB.

---

## 3. Storing the payload gzipped

The two big files cannot be trimmed, but they compress well, and FITS gzips
losslessly. Measured with `gzip -9 -n` on the real payload:

| File | Raw | gzip -9 | Ratio |
|---|---|---|---|
| `ft2_10years_reduced.fits` | 336.3 MB | 229.4 MB | 68.2% |
| `DataE2XWgts_3percent_P305_zmax105_PSF3.fits` | 252.0 MB | 63.2 MB | 25.1% |
| `srcMap_1001_E13.fits` | 123.2 MB | 108.1 MB | 87.7% |
| `ltcube_12years_zmax105.fits` | 16.8 MB | 14.6 MB | 86.8% |
| `srcMap_1055_E15.fits` | 6.7 MB | 2.7 MB | 40.8% |
| `srcMap_1312_E10.fits` | 5.6 MB | 4.1 MB | 73.8% |
| *(18 smaller FITS files)* | 24.3 MB | 15.6 MB | 64.2% |
| **All 24 FITS** | **764.9 MB** | **437.7 MB** | **57.2%** |

**Saving: 327 MB, or 43% of the LFS payload.** `DataE2XWgts` alone accounts for
189 MB of that.

### Decompress at build time, not install time

The requirement is that the installed files end up uncompressed. Two places that
can happen:

**A. During the conda build (recommended).** The repo holds `*.fits.gz`;
`build.sh` gunzips into `$PREFIX`. The package therefore contains ordinary
uncompressed FITS files, conda tracks every one of them normally, and nothing
special happens on the user's machine.

**B. At install time via `post-link.sh`.** Rejected, because:

* Files created by a post-link script are **not in the package manifest**.
  `conda list --files` would not show them, `conda remove` would leave 765 MB of
  orphans behind, and package verification/`--force-reinstall` would disagree
  with what is on disk. A matching `pre-unlink.sh` would be needed just to clean
  up.
* Post-link scripts are discouraged by conda, and their failures are poorly
  surfaced.
* It would need `gzip` guaranteed present in the *target* env, adding a run dep.
* Users pay the CPU and need double the peak disk during install.
* It saves nothing on package size — see below.

**Option A also produces a smaller published package.** The `.conda` format
compresses its payload with zstd, and already-gzipped data does not recompress.
Measured:

| File | zstd-19 of raw | gzip-9 | zstd-19 of the gzip |
|---|---|---|---|
| `DataE2XWgts…` | **54.7 MB** | 63.2 MB | 63.2 MB |
| `srcMap_1001_E13.fits` | **108.0 MB** | 108.1 MB | 108.1 MB |

So shipping raw files inside the package is *better* than shipping `.gz` files
inside it — zstd beats gzip on the raw data, and gzipped input passes through
unchanged. Compression buys us LFS headroom; it should not reach the package.

### Mechanics that matter

* **Use `gzip -9 -n`.** `-n` omits the original filename and mtime from the
  gzip header, so recompressing identical content yields a byte-identical blob.
  Without it, a re-gzip can produce a new LFS object and silently cost another
  229 MB of storage. Verified: `gzip -9 -n` twice over the same input gives the
  same SHA-256.
* **Roundtrip is exact.** `gunzip -c` of both big files reproduces the original
  SHA-256 byte for byte.
* **Decompression is cheap.** 0.8 s for `DataE2XWgts…`, 1.5 s for
  `ft2_10years_reduced.fits`; the whole payload adds a few seconds to a build.
* **The LFS pointer guard must inspect the `.gz` files**, since those are now
  what LFS tracks (section 4).

---

## 4. Hazard: conda-build does not fetch Git LFS objects

If `source:` is ever changed to `git_url:`, conda-build does a plain clone and
silently packages ~130-byte pointer files — a tiny package that installs fine
and fails at runtime. This is exactly the state `fermitools-data`'s checkout is
in right now. Mitigation: keep `source: path: ../` (conda-build copies the
working tree, so content must have been `git lfs pull`ed) **and** keep the
pointer-file guard in `build.sh`. With gzipping, a pointer would also fail
`gunzip`, but the guard gives the clear error message. Both are in step 3.

---

## 5. Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Payload scope | **Resolved:** the 37 curated files from `~/ST/testing/likelihood_test_suite/data`, 765 MB raw — the 39 there minus the two `fermitools-data` mission templates. No second package; no `outref/`. |
| D2 | LFS strategy: commit the data and build from the working tree (`source: path: ../`), or clone with git-lfs at build time like `fermitools-data`? | **Commit + `source: path: ../`**, plus the pointer guard. The first build comes from the locally staged working tree, before anything is pushed (section 6), so it costs no bandwidth at all. Later rebuilds on another machine pull 438 MB once, then build many times. The `fermitools-data` approach re-downloads the payload on every build — untenable on 1 GB/month — and `git-lfs clone` is deprecated in git-lfs 3.x. |
| D3 | Version number | **0.6** (0.5 is taken). 0.6 is the first git-provenanced build, with the Likelihood suite payload only. **1.0 is reserved** for when the remaining test data has been added. |
| D4 | Run deps | Put `memory_profiler`, `numpy`, `scipy`, `pyyaml` back in the package — installing the data then provisions a working test env in one step, and it fixes the missing `memory_profiler` in `fermitools-testing.yml`. **Add `fermitools-data`** too, since the rewritten XMLs reference its `galdiffuse/` templates. Leave it unpinned and let `fermitools` do the pinning (`recipe/meta.yaml:79`). |
| D5 | Keep `outref/*.key`? | **Resolved by D1:** dropped. They duplicated `ScienceTools/.../likelihood_test_suite/key_data/`, which is what the suite actually reads (`key_path = "key_data"`). |
| D6 | Confirm with Joe that nothing of his depends on the 93 dropped files, given the in-flight `ST-AGN-thread-test` migration. | Open — do this before pushing (step 6). |
| D7 | Gzip *all* FITS files, or only the ones where it pays? | **All 24**, as a single rule — the build loop treats them identically, there are no per-file judgment calls, and the saving is the full 327 MB. (Gzipping only the four files above 5 MB would recover 314 MB of the 327 MB, if a mixed tree is preferred.) |
| D8 | Rewrite the run-area XML spectrum paths ourselves, or take the already-correct XMLs from an installed 0.5 tree? | **Resolved: build from the installed 0.5 tree.** Those copies already carry the right `$(CONDA_PREFIX)` paths, and they are otherwise identical to the run-area versions (one tab-vs-spaces indent aside), so there is nothing to hand-rewrite and no `sed` step to get wrong. The run area supplies the *list* of 37 files; the installed tree supplies their contents. |

---

## 6. Instructions

**Order of work.** Steps 1–4 happen entirely on this machine: the payload sits
uncommitted in the working tree, and the package is built from that tree
(`source: path: ../` copies it as-is, with no git or LFS involved). The
payload is committed only after the suite passes (step 5), and pushed only
after that commit has been rebuilt and verified (step 6).

Holding the data out of git until then matters. When a branch is pushed, LFS
uploads **every** object referenced by **any** commit being pushed, not just
the tip. A data commit followed by a "fix" commit would push both
versions of the changed files, and each counts permanently against the 1 GB
storage quota. Keep the data uncommitted while iterating. If something does
get committed early, squash it away before pushing (step 6 checks for this).

### Step 0 — Local prerequisites

```bash
conda install -n base -c conda-forge git-lfs conda-build anaconda-client
git lfs install
```

`git-lfs` is not needed to *build* (steps 2–4 never touch it), but it must be
installed before the data is committed in step 5. Without it, `.gitattributes`
is silently ignored and the FITS files land in plain git.

### Step 1 — Repo hygiene, before any data lands

```bash
cd ~/ST/current/test-scripts-data

cat > .gitattributes <<'EOF'
# The FITS payload is stored gzipped (see PACKAGING.md) and tracked in LFS.
# recipe/build.sh decompresses it into $PREFIX at build time.
*.fits.gz filter=lfs diff=lfs merge=lfs -text
# Safety net in case an uncompressed FITS file is ever added.
*.fits    filter=lfs diff=lfs merge=lfs -text
EOF

cat > .gitignore <<'EOF'
# macOS resource forks and Windows zone markers from transferred archives
._*
.DS_Store
*:Zone.Identifier

# conda-build output
conda-bld/
EOF

git rm --cached share/fermitools/data/test-scripts/placeholder.txt
rm share/fermitools/data/test-scripts/placeholder.txt
git rm recipe/conda_build_config.yaml recipe/meta.yaml.template
git add .gitattributes .gitignore
git commit -m "Add LFS tracking and ignores; drop stale recipe config and placeholder"
```

This commit is local only. It holds no data, so it could be pushed safely, but
there is no need to until step 6.

Then disable pushing for this repo, so nothing reaches GitHub (or its LFS) by
accident before step 6. `git lfs install` adds a `pre-push` hook that uploads
LFS objects on **any** `git push`. Fetching still works:

```bash
git remote set-url --push origin no_push
git push --dry-run origin main     # must fail: "'no_push' does not appear to be a git repository"
```

Commits, `git lfs` operations and local clones never contact GitHub. Only a push
uploads LFS objects.

`.gitattributes` must be committed **before** the data, or the files land in
plain git and need a `git lfs migrate` to fix — on a 1 GB budget that mistake is
expensive.

### Step 2 — Stage and compress the curated payload (working tree only)

The run area defines *which* files; an installed 0.5 tree supplies *their
contents*, because its XML models already carry the right paths (D8).

Everything this step writes stays **untracked**. Do not `git add` it. If steps
3–4 show the payload needs changing, delete `share/fermitools/data/test-scripts/`
and `payload.list`, then rerun this step.

```bash
cd ~/ST/current/test-scripts-data
LIST=~/ST/testing/likelihood_test_suite/data                   # which files
SRC=/home/tstephen/miniconda3/envs/fermidev/share/fermitools/data/test-scripts  # contents
DST=share/fermitools/data/test-scripts

# Record the payload list in the repo so future rebuilds are reproducible.
# The two fermitools-data mission templates are absent from the 0.5 tree, so
# they drop out here without needing an exclusion rule.
( cd "$LIST" && ls ) | while read -r f; do
  [ -f "$SRC/$f" ] && echo "$f"
done > payload.list
wc -l payload.list        # expect 37

mkdir -p "$DST"
while read -r f; do
  case "$f" in
    # FITS files are stored gzipped;  -n keeps the blob reproducible.
    *.fits) gzip -9 -n -c "$SRC/$f" > "$DST/$f.gz" ;;
    *)      cp "$SRC/$f" "$DST/$f" ;;
  esac
done < payload.list

# expect 24 .fits.gz + 13 plain files = 37, about 438 MB
find "$DST" -type f | wc -l
du -sh "$DST"
```

Two sanity checks before moving on — that nothing was skipped, and that the
non-XML files really do match the curated run area:

```bash
# every curated file except the two mission templates made it into payload.list
( cd "$LIST" && ls | grep -vE '^(iso_P8R3_SOURCE_V3_PSF3_v1|isotropic_iem_v02)\.txt$' ) \
  | diff - payload.list && echo "payload list complete"

# contents identical to the run area for everything but the 9 XML models
while read -r f; do
  case "$f" in *.xml|*.xml-*) continue ;; esac
  cmp -s "$LIST/$f" "$SRC/$f" || echo "UNEXPECTED DIFFERENCE: $f"
done < payload.list; echo "content check done"
```

### Step 2b — Verify the XML spectrum paths

Nothing to rewrite — the staged models came from the 0.5 tree, so they should
already use `$(CONDA_PREFIX)`. Confirm it, because a stray CWD-relative path is
the one defect that would survive the build and only fail at test time:

```bash
cd share/fermitools/data/test-scripts

# No spectrum file may be CWD-relative.  (Restricted to <spectrum> elements:
# srcModel_4.xml-initial has a known-dead spatialModel "data/gll_iem_v02.fit",
# see section 7, which this check must not trip on.)
grep -lE '<spectrum[^>]*file="data/' *.xml *.xml-* \
  && echo "CWD-RELATIVE PATH FOUND - do not commit" \
  || echo "no relative spectrum paths - good"

# Every isotropic template resolves to one of the two expected homes.
grep -ho 'file="[^"]*iso[^"]*"' *.xml *.xml-* | sort -u
```

The last command should print exactly five distinct paths: the two mission
templates under `$(CONDA_PREFIX)/share/fermitools/refdata/fermi/galdiffuse/` and
the three custom ones under
`$(CONDA_PREFIX)/share/fermitools/data/test-scripts/`. Anything else, or any
`data/…` form, means the wrong source tree was used in step 2.

### Step 2c — Record the manifest

Record a manifest with **both** checksums, so we can verify the compressed blobs
in the repo and the uncompressed files the user ends up with:

```bash
cd ~/ST/current/test-scripts-data        # step 2b left us inside $DST
DST=share/fermitools/data/test-scripts
SRC=/home/tstephen/miniconda3/envs/fermidev/share/fermitools/data/test-scripts

( cd "$DST" && for f in *; do
    case "$f" in
      *.fits.gz) printf "%s  %s  (gz)\n" "$(sha256sum < "$f" | cut -d' ' -f1)" "$f"
                 printf "%s  %s  (raw)\n" "$(gunzip -c "$f" | sha256sum | cut -d' ' -f1)" "${f%.gz}" ;;
      *)         printf "%s  %s\n" "$(sha256sum < "$f" | cut -d' ' -f1)" "$f" ;;
    esac
  done ) | sort -k2 > MANIFEST.sha256
```

Cross-check the `(raw)` lines against the source files before pushing — only
the files in `payload.list`, since the 0.5 tree holds many more:

```bash
grep '\.fits$' payload.list | while read -r f; do
  printf "%s  %s\n" "$(sha256sum < "$SRC/$f" | cut -d' ' -f1)" "$f"
done | sort -k2 > /tmp/src.sha256

grep '(raw)' MANIFEST.sha256 | awk '{print $1"  "$2}' | sort -k2 \
  | diff - /tmp/src.sha256 && echo "payload verified"
```

Regenerate the manifest whenever step 2 is rerun.

### Step 3 — Rewrite the recipe

`recipe/meta.yaml`:

```yaml
{% set version = "0.6" %}

package:
  name: fermitools-test-scripts-data
  version: {{ version }}

source:
  # Build from the working tree: conda-build does NOT smudge Git LFS objects,
  # so in a clone the tree must have been `git lfs pull`ed.  build.sh enforces this.
  path: ../

build:
  noarch: generic
  number: 0

requirements:
  run:
    # The source models reference isotropic templates that fermitools-data
    # installs under refdata/fermi/galdiffuse/; fermitools pins its version.
    - fermitools-data
    - memory_profiler
    - numpy
    - scipy
    - pyyaml

test:
  commands:
    # The payload is stored gzipped in git but must install uncompressed.
    - test -f $PREFIX/share/fermitools/data/test-scripts/ft2_10years_reduced.fits
    - test -f $PREFIX/share/fermitools/data/test-scripts/ltcube_12years_zmax105.fits
    - test -f $PREFIX/share/fermitools/data/test-scripts/srcmdl_00.xml
    - '[ -z "$(find $PREFIX/share/fermitools/data/test-scripts -name "*.gz")" ]'

about:
  home: https://github.com/fermi-lat/test-scripts-data
  summary: Reference data for the Fermitools Likelihood test suite
  description: |
    Input and reference data used by the Fermitools Likelihood test suite,
    installed into $PREFIX/share/fermitools/data/test-scripts.  Required only
    for running the test suite, not for normal Fermitools use.

    Version 0.6 holds the files the Likelihood suite reads.  More test data
    will be added before 1.0; the broader legacy data set remains available
    as version 0.5.  FITS files are stored gzipped in the source repository to
    conserve Git LFS quota and are decompressed at build time, so the installed
    files are plain FITS.
```

`recipe/build.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

condaname="fermitools"
src="./share/${condaname}/data/test-scripts"
dest="${PREFIX}/share/${condaname}/data/test-scripts"

# conda-build copies the working tree verbatim.  If Git LFS content was never
# fetched, every large file here is a ~130-byte text pointer and the resulting
# package installs cleanly but fails at runtime.  Fail the build instead.
while IFS= read -r -d '' f; do
  if head -c 64 "$f" | grep -q 'git-lfs.github.com/spec'; then
    echo "ERROR: $f is an unfetched Git LFS pointer. Run 'git lfs pull' first." >&2
    exit 1
  fi
done < <(find "$src" -type f -print0)

# The FITS payload is stored gzipped in git to conserve LFS quota; the installed
# tree must be plain FITS.  Everything else is copied through unchanged.
mkdir -p "$dest"
while IFS= read -r -d '' f; do
  rel="${f#"$src"/}"
  mkdir -p "$dest/$(dirname "$rel")"
  case "$rel" in
    *.gz) gunzip -c "$f" > "$dest/${rel%.gz}" ;;
    *)    cp "$f" "$dest/$rel" ;;
  esac
done < <(find "$src" -type f -print0)

# Nothing compressed may survive into the installed tree.
if find "$dest" -name '*.gz' | grep -q .; then
  echo "ERROR: compressed files left in $dest" >&2
  exit 1
fi
```

Also fix `README.md`: the build command is `conda build recipe` (meta.yaml is in
`recipe/`, and its `source: path: ../` then resolves to the repo root), not
`conda build .`. Add notes that FITS files are stored gzipped and expanded by
`build.sh`, that new files must be added with `gzip -9 -n`, and that a full
`git lfs pull` costs ~43% of the monthly LFS bandwidth.

### Step 4 — Build, install and run the suite locally

The build reads the untracked payload straight from the working tree, so no
LFS is involved:

```bash
cd ~/ST/current/test-scripts-data
conda build recipe                 # expect a ~420 MB .conda
PKG=$(conda build recipe --output)

# Install from the local build channel by name, not from the "$PKG" path:
# installing a package file directly skips dependency resolution, so it
# would not check that the run deps (fermitools-data, memory_profiler, ...)
# resolve.
conda create -n tsd-verify -y -c local -c conda-forge -c fermi \
  python=3.12 fermitools "fermitools-test-scripts-data=0.6"
conda list -n tsd-verify fermitools-test-scripts-data   # channel must be "local"
```

Check the installed tree is 37 plain files with the right contents:

```bash
conda run -n tsd-verify bash -c '
  D="$CONDA_PREFIX/share/fermitools/data/test-scripts"
  find "$D" -type f | wc -l                       # 37
  find "$D" -name "*.gz" -o -name "*.fits.gz" | wc -l   # 0
  # -size -1k would only match empty files (find rounds up to whole KiB),
  # and find exits 0 when nothing matches, so test grep's output instead.
  hits=$(find "$D" -type f -size -1024c -exec grep -l "git-lfs.github.com/spec" {} +)
  [ -z "$hits" ] && echo "no LFS pointers - good" || echo "POINTERS FOUND: $hits"'

# contents match what we compressed
conda run -n tsd-verify bash -c '
  cd "$CONDA_PREFIX/share/fermitools/data/test-scripts" && sha256sum *.fits' \
  | sort -k2 > /tmp/installed.sha256
grep '(raw)' MANIFEST.sha256 | awk '{print $1"  "$2}' | sort -k2 \
  | diff - /tmp/installed.sha256 && echo "installed payload verified"
```

Then run the suite reading **only** the new package's data. This is the real test that the
37-file trim is complete and that the XML paths resolve. `envs/fermidev` holds
the full 0.5 tree, which would mask both problems, so the data must come from
`tsd-verify`.

**The tools must come from a working development build, not the released
`fermitools`.** Released 2.5.3 (what `tsd-verify` gets from `fermi`) cannot run
the suite. Its Python wrappers call `pyLike.StApp_parGroup` and
`pyLike.SourceFactory_funcFactory`, which its own compiled `pyLikelihood` no
longer exports. 5 tests die before touching any data, and 4 more fail the
`key_data` comparison. That says nothing about this package.

So run the `fermidev` dev build, with `CONDA_PREFIX` pointed at `tsd-verify`.
`LOCAL_DATA` (`likelihoodTestSuite.py:90`) and the `$(CONDA_PREFIX)` paths in
the XML models both resolve through that one variable, so the suite reads the
new package and `tsd-verify`'s `fermitools-data`, while the code, CALDB and
pfiles stay `fermidev`'s. Two cautions:

* Do **not** `source scripts/activate.sh RelWithDebInfo` for this.
  `RelWithDebInfo`'s install prefix is `envs/fermi-dev`, not `envs/fermidev`,
  and the script prepends `fermi-dev/lib` to `LD_LIBRARY_PATH`. The mixed
  libraries make `_pyLikelihood.so` fail with an undefined `optimizers` symbol.
  Set the variables from `recipe/activate.sh` against `fermidev` directly.
* Run from a **copy** of the suite. It writes `output/` next to the script,
  which would dirty the ScienceTools working tree.

```bash
FD=~/miniconda3/envs/fermidev/share/fermitools
WORK=$(mktemp -d)
mkdir -p "$WORK/suite" "$WORK/pf"
tar -C ~/ST/current/ScienceTools/src/Likelihood/src/test/likelihood_test_suite \
    -cf - --exclude=./output --exclude=./__pycache__ . | tar -C "$WORK/suite" -xf -
mkdir "$WORK/suite/output"

conda run --no-capture-output -n fermidev bash -c "
  export INST_DIR=$FD FERMI_DIR=$FD FERMI_INST_DIR=$FD BASE_DIR=$FD
  export EXTFILESSYS=$FD/refdata/fermi TIMING_DIR=$FD/refdata/fermi/jplephem
  export GENERICSOURCESDATAPATH=$FD/data/genericSources
  export CALDB=$FD/data/caldb CALDBROOT=$FD/data/caldb
  export CALDBALIAS=$FD/data/caldb/software/tools/alias_config.fits
  export CALDBCONFIG=$FD/data/caldb/software/tools/caldb.config
  export PFILES='.:$WORK/pf;$FD/syspfiles'
  export CONDA_PREFIX=$(conda run -n tsd-verify printenv CONDA_PREFIX)
  cd $WORK/suite && python likelihoodTestSuite.py"
```

For a baseline, run the same thing a second time with `CONDA_PREFIX` left at
`fermidev` (the 0.5 data) and compare `output/*.out` between the two runs. Any
test that also fails in the baseline is a tools or keys problem, not a data
problem.

**Result (2026-10-15, payload identical in 0.6):** all 14 tests PASS on the new data, as they do
on the 0.5 baseline. All 14 `output/*.out` files are byte-identical between the
two runs, and no test output contains a file-access error.

If a test reports a missing input, add that file to the payload, go back to
step 2, then rebuild and reinstall
(`conda env remove -n tsd-verify` first, so the old build cannot mask the new
one). Repeat until the suite passes. None of this touches git or GitHub.

### Step 5 — Commit the verified payload locally

Only now does the data enter git, as a **single** commit of exactly the payload
that passed step 4. `git lfs install` from step 0 must be in place:

```bash
cd ~/ST/current/test-scripts-data
git lfs env | grep -q 'filter.lfs.clean' || echo "git-lfs NOT installed - stop"

git add payload.list MANIFEST.sha256 share recipe README.md
git status --short | grep -v '^A \|^M \|^D ' && echo "unexpected files - check"

git commit -m "fermitools-test-scripts-data 0.6: Likelihood suite payload and recipe"

# Confirm the FITS blobs were captured by LFS rather than stored in plain git:
git lfs ls-files | wc -l    # expect 24
```

If the count is wrong, `git reset --soft HEAD~1` undoes the commit. That is
free, since nothing has been pushed.

Nothing has left the machine yet. The objects sit in `.git/lfs/objects/`.

### Step 6 — Rebuild from a clean clone, then push

The step 4 build came from the working tree. To confirm the *commit* contains
the whole package (no file left unstaged, no LFS filter misfire), clone the
repo locally and build from the clone. A local clone reads LFS objects from
this repo's `.git/lfs`, not from GitHub, so this is still free:

```bash
CLONE=$(mktemp -d)/test-scripts-data
git clone ~/ST/current/test-scripts-data "$CLONE"
cd "$CLONE"

# The clone must hold real gzip data, not pointers, and match the manifest
grep '(gz)' MANIFEST.sha256 | awk '{print $1"  share/fermitools/data/test-scripts/"$2}' \
  | sha256sum -c --quiet && echo "clone payload verified"

conda build recipe --croot "$CLONE-bld"
PKG=$(conda build recipe --croot "$CLONE-bld" --output)
```

If the clone shows pointer files, the installed git-lfs predates local-path
LFS support. Upgrade it rather than skipping this check. (git-lfs 3.8.0 from
conda-forge fills a local-path clone correctly.) `$PKG` from the clone is the
artifact to publish in step 7, because it is built from exactly what will be on
GitHub. The clone's `origin` is the local repo, so nothing run inside it can
reach GitHub.

Before pushing, check the GitHub side:

* **Quota.** Check the org's current LFS usage against the 1 GB storage quota
  (GitHub → `fermi-lat` → Settings → Billing → Git LFS Data). We need ~438 MB
  of room, shared with `fermitools-data`. If the headroom is not there, stop.
* **D6** is resolved.

Then confirm the push will upload only the final objects, so no earlier revision
of a file is hiding in local history (see "Order of work" above):

```bash
cd ~/ST/current/test-scripts-data
# Works offline and with the step 1 push guard still in place
git lfs status | grep -c '\.fits\.gz ('       # expect 24, not more
git log --oneline origin/main..main            # expect only local commits; none may add LFS objects beyond the 24
```

More than 24 objects means a superseded payload is in the history being
pushed. Squash it away (`git reset --soft origin/main` and recommit) and recheck
before pushing. Then lift the push guard, push, and put the guard back:

```bash
git remote set-url --push origin git@github.com:fermi-lat/test-scripts-data.git
git push origin main
git remote set-url --push origin no_push
git lfs ls-files | wc -l    # sanity: 24
```

After the push, `git lfs prune` can reclaim local disk from any abandoned
objects.

### Step 7 — Publish

Upload the package built from the clean clone in step 6 (`$PKG` there), not the
working-tree build from step 4:

```bash
anaconda login
anaconda upload --user fermi --label dev "$PKG"
```

Promote `dev` → `main` once the suite passes against the published package.

### Step 8 — CI: deliberately none, for now

Do **not** add a push- or tag-triggered build workflow. Any workflow that checks
out with `lfs: true` spends ~438 MB of the 1 GB monthly bandwidth per run, and
the whole point of this design is that the data ships inside the conda package so
nothing downstream ever touches LFS. Build by hand from a working tree that
already holds the data (steps 4–6), which costs nothing: the first build
predates the push, and later ones reuse a tree that has already been pulled.

If we later want a one-button release, add a **`workflow_dispatch`-only**
workflow — never `on: push` — and treat each run as a deliberate bandwidth
spend. It would need `ANACONDA_TOKEN` added to this repo's secrets (that secret
currently exists only on `ScienceTools`), `actions/checkout@v6` with `lfs: true`,
and the same `uibcdf/action-build-and-upload-conda-packages@main` action
ScienceTools already uses with `meta_yaml_dir: recipe`, `user: fermi`.

Tag releases regardless, so a build is reproducible from a commit:

```bash
git tag -a v0.6 -m "Likelihood suite test data, gzip-stored in LFS"
git push origin v0.6
```

### Step 9 — Wire into ScienceTools

`environments/fermitools-testing.yml` already installs this package but does not
pin it, so it would silently jump to the trimmed 0.6. Pin it explicitly:

```yaml
  - fermi::fermitools-test-scripts-data=0.6
```

If D4 was taken, `memory_profiler` arrives with the package; otherwise add it to
that env file. Then extend `.github/workflows/testing-conda-st-unit.yml` to run
the Likelihood suite after `ST-unit-test`.

Leave `ScienceTools/recipe/meta.yaml` alone — this package stays out of the
`fermitools` run deps by design.

---

## 7. Open questions

* **D6:** confirm with Joe that the 93 dropped files (especially `outref/`) are
  not needed, given the `ST-AGN-thread-test` migration in `394106eb`. Related:
  that test now needs `L25110610395696BB9F6356_{PH00,SC00}.fits` and
  `3C279_input_model.xml` under `share/fermitools/data/`, which exist in no
  package — whose job is it to package those, and does `test_outref_path`
  (now `.../data/outref`, nonexistent) need fixing?
* Current `fermi-lat` LFS storage usage, i.e. how much of the 1 GB is left.
* `srcModel_1_E1.xml-initial` (used by `test_delete_src.py`) references
  `gll_iem_v02.fit` and `IC443.fits`, and `srcModel_4.xml-initial` (used by
  `test_restore.py`) references `data/gll_iem_v02.fit` — with no usable
  directory, in both our copies and 0.5's. **Neither file exists anywhere**: not
  in this payload, not in 0.5, not in `fermitools-data`. The tests pass anyway,
  most likely because binned analysis reads the precomputed `srcMap_*.fits`
  rather than re-convolving the spatial template. Worth confirming and then
  either removing those dead sources or pointing them at real files.
* ~~Confirm the two mission templates are still present in `fermitools-data`
  0.19.~~ **Resolved 2026-10-15:** both `iso_P8R3_SOURCE_V3_PSF3_v1.txt` and
  `isotropic_iem_v02.txt` are under `refdata/fermi/galdiffuse/` in both 0.18 and
  0.19.
* **Released `fermitools` 2.5.3 cannot run the Likelihood suite.** Its Python
  wrappers (e.g. `BinnedAnalysis.py:298`) call `pyLike.StApp_parGroup` and
  `pyLike.SourceFactory_funcFactory`, which its compiled `pyLikelihood` does
  not export. The newer dev build in `envs/fermi-dev` lacks `StApp_parGroup`
  too. This is a ScienceTools issue, not a data one, but it blocks step 9
  (running the suite in CI against released tools) until it is fixed.
* Which channel label the testing workflows should consume: `fermi` or
  `fermi/label/dev`.
* Are the two files refreshed on 2025-09-18 the versions we want to publish?
  They are byte-size-identical to the legacy copies but differ in mtime.
