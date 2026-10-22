export condaname="fermitools"
likelihood_url="https://fermidev.gsfc.nasa.gov/ssc/dev"
tooldirs=($(ls -d test-scripts-data/outrefFiles/* | sed "s|.*/||"))

# Populate the outref files with additional reference files                                                                         
for i in "${tooldirs[@]}"
do
echo "Populating outref file ${i}...\n"
mkdir -p $PREFIX/share/${condaname}/data/$i/outref
cp -R -n test-scripts-data/outrefFiles/$i/* $PREFIX/share/${condaname}/data/$i/outref/
if [ "$i" = "Likelihood" ]; then
    for f in "${likelihood_files[@]}"; do
        curl -fsSL -o "$PREFIX/share/${condaname}/data/$i/outref/$f" "${likelihood_url}/$f"
    done
fi
done


