# (function) VM IP List
#####################################
vm_iplist () {
  grep -vE "(^#|^ *#)" /opt/vm/repository/Vagrantfile | uniq | awk -f /opt/vm/script/bin/Vagrant.awk
  exit 1
}

# (function) help
#####################################
usage () {
   def_vbox=$1
   cat <<EOF
$(basename ${0}) is a tool for VirtualMachine Auto Creating.

Usage:
  $(basename ${0}) [command] [<option>]

Options:
  -n     VirtualMachine Name, and ssh-config Host Name
  -i     IP address
  -b     Vagrant Box Name(default: ${def_vbox})
  -l     VirtualMachine and IP Adress List
  -m     Memory Size (MB) (default: 2048)
  -c     CPU Core (default: 2)
  -h     usage
EOF

  exit 1
}

# initialize variables
#####################################
vm_name=""
ip_addr=""
box_name="centos6.5"
#box_name="centos7.0"
vgrntrepo_dir="/opt/vm/repository"
vgrntfile=${vgrntrepo_dir}"/Vagrantfile"
date=`date +"%Y%m%d-%H%M"`
error_msg=""
submask="192.168.2."
vbox_srv_addr="192.168.2.50"
api_token="fae7c1b5dc3bad1dc835ca39fb519ead"
url="https://api.chatwork.com/v1/rooms/28421866/messages"
default_user="vagrant"
exec_user="toga" #本スクリプトを実行するユーザ


memory=1024
cpu=2

# get options
#####################################
while getopts n:i:b:m:c:lh opt
do
  case $opt in
    n)  vm_name=$OPTARG
        ;;
    i)  ip_addr=$OPTARG
        ;;
    b)  box_name=$OPTARG
        ;;
    l)  vm_iplist
        ;;
    h)  usage $box_name
        ;;
    m)  memory=$OPTARG
        ;;
    c)  cpu=$OPTARG
        ;;
    \?) usage $box_name
        ;;
  esac
done
shift $((OPTIND - 1))


# Script execution user Check
#####################################
echo "[INFO] Script execution user Check."
id -un | grep -q ${exec_user}

# check variables
#####################################

echo "[INFO] Checking 'vm_name' Argument."

if [ -z "${vm_name}" ]; then
  error_msg=${error_msg}"[WARNING] Please specify the VirtualMachine.\n"

else # check valid value
  cd ${vgrntrepo_dir}
  vagrant status | grep -qE "^${vm_name} "
  if [ "$?" -eq 0 ]; then
    error_msg=${error_msg}"[WARNING] VirtualMachine name duplication.\\n"
  fi
fi

echo "[INFO] Checking 'ip_addr' Argument."

if [ -z "${ip_addr}" ]; then
  error_msg=${error_msg}"[WARNING] Please specify the Ip Address.\n"

else # check valid value
  cd ${vgrntrepo_dir}
  grep -qE "^ *node\.vm\.network.*ip: *\"${ip_addr}\"" ${vgrntfile}
  if [ "$?" -eq 0 ]; then
    error_msg=${error_msg}"[WARNING] Ip address duplication.\n"
  fi
  echo ${ip_addr} | grep -qF ${submask}
  if [ "$?" -ne 0 ]; then
    error_msg=${error_msg}"[WARNING] Unusable Subnetmask.(Ex. ${submask}XXX).\n"
  fi

  echo ${ip_addr} | grep -qF ${vbox_srv_addr}
  if [ "$?" -eq 0 ]; then
    error_msg=${error_msg}"[WARNING] ${ip_addr} ip  can not be used"
  fi
fi

if [ -n "${error_msg}" ]; then
  echo -e $error_msg
  usage $box_name
  exit 1
fi

# 2nd initialize variables
#####################################
key_dir="/mnt/vm/repository/.vagrant/machines/${vm_name}/virtualbox"
key_basedir="/mnt/vm/boxes/${box_name}"
ssh_key_dir="/home/${exec_user}/.ssh/key"


vgrntfile_addline="\
config.vm.define :\"${vm_name}\" do |node|\n\
node.vm.box = \"${box_name}\"\n\
node.vm.network :public_network, ip: \"${ip_addr}\", bridge: \"eth0\"\n\
node.vm.provision :shell, :path => \"/opt/vm/script/init/vagrant_init.sh\"\n\
#del node.ssh.username = \"${exec_user}\"\n\
#del node.ssh.private_key_path = \"/home/${exec_user}/.ssh/key/${vm_name}.key\"\n\
node.vm.provider :virtualbox do |vb|
vb.customize [\"modifyvm\", :id, \"--memory\", \"${memory}\", \"--cpus\", \"${cpu}\", \"--ioapic\", \"on\"]; vb.name = \"${vm_name}\"
end\n\
end\
"

sshconfig_addline="\
Host ${vm_name}\n\
HostName ${ip_addr}\n\
User ${exec_user}\n\
IdentityFile ${ssh_key_dir}/${vm_name}.key\n\
"

# ssh-keygen Delete
#####################################
echo "[INFO] Delete the '${ip_addr}' from known_hosts."
ssh-keygen -f "/home/${exec_user}/.ssh/known_hosts" -R ${ip_addr}

# Edit Vagrantfile
#####################################
echo "[INFO] Edit Vagrantfile."

cp -p  ${vgrntfile} ${vgrntfile}.${date}

line_num=`grep -n "# add line" ${vgrntfile} | cut -d : -f 1`
echo -e ${vgrntfile_addline} | while read line
do
    echo $line | grep -qE "(^node\.)|(^#del )"

    if [ "$?" -ne 0 ];then
      addline="\ \ "$line
    else
      addline="\ \ \ \ "$line
    fi

    sed -i "${line_num}a `echo ${addline}`" ${vgrntfile}
    line_num=$(( line_num+1 ))
done

# Vagrantfile Syntax Check
#####################################
echo "[INFO] Vagrantfile Syntax Check"
cd ${vgrntrepo_dir}
vagrant status

if [ "$?" -ne 0 ];then
  echo "[CRITICAL] Vagrantfile Syntax Check NG!!"
  cat ${vgrntfile} | grep -vE "(^#|^ *#)" | uniq
  cp ${vgrntfile}.${date} ${vgrntfile}
  exit 1
else
  echo "[INFO] Vagrantfile Syntax Check OK!!"
fi

# VirtualMachine Up
#####################################
echo "[INFO] VirtualMachine UP."
cd ${vgrntrepo_dir}
vagrant up ${vm_name}

#秘密鍵を~/.ssh/keyにコピー
cp -p /opt/vm/repository/.vagrant/machines/${vm_name}/virtualbox/private_key /home/${exec_user}/.ssh/key/${vm_name}.key

# Edit .ssh/config
#####################################
echo "[INFO] Edit ssh-config."
cp -p /home/${exec_user}/.ssh/config /home/${exec_user}/.ssh/config.${date}
#echo "${sshconfig_addline}" >> /home/${exec_user}/.ssh/config

line_num=`wc -l /home/${exec_user}/.ssh/config | awk '{print $1}'`

echo -e $sshconfig_addline | while read line
do
    echo $line | grep -qE "^Host "

    if [ "$?" -eq 0 ];then
      addline=$line
    else
      addline="\ \ "$line
    fi

    sed -i "${line_num}a `echo ${addline}`" /home/${exec_user}/.ssh/config
    line_num=$(( line_num+1 ))
done

## SSH Connection Test
######################################
#echo "[INFO] SSH Connection Test."
#ssh ${vm_name} "echo '[INFO] SSH Connection Test OK!!'"
#
#if [ "$?" -ne 0 ];then
#  echo "[CRITICAL] 'ssh ${vm_name}' Command Faild."
#  remand_set $vgrntfile $vm_name $vgrntrepo_dir $date
#  exit 1
#fi

# Modify SSH User Vagrantfile
#####################################
echo "[INFO] Edit Vagrantfile. change of ssh login user."
sed -i "s/#del node.ssh.username/node.ssh.username/" ${vgrntfile}

# Modify SSH User Vagrantfile
#####################################
echo "[INFO] Edit Vagrantfile. change of ssh private key path."
sed -i "s/#del node.ssh.private_key_path/node.ssh.private_key_path/" ${vgrntfile}


# vagrant user delete
#####################################
echo "[INFO] Delete vagrant user."
ssh ${vm_name} "sudo userdel -r vagrant"

# reload VirtualMachine
#####################################
echo "[INFO] Reload VirtualMachine."
cd ${vgrntrepo_dir}
vagrant reload ${vm_name}
