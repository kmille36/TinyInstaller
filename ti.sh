#!/bin/bash

export isDebug="no"
export isRecovery="no"
export verbose=""
export confirm="no"
POSITIONAL=()
while [[ $# -ge 1 ]]; do
  case $1 in
    -d|--debug)
      shift
      isDebug="yes"
      ;;
	  -r|--recovery)
	    shift
	    isRecovery="yes"
	    ;;
	  -y|--yes)
      shift
      confirm="yes"
      ;;
	  -v|--verbose)
        shift
        verbose="yes"
        ;;
    *)
      POSITIONAL+=("$1")
      shift;
      ;;
    esac
  done

set -- "${POSITIONAL[@]}" # restore positional parameters

export DDURL=$1
export ipAddr=$2
export ipMask=$3
export ipGate=$4
export DISK=$5
export ipDNS='8.8.8.8'
export setNet='0'
export tiIso='https://github.com/4iTeam/TinyInstaller/raw/main/ti.iso'
REBOOT="reboot=1"

[ "$EUID" -ne '0' ] && echo "Error:This script must be run as root!" && exit 1;



dependence(){
  Full='0';
  for BIN_DEP in `echo "$1" |sed 's/,/\n/g'`
    do
      if [[ -n "$BIN_DEP" ]]; then
        Found='0';
        for BIN_PATH in `echo "$PATH" |sed 's/:/\n/g'`
          do
            ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1;
            if [ $? == '0' ]; then
              Found='1';
              break;
            fi
          done
        if [ "$Found" == '1' ]; then
          echo -en "[\033[32mok\033[0m]\t";
        else
          Full='1';
          echo -en "[\033[31mNot Install\033[0m]";
        fi
        echo -en "\t$BIN_DEP\n";
      fi
    done
  if [ "$Full" == '1' ]; then
    echo -ne "\n\033[31mError! \033[0mPlease use '\033[33mapt-get\033[0m' or '\033[33myum\033[0m' install it.\n\n\n"
    exit 1;
  fi
}

netmask() {
  n="${1:-32}"
  b=""
  m=""
  for((i=0;i<32;i++)){
    [ $i -lt $n ] && b="${b}1" || b="${b}0"
  }
  for((i=0;i<4;i++)){
    s=`echo "$b"|cut -c$[$[$i*8]+1]-$[$[$i+1]*8]`
    [ "$m" == "" ] && m="$((2#${s}))" || m="${m}.$((2#${s}))"
  }
  echo "$m"
}

getInterface(){
  interface=""
  Interfaces=`cat /proc/net/dev |grep ':' |cut -d':' -f1 |sed 's/\s//g' |grep -iv '^lo\|^sit\|^stf\|^gif\|^dummy\|^vmnet\|^vir\|^gre\|^ipip\|^ppp\|^bond\|^tun\|^tap\|^ip6gre\|^ip6tnl\|^teql\|^ocserv\|^vpn'`
  defaultRoute=`ip route show default |grep "^default"`
  for item in `echo "$Interfaces"`
    do
      [ -n "$item" ] || continue
      echo "$defaultRoute" |grep -q "$item"
      [ $? -eq 0 ] && interface="$item" && break
    done
  echo "$interface"
}

getDisk(){
  echo $(mount | grep "/ "  | cut -d' ' -f1 | sed -r 's/[0-9]+$//');
}

getGrub(){
  Boot="${1:-/boot}"
  folder=`find "$Boot" -type d -name "grub*" 2>/dev/null |head -n1`
  [ -n "$folder" ] || return
  fileName=`ls -1 "$folder" 2>/dev/null |grep '^grub.conf$\|^grub.cfg$'`
  if [ -z "$fileName" ]; then
    ls -1 "$folder" 2>/dev/null |grep -q '^grubenv$'
    [ $? -eq 0 ] || return
    folder=`find "$Boot" -type f -name "grubenv" 2>/dev/null |xargs dirname |grep -v "^$folder" |head -n1`
    [ -n "$folder" ] || return
    fileName=`ls -1 "$folder" 2>/dev/null |grep '^grub.conf$\|^grub.cfg$'`
  fi
  [ -n "$fileName" ] || return
  [ "$fileName" == "grub.cfg" ] && ver="0" || ver="1"
  echo "${folder}:${fileName}:${ver}"
}

lowMem(){
  mem=`grep "^MemTotal:" /proc/meminfo 2>/dev/null |grep -o "[0-9]*"`
  [ -n "$mem" ] || return 0
  [ "$mem" -le "524288" ] && return 1 || return 0
}
validUrl(){
  echo "$1" |grep '^http://\|^ftp://\|^https://';
}


[ -n "$ipAddr" ] && [ -n "$ipMask" ] && [ -n "$ipGate" ] && setNet='1';
if [ "$setNet" == "0" ]; then
  dependence ip
  [ -n "$interface" ] || interface=`getInterface`
  iAddr=`ip addr show dev $interface |grep "inet.*" |head -n1 |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\/[0-9]\{1,2\}'`
  ipAddr=`echo ${iAddr} |cut -d'/' -f1`
  ipMask=`netmask $(echo ${iAddr} |cut -d'/' -f2)`
  ipGate=`ip route show default |grep "^default" |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' |head -n1`
fi
if [ -z "$interface" ]; then
    dependence ip
    [ -n "$interface" ] || interface=`getInterface`
fi
IPv4="$ipAddr"; MASK="$ipMask"; GATE="$ipGate";
[ -n "$IPv4" ] && [ -n "$MASK" ] && [ -n "$GATE" ] && [ -n "$ipDNS" ] || {
  echo -ne '\nError: Invalid network config\n\n'
  exit 1;
}
if [ -z "$DISK" ]; then
  DISK=$(getDisk)
fi
[ -n "$DISK" ] || {
  echo -ne '\nError: Invalid disk config\n\n'
  exit 1;
}
if [ "$isRecovery" = "yes" ];then
  DDURL=""
  REBOOT=""
else
  validDD=$(validUrl $DDURL);
  while [ -z $validDD ];
  do
  {
        echo -n "Enter image URL : ";
        read DDURL;
        validDD=$(validUrl $DDURL);
        [ -z $validDD ] && echo 'Please input vaild URL,Only support http://, ftp:// and https:// !';
  }
  done;
fi
clear && echo -e "\n\033[36m# Install\033[0m\n"
yesno="n"
echo "Installer will reboot your computer then re-install with using these information";
if [ "$isDebug" = "yes" ];then
  REBOOT=""
fi
if [ -n "$DDURL" ];then
  DD=dd=$DISK="\"$DDURL\""
fi

GRUBDIR=/boot/grub;
GRUBFILE=grub.cfg

cat >/tmp/grub.new <<EndOfMessage
menuentry "TinyInstaller" {
  set isofile="/ti.iso"
  loopback loop \$isofile
  linux (loop)/boot/vmlinuz noswap ip=$IPv4:$MASK:$GATE $DD $REBOOT
  initrd (loop)/boot/core.gz
}
EndOfMessage

if [ ! -f $GRUBDIR/$GRUBFILE ];then
  echo "Grub config not found $GRUBDIR/$GRUBFILE"
  exit 2
fi
echo "";
echo "Image Url:  $DDURL";
echo "IPv4: $IPv4";
echo "MASK: $MASK";
echo "GATE: $GATE";
echo "DISK: $DISK";
if [ -n "$verbose" ];then
  echo "============================================"
  echo "Debug: $isDebug";
  echo "Recovery: $isRecovery";
  echo "Grub entry:"
  cat /tmp/grub.new
  echo "============================================"
fi
echo "";

if [ "$confirm" = "no" ];then
  echo -n "Start installation? (y,n) : ";
  read yesno;
  if [ "$yesno" != "y" ];then
    exit 1;
  fi
fi

BP=$(mount | grep -c -e "/boot ")
echo "Downloading TinyInstaller..."
if [ "${BP}" -gt 0 ];then
  wget --no-check-certificate -O /boot/ti.iso "$tiIso"
else
  wget --no-check-certificate -O /ti.iso "$tiIso"
fi

if [ ! -f /boot/ti.iso ] && [ ! -f /ti.iso ];then
  echo "Failed to download iso from $tiIso"
  exit 1;
fi


sed -i '$a\\n' /tmp/grub.new;
INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE;
sed -i ''${INSERTGRUB}'r /tmp/grub.new' $GRUBDIR/$GRUBFILE;
echo "Rebooting to installer..."
reboot


