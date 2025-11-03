export condaname="fermitools"

mkdir -p $PREFIX/share/${condaname}/data/test-scripts
cp -R ./share/${condaname}/data/test-scripts/* $PREFIX/share/${condaname}/data/test-scripts/
