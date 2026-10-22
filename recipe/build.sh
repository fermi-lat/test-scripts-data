#!/usr/bin/env bash
# Any failed step, including a failed download, must fail the build.
set -euo pipefail

export condaname="fermitools"
likelihood_url="https://fermidev.gsfc.nasa.gov/ssc/dev/Likelihood"
# Large Likelihood inputs hosted outside git; fetched into Likelihood/outref.
likelihood_files=(
    DataE2XWgts_3percent_P305_zmax105_PSF3.fits
    MergedEVENTS_1001_E19.fits
    bexpmap_00.fits
    binned_exposure.fits
    binned_exposure_2.fits
    binned_exposure_E1-restore.fits
    binned_exposure_E1.fits
    binned_exposure_E10.fits
    binned_exposure_E13.fits
    binned_exposure_E15.fits
    binned_exposure_E3.fits
    expMap_1001_E19.fits
    ft2_10years_reduced.fits
    ft2_july09_pass8.fits
    ltcube_12years_zmax105.fits
    srcMap_1001_E13.fits
    srcMap_1055_E15.fits
    srcMap_1312_E10.fits
    srcMap_1_E1.fits
    srcMap_3_2.fits
    srcMap_4.fits
    srcMap_4_E1.fits
    srcMap_4_E3.fits
    srcmap_00.fits
)
tooldirs=($(ls -d test-scripts-data/outrefFiles/* | sed "s|.*/||"))

# Populate the outref files with additional reference files                                                                         
for i in "${tooldirs[@]}"
do
echo "Populating outref file ${i}...\n"
mkdir -p $PREFIX/share/${condaname}/data/$i/outref
cp -R -n test-scripts-data/outrefFiles/$i/* $PREFIX/share/${condaname}/data/$i/outref/
if [ "$i" = "Likelihood" ]; then
    for f in "${likelihood_files[@]}"; do
        curl -fsSL --retry 3 -o "$PREFIX/share/${condaname}/data/$i/outref/$f" "${likelihood_url}/$f"
    done
    # A download that succeeded but is truncated or wrong must also fail:
    # check every fetched file against MANIFEST.sha256.
    manifest="$(pwd)/test-scripts-data/MANIFEST.sha256"
    for f in "${likelihood_files[@]}"; do
        grep -qE "^[0-9a-f]{64}  ${f}\$" "$manifest" || {
            echo "ERROR: $f is not listed in MANIFEST.sha256" >&2; exit 1; }
    done
    (cd "$PREFIX/share/${condaname}/data/$i/outref" &&
        printf '%s\n' "${likelihood_files[@]}" |
        sed 's/.*/  &$/' | grep -f - "$manifest" | sha256sum -c --quiet -)
fi
done


