vdp="./util/vdp"
filename=$1.vhd

if [ $# -eq 2 ] 
then
	filename=$2/$1.vhd
fi

echo "Creating entity:" $1
$vdp -d entity_name " $1 " -f ./rtl/templates/entity.vhd -o > $filename