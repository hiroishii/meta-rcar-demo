#!/bin/bash

# COMMIT=44d423063e97c5597668174eb484818441d709f8
# COMMIT=3306c9fd84987f31bad3e22b79e57c2e332ef73d # 2024-12-5: Android 14
COMMIT=db28f8d29160fdf95ecbeac5eaafb29168f3b789 # 2025-1-28: Android 15
REPO_URL=https://github.com/xen-troops/meta-xt-prod-devel-rcar/archive/$COMMIT.zip
GFX_MMP_DRV=R-Car_Gen3_Series_Evaluation_Software_Package_for_Linux-20220121.zip
GFX_MMP_LIB=R-Car_Gen3_Series_Evaluation_Software_Package_of_Linux_Drivers-20220121.zip
SCRIPT_DIR=$(cd `dirname $0` && pwd)

CheckEvaluationPackage () {
    if [[ ! -e "./proprietary/$GFX_MMP_DRV" ]] || [[ ! -e "./proprietary/$GFX_MMP_LIB" ]]; then
        echo "Error: GFX/MMP evaluation package is missing."
        echo "please download follwing items and copy into './propietary' directory:"
        echo "- $GFX_MMP_DRV"
        echo "- $GFX_MMP_LIB"
        echo ""
        echo "Package can be downloaded from following link:"
        echo "- https://www.renesas.com/application/automotive/r-car-h3-m3-h2-m2-e2-documents-software"
        echo ""
        echo "Directory structure:"
        echo "."
        echo "|--$0"
        echo "|--proprietary"
        echo "   |--$GFX_MMP_DRV"
        echo "   |--$GFX_MMP_LIB"
        exit -1
    fi
}
Usage() {
    echo "Usage: $0 <target_board>"
    echo "board list:"
    echo "- h3ulcb-4x2g-kf (h3sk 8GB + kingfisher board)"
    echo "- h3ulcb-4x2g-ab (h3sk 8GB + ccpf-sk board)"
    echo "- salvator-xs-h3-4x2g (Salvator-XS with H3 8GB)"
    echo ""
    CheckEvaluationPackage;
}
if [[ $# -ne 1 ]]; then
    Usage; exit -1
fi
if [[ $1 != "h3ulcb-4x2g-kf" ]] && 
    [[ $1 != "h3ulcb-4x2g-ab" ]] && 
    [[ $1 != "salvator-xs-h3-4x2g" ]]; then
    echo "Error: This board is not supported: $1"
    Usage; exit -1
fi
CheckEvaluationPackage;

rm -f ./repo.zip
wget -cq $REPO_URL -O repo.zip
unzip -qo repo.zip
WORK=$(cd meta-xt-prod-devel-rcar-$COMMIT && pwd)

# Prepare GFX/MMP
cd $WORK
mkdir -p $WORK/../prebuilt_gsx/domd
for zipname in $(ls $WORK/../proprietary/*.zip); do
    unzip -qo $zipname -d $WORK/../prebuilt_gsx
done
cd $WORK/../prebuilt_gsx/
ls *.zip | xargs -i unzip -qo {}
find | grep -e GSX -e gles | xargs cp -t domd
mv -f domd/{INF_,}r8a77951_linux_gsx_binaries_gles.tar.bz2
mv -f domd/{INF_,}r8a77960_linux_gsx_binaries_gles.tar.bz2
cp -rf $WORK/../prebuilt_gsx/domd $WORK/../prebuilt_gsx/domu

# Build
cd $WORK
curl https://storage.googleapis.com/git-repo-downloads/repo > repo
chmod a+x ./repo
export PATH=$PWD:$PATH
cat ../demo.yaml >> prod-devel-rcar-virtio.yaml


moulin prod-devel-rcar-virtio.yaml \
    --MACHINE $1 \
    --ENABLE_ANDROID yes \
    --ENABLE_DOMU no \
    --GRAPHICS binaries \

# workaround: Modify build.ninja to inherit rm_work, since moulin seems not to be able to handle "+=" syntax
sed -i -e "s/conf\ =\ /conf\ =\ \'INHERIT\ \+\=\ \"rm_work\"\'\ /g" build.ninja

# Cleanup build directory
rm -rf firmware
find yocto/common_data/sstate | grep xen: | xargs rm -r
find yocto/common_data/sstate | grep arm-trusted-firmware: | xargs rm -r

ninja
ninja full.img.gz

mkdir -p firmware
find ./yocto/build-domd/tmp/deploy/images/ -name "*.srec" | xargs cp -t firmware

