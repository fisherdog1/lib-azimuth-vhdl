vdp="./util/vdp"
filename=$1.vhd

if [ $# -eq 2 ] 
then
	filename=$2/$1.vhd
fi

echo "Creating package:" $1
$vdp -d package_name " $1 " -f ./rtl/templates/package.vhd -o > $filename