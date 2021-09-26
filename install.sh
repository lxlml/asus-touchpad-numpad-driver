#!/bin/bash

# Checking if the script is runned as root (via sudo or other)
if [[ $(id -u) != 0 ]]
then
	echo "Please run the installation script as root (using sudo for example)"
	exit 1
fi

if [[ $(sudo apt install 2>/dev/null) ]]; then
    echo 'apt is here' && sudo apt -y install libevdev2 python3-libevdev i2c-tools git
elif [[ $(sudo pacman -h 2>/dev/null) ]]; then
    echo 'pacman is here' && sudo pacman --noconfirm -S libevdev python-libevdev i2c-tools git
elif [[ $(sudo dnf install 2>/dev/null) ]]; then
    echo 'dnf is here' && sudo dnf -y install libevdev python-libevdev i2c-tools git
elif [[ $(sudo xbps-install 2> /dev/null) ]]; then
    echo 'xbps is here' && xbps-install -S libevdev python3-libevdev i2c-tools i2c-tools-devel git
fi

modprobe i2c-dev

# Checking if the i2c-dev module is successfuly loaded
if [[ $? != 0 ]]
then
	echo "i2c-dev module cannot be loaded correctly. Make sur you have installed i2c-tools package"
	exit 1
fi

interfaces=$(for i in $(i2cdetect -l | grep DesignWare | sed -r "s/^(i2c\-[0-9]+).*/\1/"); do echo $i; done)
if [ -z "$interfaces" ]
then
    echo "No interface i2c found. Make sure you have installed libevdev packages"
    exit 1
fi

touchpad_detected=false;
for i in $interfaces; do
    echo -n "Testing interface $i : ";
    number=$(echo -n $i | cut -d'-' -f2)
	offTouchpadCmd="i2ctransfer -f -y $number w13@0x15 0x05 0x00 0x3d 0x03 0x06 0x00 0x07 0x00 0x0d 0x14 0x03 0x00 0xad"
    i2c_test=$($offTouchpadCmd 2>&1)
    if [ -z "$i2c_test" ]
    then
        echo "sucess"
        touchpad_detected=true;
        break
    else
        echo "failed"
    fi
done;

if [ "$touchpad_detected" = false ] ; then
    echo 'The detection was not successful. Touchpad not found.'
    exit 1
fi

if [[ -d numpad_layouts/__pycache__ ]] ; then
    rm -rf numpad_layouts/__pycache__
fi

echo
echo "Select models keypad layout:"
PS3='Please enter your choice '
options=($(ls numpad_layouts) "Quit")
select opt in "${options[@]}"
do
    opt=${opt::-3}
    case $opt in
        "m433ia")
            model=m433ia
            break
            ;;
        "ux433fa")
            model=ux433fa
            break
            ;;
        "ux581l" )
            model=ux581l
            break
            ;;
        "Q")
            exit 0
            ;;
        *)
            echo "invalid option $REPLY";;
    esac
done

echo
echo "What is your keyboard layout?"
PS3='Please enter your choice [1-3]: '
options=("Qwerty" "Azerty" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Qwerty")
            percentage_key=6 # Number 5
            break
            ;;
        "Azerty")
            percentage_key=40 # Apostrophe key
            break
            ;;
        "Quit")
            exit 0
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

mkdir -p /etc/sv/asus-touchpad-service

echo "Added asus touchpad service in /etc/sv"
cat run | LAYOUT=$model PERCENTAGE_KEY=$percentage_key envsubst '$LAYOUT $PERCENTAGE_KEY' > /etc/sv/asus-touchpad-service/run
chmod +x /etc/sv/asus-touchpad-service/run

mkdir -p /usr/share/asus_touchpad_numpad-driver/numpad_layouts
mkdir -p /var/log/asus_touchpad_numpad-driver
install asus_touchpad.py /usr/share/asus_touchpad_numpad-driver/
install -t /usr/share/asus_touchpad_numpad-driver/numpad_layouts numpad_layouts/*.py

echo "i2c-dev" | tee /etc/modules-load.d/i2c-dev.conf >/dev/null

ln -s /etc/sv/asus-touchpad-service /var/service

if [[ $? != 0 ]]
then
	echo "Something has gone wrong while enabling the Asus touchpad runit service"
	exit 1
else
	echo "Asus touchpad service enabled"
fi


sleep 3

sv up asus-touchpad-service

if [[ $? != 0 ]]
then
	echo "Something has gone wrong while starting the Asus touchpad runit service"
	exit 1
else
	echo "Asus touchpad service started"
fi

exit 0

