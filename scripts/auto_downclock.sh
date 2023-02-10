#!/bin/sh
# Auto downclocking utility for MiSTer, by Natrox (c) 2023
#
#  Downclocks whenever the MiSTer is inactive, through checking whether
#  a controller is present. This utility checks for /dev/input/js0 by
#  default, which may not work with your setup.
#
#  If it detects disappearance of js0, it lowers the clock -
#  if it detects appearance of js0, it raises the clock.
#
#  Runs in the background until auto_downclock_stop is called.

# Important variables
CPU_FREQ_DEV="/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
CONTROLLER_DEV="/dev/input/js0"
BIN_SELF=`basename "$0"`

#  Current clock frequency
HIGH_CPU_FREQ=$(cat $CPU_FREQ_DEV)
#  Desired downclock frequency
LOW_CPU_FREQ=400000

#  Need to keep track of background process
PID_FILE="/tmp/auto_downclock.pid"

# This function is used to set the frequency
SET_CLOCK=$HIGH_CPU_FREQ
function SetCpuClock()
{
	echo $SET_CLOCK > $CPU_FREQ_DEV
}

# This function is called upon SIGINT
function CloseDown
{
	SET_CLOCK=$HIGH_CPU_FREQ SetCpuClock
	rm -rf $PID_FILE
	exit
}

# This function contains the logic that is run in the background.
function AutoDownclock()
{
	trap CloseDown INT # Shutdown handler

	PREV=0
	CUR=0

	while true
	do
		sleep 5
		stat -c %Y $CONTROLLER_DEV
		CUR=$(echo $?)

		if [ $CUR -ne $PREV ];
		then
			# The stat result determines the action to take
			if [ $CUR -ne 0 ];
			then
				# File has disappeared, downclock
				SET_CLOCK=$LOW_CPU_FREQ SetCpuClock
			else
				# File has appeared/changed, restore clock
				SET_CLOCK=$HIGH_CPU_FREQ SetCpuClock
			fi
		fi
		PREV=$CUR
	done
}


# Start of execution

# Check if PID is valid, in case a reboot was done.
# In case of invalid PID, remove it
if [ -f $PID_FILE ];
then
	CHECK_PID=$(cat $PID_FILE)
	PID_VALID=$(ps -f | grep $CHECK_PID | wc -l)

	if [ $PID_VALID -eq 1 ]; # Includes the grep itself too
	then
		echo "Removing remnant PID from previous run"
		rm -rf $PID_FILE
	fi
fi

echo "Attempting to start/stop auto downclocking process..."

if [ -f $PID_FILE ];
then
	kill -2 $(cat $PID_FILE)
	echo "The downclocking utility is stopping!"
	exit
fi

(AutoDownclock) 1>/dev/null 2>/dev/null &
echo $! > $PID_FILE;
sleep 1

if [ -f $PID_FILE ];
then
	echo "The downclocking utility has started!"
	echo "Run this script again to stop it."
	exit
else
	echo "Failed to launch the downclocking utility."
	exit
fi
