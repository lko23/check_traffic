#!/bin/bash
#########################################################################
#
# File:         check_traffic.sh
# Description:  Nagios check plugins to check network interface traffic with SNMP run in *nix.
# Language:     GNU Bourne-Again SHell
# Version:	1.4.1
# Date:		2022-02-03
# Corp.:	Chenlei
# Author:	cloved@gmail.com, chnl@163.com (U can msn me with this), QQ 31017671
# WWW:		http://www.itnms.info
# Perl Version:	U Can find the perl/Net::SNMP Version in the same site.
#########################################################################
# Bugs:
# The Latest Version will be released in http://bbs.itnms.info.
# You can send bugs to http://bbs.itnms.info,
# or email to me directly: chnl@163.com or cloved@gmail.com
#########################################################################
# Todo:
# Do not use unit at performance data, for pnp/rrd graphing better.
# Add the History performance data file support.(maybe)
# Multi hosts and mult interfaces check function is a quick release, \
# need to review and process the code.
#########################################################################
# ChangeLog:
#
# Version 1.4.5
# 2023-01-10
# Retry once if old hist file
#
# Version 1.4.4
# 2023-01-10
# only use Last found interface
#
# Version 1.4.3
# 2022-08-08
# delete tmp file when unknown for clean retry.
#
# Version 1.4.2
# 2022-02-08
# Retry once when negative result
#
# Version 1.4.1
# 2022-02-03
# Case insensitive search for first occurence of pattern, cut index
#
# Version 1.4.0
# 2013-11-05
# Fix bug for Conter64 check.
#
############################
#
# Exit values:
# ------------
#    0		OK
#    1		Warning
#    2		Cirital
#    3		Unknown
#    Others	Unknown
#
# ----------------------------------------------------------------------
# These are Parameters from external
# -h 
#	Get the help message
#
# -v 
#	Verbose mode, to debug some messages out to the /tmp directory with log file name check_traffic.$$.
#
# -V    1|2c|3
#	Specify the version of snmp
#
# -C    Community
#	Specify the Community
#
# -H    host
#	Specify the host
#
# -6    Use 64 bit counter, ifHC*  instead of if*.
#
# -r    Use Range instead of single value in warning and critical Threshold;
#
# -I    interface
#	Specify the interface
#
# -N    interface name
#	Specify the interface name
#
# -L    List all Interfaces on specify host
#
# -B/b  Switch to B/s or bps, default is -b, bps
#
# -K/M  Switch to K or M (bsp,B/s), default is -K 
#
# -w    Warning value Kbps, in and out
# -c    Critical value Kbps, in and out
# 	Set Warning and Critical Traffic value
# -F    s/S 
#	Simple or more simple output format
#
# -p    number
#	It is a number that we comare this time value with the average value of previos N times we had been checked.
#	Suggestion values is from 4 to 12.
#
# -i	suffix
#	It's the individual suffix with the CF/STAT_HIST_DATA if necessary.
# -F	s/S
#	Get less output with s or S option.

unset LANG

Scale=2
Unit_1="K"
#IcingaWeb only accepts units with lenght of 1 or 2
#Unit_2="bps"
Unit_2="b"

UseRange="False"	

ifIn32="ifInOctets"
ifOut32="ifOutOctets"

ifIn64="ifHCInOctets"
ifOut64="ifHCOutOctets"
# Set the Min Interval of Check.
#Set Min_Interval to 5
#Min_Interval=30
Min_Interval=5
Max_Interval=1800
# Set the Default TIMEOUT. 
#Set Timeout 60
#Timeout=15
Timeout=60

print_help_msg(){
	print_version
	$Echo "Usage: $0 -h to get help."
	$Echo 
        $Echo 'Report bugs to: cloved@gmail.com'
        $Echo 'Home page: <http://bbs.itnms.info/forum.php?mod=viewthread&tid=767&extra=page%3D1>'
        $Echo 'Geting help: <http://bbs.itnms.info/forum.php?mod=forumdisplay&fid=10&page=1> or Email to: cloved@gmail.com'

}

print_full_help_msg(){
	print_version
	$Echo "Usage:"
	$Echo "$0 [ -v ] [ -6 ] [ -i Suffix ] [ -F s|S ] [-p N] [ -r ] -V 1|2c|3 ( -C snmp-community | -A \"AuthString\" (when use snmp v3, U must give the AuthString)) -H host [ -L ] (-I interface|-N interface name) -w in,out-warning-value  -c in,out-critical-value -K/M -B/b "

	$Echo "Example:"
	$Echo "${0} -V 2c -C public -H 127.0.0.1 -N FastEthernet0/1,FastEthernet0/2 -w 45,45 -c 55,55"
}

print_version(){
	$Echo $(cat $0 | head -n 7 | tail -n 1|sed 's/\# //')
}

print_err_msg(){
	$Echo "Error."
	print_full_help_msg
}

check_record_cnt(){
	echo $2 | awk -F "$1" '{print NF}'
}

list_interface(){
	$SNMPWALK -v $Version $Community $Host "IF-MIB::ifDescr" |sed 's/IF-MIB::ifDescr./Interface index /g' | sed 's/= STRING:/orresponding to /g'
	#exit 3

}

get_interface_index(){
        intNames="$1"
        intIndex=""
        intNameList=$(echo $intNames|sed 's/,/ /g')
        for intName in $intNameList
        do
# Case insensitive search for first occurence of pattern, cut index
# Only keep last found device
#               intIndex="$intIndex "$($SNMPWALK -v $Version $Community $Host "IF-MIB::ifDescr" |awk -F 'STRING: ' '{if ($2 == "'$intNameTemp'")print $0}' | awk -F '=' '{print $1}' | sed 's/IF-MIB::ifDescr.//')
#               intIndex="$intIndex "$($SNMPWALK -v $Version $Community $Host "IF-MIB::ifDescr" | grep -m 1 -iF $intName | cut -d "." -f 2 | cut -d "=" -f 1)
                Return=$($SNMPWALK -v $Version $Community $Host "IF-MIB::ifDescr" | grep -m 1 -iF $intName | cut -d "." -f 2 | cut -d "=" -f 1)
                if [ ! -z $Return ]; then
                intIndex=$Return
                fi
	done
}


gen_string(){
	string_num=$1
	string_i=1
	string_t=""
	string_p="NA "
	while [ $string_i -le $string_num ]
	do
		string_t="$string_t$string_p"
		string_i=`expr $string_i + 1`
	done
}

#adjust_value(){
#	if [ `echo "$1 < 1" | bc` -eq 1 ]; then
#		return "0"${$1} # if -lt 1, will error at: return: 0.1: numeric argument required
#	else
#		return $1
#	fi
#}

to_debug(){
if [ "$Debug" = "true" ]; then
	$Echo "$*" >> /tmp/check_traffic.log.$$ 2>&1
	#$Echo "$*" >> /tmp/check_traffic.log 2>&1
	if [ "$zDebug" = "true" ]; then
		$Echo "$*" 
	fi
fi
}


case "$(uname -s)"
	in
	SunOS)
	Echo="echo"
	;;
	Linux)
	Echo="echo -e"
	;;
	*)
	Echo="echo"
	;;
esac


if [ $# -lt 1 ]; then
	print_help_msg
	exit 3
else
	while getopts :vz6rhi:p:F:V:C:A:H:I:N:LKMBbw:c: OPTION
	do
		case $OPTION
			in
			v)
			#$Echo "Verbose mode."
			Debug=true
			;;
			z)
			zDebug=true
			;;

			V)
			Version=$OPTARG
			if [ $Version == "3" ]; then
				SnmpVersion=3
			fi
			;;
			C)
			Community=$OPTARG
			;;
			A)
			AuthString=$OPTARG
			;;
			i)
			Suffix="$OPTARG"	
			;;
			F)
			Format="$OPTARG"	
			;;
			6)
			Bit64="True"	
			;;
			p)
			Num="$OPTARG"	
			TrafficJitter="True"	
			;;
			r)
			UseRange="True"	
			;;
			H)
			Host=$OPTARG
			;;
			L)
			ListInt="True"
			;;
			I)
			Interface=$OPTARG
			;;
			N)
			UseIntName="True"
			InterfaceName=$OPTARG
			;;
			w)
			WarningV=$OPTARG
			;;
			c)
			CriticalV=$OPTARG
			;;
			M)
			isM="True"
			Unit_1="M"
			;;
			K)
			;;
			B)
			isB="True"
			Unit_2="B"
			;;
			b)
			;;
			h)
			print_full_help_msg
			exit 3
			;;
			?)
			$Echo "Error: Illegal Option."
			print_help_msg
			exit 3
			;;
		esac
	done
fi

SNMPWALK=`which snmpwalk 2>&1`
if [ $? -ne 0 ];then
	$Echo $SNMPWALK
	$Echo "Can not find command snmpwalk in you system PATH: $PATH, pleas check it"
	exit 3
fi
SNMPWALK="$SNMPWALK -t $Timeout -Oa"
to_debug Use $SNMPWALK to check traffic

SNMPGET=`which snmpget 2>&1`
if [ $? -ne 0 ];then
	$Echo $SNMPGET
	$Echo "Can not find command snmpget in you system PATH: $PATH, pleas check it"
	exit 3
fi
SNMPGET="$SNMPGET -t $Timeout -Oa"
to_debug Use $SNMPGET to check traffic


BC=`which bc 2>&1`
if [ $? -ne 0 ];then
	$Echo $BC
	$Echo "Can not find command bc in you system PATH: $PATH, pleas check it"
	exit 3
fi
to_debug Use $BC to calculate

if [ ! -z "$Interface" -a ! -z "$InterfaceName" ] ; then
	$Echo "Please Use -N or -I only"
	print_help_msg
	exit 3
fi

mmHostCnt=`check_record_cnt "," "$Host"`
mmCommunityCnt=`check_record_cnt "," "$Community"`
mmVersionCnt=`check_record_cnt "," "$Version"`

if [ "$UseIntName""ZZ" == "TrueZZ" ]; then
	Interface="$InterfaceName"
fi
mmIntCnt=`check_record_cnt "," "$Interface"`



if [ $mmHostCnt -gt 1 ]; then
#MM
	if [ $mmHostCnt -lt 1 -o  $mmCommunityCnt -lt 1 -o $mmVersionCnt -lt 1 -o $mmIntCnt -lt 1 ]; then
		$Echo "Args Error."
		print_full_help_msg
		exit 3
	fi
	
	if [ $mmHostCnt -ne $mmCommunityCnt -o $mmCommunityCnt -ne $mmVersionCnt -o  $mmVersionCnt -ne $mmIntCnt ]; then
		$Echo "Args Error."
		print_full_help_msg
		exit 3
	fi

	mmHostList=$(echo $Host|sed 's/,/ /g')
	mmCommunityList=$(echo $Community|sed 's/,/ /g')
	mmVersionList=$(echo $Version|sed 's/,/ /g')
	mmIntList=$(echo $Interface|sed 's/,/ /g')
	mmIntNameList=$(echo $InterfaceName|sed 's/,/ /g')
	
	mmHostArray=($mmHostList)
	mmCommunityArray=($mmCommunityList)
	mmVersionArray=($mmVersionList)
	mmIntArray=($mmIntList)
	mmIntNameArray=($mmIntNameList)

	
	##MMArray Data Struct
	#MMArray[0](Host Community Version Interface InterfaceName)
	#             0      1        2        3           4
	#MMArray[...]
	##
	declare -a MMArray
	Columns=5
	Rows=$mmHostCnt

	#init ctbspIn/ctbspOut
	ctbpsIn=0
	ctbpsOut=0
	#init ctDiffRIAVG/ctDiffROAVG
	ctDiffRIAVG=0
	ctDiffROAVG=0
	
	for mmII in `seq 1 $mmHostCnt`
	do
		let "aIndex = $mmII - 1"
	
		let "mmIndex = $aIndex * $Columns + 0"
		MMArray[$mmIndex]=${mmHostArray[$aIndex]}
		Host=${MMArray[$mmIndex]}
		to_debug MMArray host  "${MMArray[$mmIndex]}"
	
		let "mmIndex = $aIndex * $Columns + 1"
		MMArray[$mmIndex]=${mmCommunityArray[$aIndex]}
		Community=${MMArray[$mmIndex]}
		to_debug MMArray community "${MMArray[$mmIndex]}"
	
		let "mmIndex = $aIndex * $Columns + 2"
		MMArray[$mmIndex]=${mmVersionArray[$aIndex]}
		Version=${MMArray[$mmIndex]}
		to_debug MMArray version "${MMArray[$mmIndex]}"
	
		let "mmIndex = $aIndex * $Columns + 3"
		MMArray[$mmIndex]=${mmIntArray[$aIndex]}
		Interface=${MMArray[$mmIndex]}
		to_debug MMArray int "${MMArray[$mmIndex]}"
		
		let "mmIndex = $aIndex * $Columns + 4"
		MMArray[$mmIndex]=${mmIntNameArray[$aIndex]}
		InterfaceName=${MMArray[$mmIndex]}
		to_debug MMArray int "${MMArray[$mmIndex]}"
		



		if [ -z "$Version" -o -z "$Host" ] ; then
			$Echo "Args Error."
			print_full_help_msg
			exit 3
		fi
		
		if [ "$SnmpVersion" = "3" ]; then
			if [ -z "$AuthString" ]; then
				$Echo "Args Error."
				print_full_help_msg
				exit 3
			else
				Community="$AuthString"
			fi
		else
			if [ -z "$Community" ]; then
				$Echo "Args Error."
				print_full_help_msg
				exit 3
			else
				Community=" -c $Community"
			fi
		fi
		
		if [ "$UseIntName""ZZ" == "TrueZZ" ]; then
			get_interface_index $InterfaceName
			Interface=$intIndex
			if [ -z "$Interface"  -o "$Interface" == " " ] ; then
				$Echo Can not get the interface index with "$InterfaceName" at "$Host".
				exit 3
			fi
			Interface=$(echo $Interface|sed 's/ /,/g')
		fi	
	
	
		
		if [ "$ListInt" = "True" ]; then
			$Echo "List Interface for host $Host."
			list_interface
			exit 3
		fi
		
		
		
		
		
		if [ -z "$Interface" -o -z "$WarningV" -o -z "$CriticalV" ] ; then
			$Echo "Args Error."
			print_full_help_msg
			exit 3
		fi
		
		to_debug All Values  are \" Warning: "$WarningV" and Critical: "$CriticalV" \".
		WVC=`check_record_cnt "," "$WarningV"`
		CVC=`check_record_cnt "," "$CriticalV"`
		to_debug WVC is $WVC and CVC is $CVC
		
		if [ $UseRange = "True" ] ;then
			to_debug UseRange is True
			#####################
			if [ $WVC -ne 2 -o $CVC -ne 2 ] ; then
				$Echo "Warning and Critical Value error."
				print_full_help_msg
				exit 3
			else
				W1=`echo $WarningV| awk -F "," '{print $1}'`
				W1b=`echo $W1| awk -F "-" '{print $1}'`
				W1e=`echo $W1| awk -F "-" '{print $2}'`
		
				W2=`echo $WarningV| awk -F "," '{print $2}'`
				W2b=`echo $W2| awk -F "-" '{print $1}'`
				W2e=`echo $W2| awk -F "-" '{print $2}'`
		
				Wtb=`echo "$W1b + $W2b"|bc`
				Wte=`echo "$W1e + $W2e"|bc`
				to_debug Warning Value is $W1 $W2 $Wtb $Wte
			
				C1=`echo $CriticalV| awk -F "," '{print $1}'`
				C1b=`echo $C1| awk -F "-" '{print $1}'`
				C1e=`echo $C1| awk -F "-" '{print $2}'`
		
				C2=`echo $CriticalV| awk -F "," '{print $2}'`
				C2b=`echo $C2| awk -F "-" '{print $1}'`
				C2e=`echo $C2| awk -F "-" '{print $2}'`
		
				Ctb=`echo "$C1b + $C2b"|bc`
				Cte=`echo "$C1e + $C2e"|bc`
		
				to_debug Critical Value is $C1 $C2 $Ctb $Cte
				
				check_1b=`echo "$C1b < $W1b" | bc`
				check_1e=`echo "$C1e > $W1e" | bc`
		
				check_2b=`echo "$C2b < $W2b" | bc`
				check_2e=`echo "$C2e > $W2e" | bc`
				to_debug check_1 is $check_1b , $check_1e check_2 is $check_2b $check_2e
			
				if [ $check_1b -ne 1 -o $check_1e -ne 1 -o  $check_2b -ne 1 -o  $check_2e -ne 1 ] ; then
					$Echo "Error, the corresponding Critical End value must greater than Warning End value, And Critical Begin value must less than Warning End value"
					print_full_help_msg
					exit 3
				fi
			
			fi
		
			#####################
			
			
		else
			to_debug Use Range is False
		
			if [ $WVC -ne 2 -o $CVC -ne 2 ] ; then
				$Echo "Warning and Critical Value error."
				print_full_help_msg
				exit 3
			else
				W1=`echo $WarningV| awk -F "," '{print $1}'`
				W2=`echo $WarningV| awk -F "," '{print $2}'`
				Wt=`echo "$W1 + $W2"|bc`
				to_debug Warning Value is $W1 $W2 $Wt
			
				C1=`echo $CriticalV| awk -F "," '{print $1}'`
				C2=`echo $CriticalV| awk -F "," '{print $2}'`
				Ct=`echo "$C1 + $C2"|bc`
				to_debug Critical Value is $C1 $C2 $Ct
				
				check_1=`echo "$C1 > $W1" | bc`
				check_2=`echo "$C2 > $W2" | bc`
				to_debug check_1 is $check_1 , check_2 is $check_2 
			
				if [ $check_1 -ne 1 -o  $check_2 -ne 1 ] ; then
					$Echo "Error, the corresponding Critical value must greater than Warning value."
					print_full_help_msg
					exit 3
				fi
			
			fi
		fi
		
		if [ -z $Suffix ]; then
			Suffix=itnms
		fi
		if [ $TrafficJitter"AA" = "TrueAA" ]; then
			Suffix=${Suffix}J
		fi
		
		if [ $UseRange = "True" ] ;then
			Suffix=${Suffix}R
		fi
		
		Username=`id --user --name`
		# This file will save the traffic data from previos check.
		# Make sure it will never be deleted.
		CF_HIST_DATA="/var/tmp/check_traffic_${Host}_${Interface}_MM_${Username}_${Suffix}.hist_dat"
		to_debug CF_HIST_DATA "$CF_HIST_DATA"
		
		Time=`date +%s`
		
		ifName="`$SNMPGET -v $Version  $Community $Host IF-MIB::ifDescr.${Interface}| awk -F ":" '{print $4}'`"
		ifSpeed="`$SNMPGET -v $Version $Community $Host IF-MIB::ifSpeed.${Interface}| awk -F ":" '{print $4}'`"
		Flag64Content=`$SNMPGET -v $Version $Community $Host IF-MIB::ifHCOutOctets.${Interface}  2>&1`
		if [ $? -eq 0 ]; then
			echo $Flag64Content |grep Counter64 >/dev/null 2>&1
			Flag64=$?
			if [ $Flag64 -eq 0  -a "$Version" = "2c" ];then
				ifIn=$ifIn64
				ifOut=$ifOut64
				BitSuffix=64
			fi
		else
			ifIn=$ifIn32
			ifOut=$ifOut32
			BitSuffix=32
			if [ "$Bit64" = "True" ] ;then
				$Echo "Maybe your Host(device) not support 64 bit counter. Please confirm your ARGS and re-check it with Verbose mode, then to check the log.(If you snmp not support 64 bit counter, do not use -6 option)"
				exit 3
			fi
		
		fi
		
		#set CF_HIST_DATA File Name
		CF_HIST_DATA=${CF_HIST_DATA}_${BitSuffix}
		
		#set STAT_HIST_DATA File Name
		STAT_HIST_DATA=${CF_HIST_DATA}_ctj_$Num
		
		if [ ! -f $CF_HIST_DATA ]; then
			IsFirst="True"
			touch $CF_HIST_DATA
			if [ $? -ne 0 ];then
				Severity=3
				Msg="Unknown"
				OutPut="Create File $CF_HIST_DATA Error with user `id`."
				$Echo "$Msg" "-" $OutPut
				exit $Severity
			fi
		
		fi
			
		if [ ! -r  $CF_HIST_DATA -o ! -w  $CF_HIST_DATA ]; then
			Severity=3
			Msg="Unknown"
			OutPut="Read or Write File $CF_HIST_DATA Error with user `id`."
			$Echo "$Msg" "-" $OutPut
			exit $Severity
		fi
		
		
		if [ $TrafficJitter"AA" = "TrueAA" ]; then
			if [ ! -f $STAT_HIST_DATA ]; then
				touch $STAT_HIST_DATA
				IsStatFirst="True"
				if [ $? -ne 0 ];then
					Severity=3
					Msg="Unknown"
					OutPut="Create File $STAT_HIST_DATA Error with user `id`."
					$Echo "$Msg" "-" $OutPut
					exit $Severity
				fi
				if [ ! -r  $STAT_HIST_DATA -o ! -w  $STAT_HIST_DATA ]; then
					Severity=3
					Msg="Unknown"
					OutPut="Read or Write File $STAT_HIST_DATA Error with user `id`."
					$Echo "$Msg" "-" $OutPut
					exit $Severity
				fi
				gen_string $Num
				to_debug string_t $string_t
				TC=0
				TRI=($string_t)
				TRO=($string_t)
				echo $TC >$STAT_HIST_DATA
				echo ${TRI[@]} >>$STAT_HIST_DATA
				echo ${TRO[@]} >>$STAT_HIST_DATA
			fi
		
			C=(`head -n 1 $STAT_HIST_DATA`)
			RI=(`head -n 2 $STAT_HIST_DATA|tail -n 1 `)
			RO=(`tail -n 1 $STAT_HIST_DATA`)
			to_debug C RI RO $C $RI $RO
			to_debug C RI RO $C ${RI[@]} ${RO[@]}
			to_debug C N $C $Num
		
		fi
		_result_status=`$SNMPGET -v $Version $Community $Host "IF-MIB::ifOperStatus.${Interface}"| awk '{print $4}' | awk -F '(' '{print $1}'`
		if [ "$_result_status" != "up" ]; then
			$Echo "The Interface name:${ifName} -- index:${Interface} you checked seems not up."
			exit 3
		fi
		
		
		
	
		_result_in=`$SNMPGET -v $Version $Community $Host "IF-MIB::${ifIn}"."$Interface"`
		_result_out=`$SNMPGET -v $Version $Community $Host "IF-MIB::${ifOut}"."$Interface" `
		to_debug time is $Time, $SNMPGET check result in is $_result_in, out is $_result_out
		
		_result_in=`echo $_result_in |awk '{print $4}'`
		_result_out=`echo $_result_out|awk '{print $4}'`
		to_debug time is $Time, $SNMPGET check result in is $_result_in, out is $_result_out
		
		if [ -z "$_result_in" -o -z "$_result_out" ] ; then
			$Echo "No Data been get here. Please confirm your ARGS and re-check it with Verbose mode, then to check the log.(If you snmp not support 64 bit counter, do not use -6 option)"
			exit 3
		fi
		
		In=`echo "$_result_in * 8 " |bc`
		Out=`echo "$_result_out * 8 " |bc`
		to_debug Index is $index Time is $Time, In is $In, Out is $Out
		
		
		HistData=`cat $CF_HIST_DATA| head -n 1`
		HistTime=`echo $HistData| awk -F "|" '{print $1}'|sed 's/ //g'`
		HistIn=`echo $HistData| awk -F "|" '{print $2}'|sed 's/ //g'`
		HistOut=`echo $HistData| awk -F "|" '{print $3}'|sed 's/ //g'`
		to_debug HistData is $HistData HistTime is $HistTime, HistIn is $HistIn, HistOut is $HistOut
		
		if [ -z "$HistTime" -o -z "$HistIn" -o -z "$HistOut" ] ; then
			if [ "$IsFirst" = "True" ]; then
				#If there is a empty hist file, can write the data before exit(for the reason of IsFirst),
				#the data can be used for next time.
				echo "$Time|$In|$Out" > $CF_HIST_DATA
				to_debug "$Time|$In|$Out"  $CF_HIST_DATA
				continue
			else
				# Delete File for clean retry
				rm $CF_HIST_DATA
				Severity="3"
				Msg="Unknown"
				OutPut="Can not find data in the history data file. The file $CF_HIST_DATA was deleted for a clean retry." 
				$Echo "$Msg" "-" $OutPut
				exit $Severity
			fi
		else
			Interval=`echo "$Time - $HistTime" | bc`
			if [ $Interval -lt $Min_Interval ] ; then
				$Echo "The check interval must greater than $Min_Interval Seconds. But now it is $Interval. Please retry it later."
				exit 3
			fi
		
			#echo DEBUG here: data of $Host $Interface $ifName "$Time|$In|$Out"
			to_debug DEBUG here: data of $Host $Interface $ifName "$Time|$In|$Out"
			echo "$Time|$In|$Out" > $CF_HIST_DATA
		
			if [ $? -ne 0 ];then
				Severity=3
				Msg="Unknown"
				OutPut="Write File $CF_HIST_DATA Error with user `id`."
				$Echo "$Msg" "-" $OutPut
				exit $Severity
			fi
		
			if [ $Interval -gt $Max_Interval ] ; then
                        	# Retry
                        	sleep 5
                        	/usr/lib/icinga2/custom_plugins/check_traffic.sh "$@"
                        	if [ $? -eq 0 ]; then
                               		exit 0
                        	fi
				$Echo "The check interval is too large. It is greater than $Max_Interval. The result is dropped. We will use fresh data at the next check."
				exit 3
			fi
		fi
		
		DiffIn=`echo "$In - $HistIn" | bc`
		DiffOut=`echo "$Out - $HistOut" | bc`
		to_debug Interval/DiffIn/DiffOut $Interval $DiffIn $DiffOut 
		
		if [ ` echo " $Interval > 0 " |bc ` -eq 0 ] ; then
                        #Retry
                        sleep 5
                        /usr/lib/icinga2/custom_plugins/check_traffic.sh "$@"
                        if [ $? -eq 0 ]; then
				exit 0
			fi
			$Echo  "we got a negative time interval value here. Return "$?"."
                        exit 3
		fi
		
		if [ ` echo " $DiffOut >= 0 " |bc ` -eq 0 -o  ` echo " $DiffIn >= 0 " |bc ` -eq 0 ] ; then
                        #Retry
                        sleep 5
	                /usr/lib/icinga2/custom_plugins/check_traffic.sh "$@"
                        if [ $? -eq 0 ]; then
	                        exit 0
                        fi
			$Echo  "Maybe 32 bit counter overflow, because we got a negative value here. Return "$?"."
			exit 3
		fi
		
		
		bpsIn=`echo "$DiffIn / $Interval" | bc`
		bpsOut=`echo "$DiffOut / $Interval" | bc`
		to_debug bpsIn/bpsOut $bpsIn $bpsOut 
		
		#Comment to fix the bug when high traffic occurs , or in some virtual environment.
		#if [ $bpsIn -gt $ifSpeed -o $bpsOut -gt $ifSpeed ]; then
		#	$Echo  "OOPS. We get a value bigger than ifSpeed here. Something is wrong. Maybe a check from 32bit to 64bit transfer, or any other error here."
		#	exit 3
		#fi
		
		
		if [ $TrafficJitter"AA" = "TrueAA" ]; then
			if [ $C -lt $Num ]; then
				to_debug we have not the enough data to calculating.
				RI[$C]=$bpsIn
				RO[$C]=$bpsOut
				to_debug C $C 
				C=`expr $C + 1`
			
				echo $C >$STAT_HIST_DATA
				echo ${RI[@]} >>$STAT_HIST_DATA
				echo ${RO[@]} >>$STAT_HIST_DATA
				isNotEnough=True
				continue
			else
				to_debug we have the enough data to calculating.
				RIAVG=0
				ROAVG=0
			
				lenRI=${#RI[@]}
				to_debug lenRI is $lenRI
				rii=0
			
				while [ $rii -lt $lenRI ]
				do
					to_debug hist: rii $rii
					to_debug hist: rii RI[rii] $rii ${RI[$rii]}
					to_debug hist: rii RO[rii] $rii ${RO[$rii]}
					RIAVG=`echo "scale=$Scale; $RIAVG + ${RI[$rii]} " |bc`
					ROAVG=`echo "scale=$Scale; $ROAVG + ${RO[$rii]} " |bc`
					let rii++
					to_debug RIAVG $RIAVG
					to_debug ROAVG $ROAVG
				done
				to_debug RIAVG $RIAVG
				to_debug ROAVG $ROAVG
				RIAVG=`echo "scale=$Scale; $RIAVG / $Num " |bc`
				ROAVG=`echo "scale=$Scale; $ROAVG / $Num " |bc`
				to_debug RIAVG $RIAVG
				to_debug ROAVG $ROAVG
			
				rii=0
				while [ $rii -lt `expr $lenRI - 1` ]
				do
					RI[$rii]=${RI[`expr $rii + 1`]}
					RO[$rii]=${RO[`expr $rii + 1`]}
					to_debug new: rii RI[rii] $rii ${RI[`expr $rii + 1 `]}
					to_debug new: rii RO[rii] $rii ${RO[`expr $rii + 1 `]}
					let rii++
				done
				RI[$rii]=$bpsIn
				RO[$rii]=$bpsOut
				echo $C >$STAT_HIST_DATA
				echo ${RI[@]} >>$STAT_HIST_DATA
				echo ${RO[@]} >>$STAT_HIST_DATA

				DiffRIAVG=`echo "scale=$Scale; $bpsIn - $RIAVG" |bc`	
				DiffROAVG=`echo "scale=$Scale; $bpsOut - $ROAVG" |bc`	
				to_debug DiffRIAVG $DiffRIAVG
				to_debug DiffROAVG $DiffROAVG
		
				DiffRIAVG=`echo $DiffRIAVG | sed 's/-//'`
				DiffROAVG=`echo $DiffROAVG | sed 's/-//'`
				to_debug DiffRIAVG $DiffRIAVG
				to_debug DiffROAVG $DiffROAVG
		
		
				DiffRIAVG=`echo "scale=$Scale; $DiffRIAVG / $RIAVG * 100 " |bc`	
				DiffROAVG=`echo "scale=$Scale; $DiffROAVG / $ROAVG  * 100" |bc`	
				DiffAVGTotal=`echo "scale=$Scale; $DiffRIAVG  + $DiffROAVG" |bc`
				to_debug DiffRIAVG $DiffRIAVG
				to_debug DiffROAVG $DiffROAVG
				to_debug DiffAVGTotal $DiffAVGTotal
				
			fi
			ctDiffRIAVG=`echo "scale=$Scale; $ctDiffRIAVG + $DiffRIAVG" |bc`
			ctDiffROAVG=`echo "scale=$Scale; $ctDiffROAVG + $DiffROAVG" |bc`
			to_debug ctDiffRIAVG $ctDiffRIAVG
			to_debug ctDiffROAVG $ctDiffROAVG
		
		else
		
			#aggreating data
			ctbpsIn=`echo $ctbpsIn + $bpsIn|bc`
			ctbpsOut=`echo $ctbpsOut + $bpsOut|bc`
		
		fi



	done

	if [ "$isNotEnough" = "True" ]; then
		$Echo "OK - There was only `echo $C -1 |bc` hist data before this check. We need the $Num hist data to use for calculating. Please wait."
		exit 0
	fi
	
	if [ "$IsFirst" = "True" ]; then
		Severity="0"
		Msg="OK"
		OutPut="It is the first time of this plugins to run, or some data file lost. We will get the data from the next time."
		$Echo "$Msg" "-" $OutPut
		exit $Severity
	fi

	DiffRIAVG=`echo "scale=$Scale; $ctDiffRIAVG / $mmIntCnt" |bc`
	DiffROAVG=`echo "scale=$Scale; $ctDiffROAVG / $mmIntCnt" |bc`
	DiffAVGTotal=`echo "scale=$Scale; $DiffRIAVG  + $DiffROAVG" |bc`
	to_debug DRIA $DiffRIAVG DROA $DiffROAVG DAVGT $DiffAVGTotal

#End of MM
else
#SM or SS
	if [ -z "$Version" -o -z "$Host" ] ; then
		$Echo "Args Error."
		print_full_help_msg
		exit 3
	fi
	
	if [ "$SnmpVersion" = "3" ]; then
		if [ -z "$AuthString" ]; then
			$Echo "Args Error."
			print_full_help_msg
			exit 3
		else
			Community="$AuthString"
		fi
	else
		if [ -z "$Community" ]; then
			$Echo "Args Error."
			print_full_help_msg
			exit 3
		else
			Community=" -c $Community"
		fi
	fi
	
	if [ "$UseIntName""ZZ" == "TrueZZ" ]; then
		get_interface_index $InterfaceName
		Interface=$intIndex
		if [ -z "$Interface"  -o "$Interface" == " " ] ; then
			$Echo Can not get the interface index with "$InterfaceName" at "$Host".
			exit 3
		fi
		Interface=$(echo $Interface|sed 's/ /,/g')
	fi	


	
	if [ "$ListInt" = "True" ]; then
		$Echo "List Interface for host $Host."
		list_interface
		exit 3
	fi
	
	
	
	
	
	if [ -z "$Interface" -o -z "$WarningV" -o -z "$CriticalV" ] ; then
		$Echo "Args Error."
		print_full_help_msg
		exit 3
	fi
	
	to_debug All Values  are \" Warning: "$WarningV" and Critical: "$CriticalV" \".
	WVC=`check_record_cnt "," "$WarningV"`
	CVC=`check_record_cnt "," "$CriticalV"`
	to_debug WVC is $WVC and CVC is $CVC
	
	if [ $UseRange = "True" ] ;then
		to_debug UseRange is True
		#####################
		if [ $WVC -ne 2 -o $CVC -ne 2 ] ; then
			$Echo "Warning and Critical Value error."
			print_full_help_msg
			exit 3
		else
			W1=`echo $WarningV| awk -F "," '{print $1}'`
			W1b=`echo $W1| awk -F "-" '{print $1}'`
			W1e=`echo $W1| awk -F "-" '{print $2}'`
	
			W2=`echo $WarningV| awk -F "," '{print $2}'`
			W2b=`echo $W2| awk -F "-" '{print $1}'`
			W2e=`echo $W2| awk -F "-" '{print $2}'`
	
			Wtb=`echo "$W1b + $W2b"|bc`
			Wte=`echo "$W1e + $W2e"|bc`
			to_debug Warning Value is $W1 $W2 $Wtb $Wte
		
			C1=`echo $CriticalV| awk -F "," '{print $1}'`
			C1b=`echo $C1| awk -F "-" '{print $1}'`
			C1e=`echo $C1| awk -F "-" '{print $2}'`
	
			C2=`echo $CriticalV| awk -F "," '{print $2}'`
			C2b=`echo $C2| awk -F "-" '{print $1}'`
			C2e=`echo $C2| awk -F "-" '{print $2}'`
	
			Ctb=`echo "$C1b + $C2b"|bc`
			Cte=`echo "$C1e + $C2e"|bc`
	
			to_debug Critical Value is $C1 $C2 $Ctb $Cte
			
			check_1b=`echo "$C1b < $W1b" | bc`
			check_1e=`echo "$C1e > $W1e" | bc`
	
			check_2b=`echo "$C2b < $W2b" | bc`
			check_2e=`echo "$C2e > $W2e" | bc`
			to_debug check_1 is $check_1b , $check_1e check_2 is $check_2b $check_2e
		
			if [ $check_1b -ne 1 -o $check_1e -ne 1 -o  $check_2b -ne 1 -o  $check_2e -ne 1 ] ; then
				$Echo "Error, the corresponding Critical End value must greater than Warning End value, And Critical Begin value must less than Warning End value"
				print_full_help_msg
				exit 3
			fi
		
		fi
	
		#####################
		
		
	else
		to_debug Use Range is False
	
		if [ $WVC -ne 2 -o $CVC -ne 2 ] ; then
			$Echo "Warning and Critical Value error."
			print_full_help_msg
			exit 3
		else
			W1=`echo $WarningV| awk -F "," '{print $1}'`
			W2=`echo $WarningV| awk -F "," '{print $2}'`
			Wt=`echo "$W1 + $W2"|bc`
			to_debug Warning Value is $W1 $W2 $Wt
		
			C1=`echo $CriticalV| awk -F "," '{print $1}'`
			C2=`echo $CriticalV| awk -F "," '{print $2}'`
			Ct=`echo "$C1 + $C2"|bc`
			to_debug Critical Value is $C1 $C2 $Ct
			
			check_1=`echo "$C1 > $W1" | bc`
			check_2=`echo "$C2 > $W2" | bc`
			to_debug check_1 is $check_1 , check_2 is $check_2 
		
			if [ $check_1 -ne 1 -o  $check_2 -ne 1 ] ; then
				$Echo "Error, the corresponding Critical value must greater than Warning value."
				print_full_help_msg
				exit 3
			fi
		
		fi
	fi
	
	if [ -z $Suffix ]; then
		Suffix=itnms
	fi
	if [ $TrafficJitter"AA" = "TrueAA" ]; then
		Suffix=${Suffix}J
	fi
	
	if [ $UseRange = "True" ] ;then
		Suffix=${Suffix}R
	fi
	
	# This file will save the traffic data from previos check.
	# Make sure it will never be deleted.
	IntCnt=`check_record_cnt "," "$Interface"`
	to_debug Interface count  $IntCnt
	
	if [ $IntCnt -gt 1 ];then
		isSMInt="True"
	fi
	to_debug isSMInt is $isSMInt
	
	
	##SMArray Data Struct
	#SMArray[0](ifIndex CF_HIST_DATA ifName ifSpeed STAT_HIST_DATA Time In Out Htime HIn HOut Interval DiffIn DiffOut bpsIn bpsOut Num  C   RI  RO)
	#             0          1         2      3            4         5   6  7    8    9   10     11     12      13     14     15    16  17  18  19
	#SMArray[...]
	##
	declare -a SMArray
	Columns=24
	Rows=$IntCnt
	
	Interface=`echo $Interface|sed 's/,/ /g'`
	SMInterfaces=($Interface)
	
	for ii in `seq 1 $IntCnt`
	do
		let "rIndex = $ii - 1"
	
		let "index = $rIndex * $Columns + 0"
		SMArray[$index]=${SMInterfaces[$rIndex]}
		to_debug SMArray ifIndex  "${SMArray[$index]}"
	
		if [ "$isSMInt" = "True" ];then
			CF_HIST_DATA="/var/tmp/check_traffic_${Host}_${SMArray[$index]}_SM_${Username}_${Suffix}.hist_dat"
		else
			CF_HIST_DATA="/var/tmp/check_traffic_${Host}_${SMArray[$index]}_${Username}_${Suffix}.hist_dat"
		fi
		to_debug CF_HIST_DATA "$CF_HIST_DATA"
	
		let "index = $rIndex * $Columns + 1"
		SMArray[$index]=$CF_HIST_DATA
		to_debug SMArray CF_HIST_DATA "${SMArray[$index]}"
	done
		
	to_debug SMArray[@] ${SMArray[@]}
	
	
	Time=`date +%s`
	
	for ii in `seq 1 $IntCnt`
	do
		let "rIndex = $ii - 1"
		let "index = $rIndex * $Columns + 0"
		ifName="`$SNMPGET -v $Version  $Community $Host IF-MIB::ifDescr.${SMArray[$index]}| awk -F ":" '{print $4}'`"
		ifSpeed="`$SNMPGET -v $Version $Community $Host IF-MIB::ifSpeed.${SMArray[$index]}| awk -F ":" '{print $4}'`"
		to_debug ifIndex ${SMArray[$index]}

		Flag64ContentSM=`$SNMPGET -v $Version $Community $Host IF-MIB::ifHCOutOctets.${SMArray[$index]}   2>&1`
		echo $Flag64ContentSM |grep Counter64 >/dev/null 2>&1
		Flag64=$?
		if [ $Flag64 -eq 0  -a "$Version" = "2c" ]; then
			ifIn=$ifIn64
			ifOut=$ifOut64
			BitSuffix=64
		else
			ifIn=$ifIn32
			ifOut=$ifOut32
			BitSuffix=32
			if [ "$Bit64" = "True" ] ;then
				$Echo "Maybe your Host(device) not support 64 bit counter. Please confirm your ARGS and re-check it with Verbose mode, then to check the log.(If you snmp not support 64 bit counter, do not use -6 option)"
				exit 3
			fi
		
		fi
	
		let "index = $rIndex * $Columns + 1"
		to_debug CF_HIST_DATA ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 2"
		SMArray[$index]=${ifName}
		to_debug ifName ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 3"
		SMArray[$index]=${ifSpeed}
		to_debug ifSpeed ${SMArray[$index]}
	done
	to_debug  SMArray[@] ${SMArray[@]}
	
	
	for ii in `seq 1 $IntCnt`
	do
		let "rIndex = $ii - 1"
		let "index = $rIndex * $Columns + 1"
		#set CF_HIST_DATA File Name
		CF_HIST_DATA=${SMArray[$index]}_${BitSuffix}
		SMArray[$index]=$CF_HIST_DATA
		to_debug CF_HIST_DATA ${SMArray[$index]}
	
		#set STAT_HIST_DATA File Name
		let "index = $rIndex * $Columns + 4"
		STAT_HIST_DATA=${CF_HIST_DATA}_ctj_$Num
		SMArray[$index]=$STAT_HIST_DATA
		to_debug STAT_HIST_DATA ${SMArray[$index]}
	done
	
	for ii in `seq 1 $IntCnt`
	do
		let "rIndex = $ii - 1"
		let "index = $rIndex * $Columns + 1"
		CF_HIST_DATA=${SMArray[$index]}
		to_debug CF_HIST_DATA ${SMArray[$index]}
	
		if [ ! -f $CF_HIST_DATA ]; then
			IsFirst="True"
			touch $CF_HIST_DATA
			if [ $? -ne 0 ];then
				Severity=3
				Msg="Unknown"
				OutPut="Create File $CF_HIST_DATA Error with user `id`."
				$Echo "$Msg" "-" $OutPut
				exit $Severity
			fi
		
		fi
		
		if [ ! -r  $CF_HIST_DATA -o ! -w  $CF_HIST_DATA ]; then
			Severity=3
			Msg="Unknown"
			OutPut="Read or Write File $CF_HIST_DATA Error with user `id`."
			$Echo "$Msg" "-" $OutPut
			exit $Severity
		fi
	done
	
	if [ $TrafficJitter"AA" = "TrueAA" ]; then
		for ii in `seq 1 $IntCnt`
		do
			let "rIndex = $ii - 1"
			let "index = $rIndex * $Columns + 4"
			STAT_HIST_DATA=${SMArray[$index]}
			to_debug STAT_HIST_DATA ${SMArray[$index]}
	
			if [ ! -f $STAT_HIST_DATA ]; then
				touch $STAT_HIST_DATA
				IsStatFirst="True"
				if [ $? -ne 0 ];then
					Severity=3
					Msg="Unknown"
					OutPut="Create File $STAT_HIST_DATA Error with user `id`."
					$Echo "$Msg" "-" $OutPut
					exit $Severity
				fi
				if [ ! -r  $STAT_HIST_DATA -o ! -w  $STAT_HIST_DATA ]; then
					Severity=3
					Msg="Unknown"
					OutPut="Read or Write File $STAT_HIST_DATA Error with user `id`."
					$Echo "$Msg" "-" $OutPut
					exit $Severity
				fi
				gen_string $Num
				to_debug string_t $string_t
				TC=0
				TRI=($string_t)
				TRO=($string_t)
				echo $TC >$STAT_HIST_DATA
				echo ${TRI[@]} >>$STAT_HIST_DATA
				echo ${TRO[@]} >>$STAT_HIST_DATA
			fi
		
			C=(`head -n 1 $STAT_HIST_DATA`)
			RI=(`head -n 2 $STAT_HIST_DATA|tail -n 1 `)
			RO=(`tail -n 1 $STAT_HIST_DATA`)
			to_debug C RI RO $C $RI $RO
			to_debug C RI RO $C ${RI[@]} ${RO[@]}
			to_debug C N $C $Num
	
			let "index = $rIndex * $Columns + 16"
			SMArray[$index]=${Num}
			to_debug Num ${SMArray[$index]}
	
			let "index = $rIndex * $Columns + 17"
			SMArray[$index]=${C}
			to_debug C ${SMArray[$index]}
	
			let "index = $rIndex * $Columns + 18"
			SMArray[$index]=${RI[@]}
			to_debug RI ${SMArray[$index]}
	
			let "index = $rIndex * $Columns + 19"
			SMArray[$index]=${RO[@]}
			to_debug RO ${SMArray[$index]}
	
		done
	fi
	
	for ii in `seq 1 $IntCnt`
	do
		let "rIndex = $ii - 1"
		let "index = $rIndex * $Columns + 0"
		curIfIdx=${SMArray[$index]}
		to_debug curIfIdx $curIfIdx
	
		let "index = $rIndex * $Columns + 2"
		curIfName=${SMArray[$index]}
		to_debug curIfName $curIfName
	
		_result_status=`$SNMPGET -v $Version $Community $Host "IF-MIB::ifOperStatus.${curIfIdx}"| awk '{print $4}' | awk -F '(' '{print $1}'`
		if [ "$_result_status" != "up" ]; then
			$Echo "The Interface name:${curIfName} -- index:${curIfIdx} you checked seems not up."
			exit 3
		fi
	done
	
	
	
	#init ctbspIn/ctbspOut
	ctbpsIn=0
	ctbpsOut=0
	#init ctDiffRIAVG/ctDiffROAVG
	ctDiffRIAVG=0
	ctDiffROAVG=0
	
	for ii in `seq 1 $IntCnt`
	do
		let "rIndex = $ii - 1"
		let "index = $rIndex * $Columns + 0"
		curIfIdx=${SMArray[$index]}
		to_debug curIfIdx $curIfIdx
		
		_result_in=`$SNMPGET -v $Version $Community $Host "IF-MIB::${ifIn}"."$curIfIdx"`
		_result_out=`$SNMPGET -v $Version $Community $Host "IF-MIB::${ifOut}"."$curIfIdx" `
		to_debug time is $Time, $SNMPGET check result in is $_result_in, out is $_result_out
		
		_result_in=`echo $_result_in |awk '{print $4}'`
		_result_out=`echo $_result_out|awk '{print $4}'`
		to_debug time is $Time, $SNMPGET check result in is $_result_in, out is $_result_out
	
		if [ -z "$_result_in" -o -z "$_result_out" ] ; then
			$Echo "No Data been get here. Please confirm your ARGS and re-check it with Verbose mode, then to check the log.(If you snmp not support 64 bit counter, do not use -6 option)"
			exit 3
		fi
	
		In=`echo "$_result_in * 8 " |bc`
		Out=`echo "$_result_out * 8 " |bc`
		to_debug Index is $index Time is $Time, In is $In, Out is $Out
	
		let "index = $rIndex * $Columns + 5"
		SMArray[$index]=$Time
		to_debug time is ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 6"
		SMArray[$index]=$In
		to_debug In is ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 7"
		SMArray[$index]=$Out
		to_debug Out is ${SMArray[$index]}
	
	
		let "index = $rIndex * $Columns + 1"
		curCHD=${SMArray[$index]}
		to_debug curCHD $curCHD
	
		HistData=`cat $curCHD| head -n 1`
		HistTime=`echo $HistData| awk -F "|" '{print $1}'|sed 's/ //g'`
		HistIn=`echo $HistData| awk -F "|" '{print $2}'|sed 's/ //g'`
		HistOut=`echo $HistData| awk -F "|" '{print $3}'|sed 's/ //g'`
		to_debug HistData is $HistData HistTime is $HistTime, HistIn is $HistIn, HistOut is $HistOut
		
		if [ -z "$HistTime" -o -z "$HistIn" -o -z "$HistOut" ] ; then
			if [ "$IsFirst" = "True" ]; then
				#If there is a empty hist file, can write the data before exit(for the reason of IsFirst),
				#the data can be used for next time.
				echo "$Time|$In|$Out" > $curCHD
				to_debug "$Time|$In|$Out"  $curCHD
				continue
			else
                                #Delete File for clean retry
                                rm $curCHD
				Severity="3"
				Msg="Unknown"
				OutPut="Can not find data in the history data file. The file $curCHD was deleted for a clean retry." 
				$Echo "$Msg" "-" $OutPut
				exit $Severity
			fi
		else
			let "index = $rIndex * $Columns + 8"
			SMArray[$index]=$HistTime
			to_debug HistTime is ${SMArray[$index]}
		
			let "index = $rIndex * $Columns + 9"
			SMArray[$index]=$HistIn
			to_debug HistIn is ${SMArray[$index]}
		
			let "index = $rIndex * $Columns + 10"
			SMArray[$index]=$HistOut
			to_debug HistOut is ${SMArray[$index]}
		
			Interval=`echo "$Time - $HistTime" | bc`
			if [ $Interval -lt $Min_Interval ] ; then
				$Echo "The check interval must greater than $Min_Interval Seconds. But now it s $Interval. Please retry it later."
				exit 3
			fi
	
			#echo DEBUG here: data of $Host $Interface $ifName "$Time|$In|$Out"
			to_debug DEBUG here: data of $Host $Interface $ifName "$Time|$In|$Out"
			echo "$Time|$In|$Out" > $curCHD
	
			if [ $? -ne 0 ];then
				Severity=3
				Msg="Unknown"
				OutPut="Write File $curCHD Error with user `id`."
				$Echo "$Msg" "-" $OutPut
				exit $Severity
			fi
	
			if [ $Interval -gt $Max_Interval ] ; then
	                        # Retry
        	                sleep 5
                	        /usr/lib/icinga2/custom_plugins/check_traffic.sh "$@"
                        	if [ $? -eq 0 ]; then
                               		exit 0
                        	fi
				$Echo "The check interval is too large(It is greater than $Max_Interval). The result is droped. We will use the fresh data at the next time."
				exit 3
			fi
		fi
	
		DiffIn=`echo "$In - $HistIn" | bc`
		DiffOut=`echo "$Out - $HistOut" | bc`
		to_debug Interval/DiffIn/DiffOut $Interval $DiffIn $DiffOut 
		
		if [ ` echo " $Interval > 0 " |bc ` -eq 0 ] ; then
                        #Retry
                        sleep 5
                        /usr/lib/icinga2/custom_plugins/check_traffic.sh "$@"
                        if [ $? -eq 0 ]; then
                        	exit 0
                        fi
			$Echo  "we got a negative time interval value here. Return "$?"."
			exit 3
		fi
		
		if [ ` echo " $DiffOut >= 0 " |bc ` -eq 0 -o  ` echo " $DiffIn >= 0 " |bc ` -eq 0 ] ; then
                        #Retry
                        sleep 5
                        /usr/lib/icinga2/custom_plugins/check_traffic.sh "$@"
                        if [ $? -eq 0 ]; then
                        	exit 0
                        fi
			$Echo  "Maybe 32 bit counter overflow, because we got a negative value here. Return "$?"."
			exit 3
		fi
		
		
		bpsIn=`echo "$DiffIn / $Interval" | bc`
		bpsOut=`echo "$DiffOut / $Interval" | bc`
		to_debug bpsIn/bpsOut $bpsIn $bpsOut 
	
		#Comment to fix the bug when high traffic occurs , or in some virtual environment.
		#if [ $bpsIn -gt $ifSpeed -o $bpsOut -gt $ifSpeed ]; then
		#	$Echo  "OOPS. We get a value bigger than ifSpeed here. Something is wrong. Maybe a check from 32bit to 64bit transfer, or any other error here."
		#	exit 3
		#fi
	
	
	
		let "index = $rIndex * $Columns + 11"
		SMArray[$index]=$Interval
		to_debug Interval is ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 12"
		SMArray[$index]=$DiffIn
		to_debug DiffIn is ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 13"
		SMArray[$index]=$DiffOut
		to_debug DiffOut is ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 14"
		SMArray[$index]=$bpsIn
		to_debug bpsIn is ${SMArray[$index]}
	
		let "index = $rIndex * $Columns + 15"
		SMArray[$index]=$bpsOut
		to_debug bpsOut is ${SMArray[$index]}
	
		if [ $TrafficJitter"AA" = "TrueAA" ]; then
		
			let "index = $rIndex * $Columns + 4"
			curSHD=${SMArray[$index]}
			to_debug curSHD $curSHD
		
			let "index = $rIndex * $Columns + 16"
			curNum=${SMArray[$index]}
			to_debug curNum $curNum
		
			let "index = $rIndex * $Columns + 17"
			curC=${SMArray[$index]}
			to_debug curC $curC
		
			let "index = $rIndex * $Columns + 18"
			curRI=${SMArray[$index]}
			to_debug curRI $curRI
		
			let "index = $rIndex * $Columns + 19"
			curRO=${SMArray[$index]}
			to_debug curRO $curRO
		
			curRI=($curRI)
			curRO=($curRO)
			if [ $curC -lt $curNum ]; then
				to_debug we have not the enough data to calculating.
				curRI[$curC]=$bpsIn
				curRO[$curC]=$bpsOut
				to_debug curC $curC 
				to_debug curRI ${curRI[@]}
				to_debug curRO ${curRO[@]}
				curC=`expr $curC + 1`
			
				echo $curC >$curSHD
				echo ${curRI[@]} >>$curSHD
				echo ${curRO[@]} >>$curSHD
				isNotEnough=True
				continue
			else
				to_debug we have the enough data to calculating.
				RIAVG=0
				ROAVG=0
			
				lencurRI=${#curRI[@]}
				to_debug lencurRI is $lencurRI
				rii=0
			
				while [ $rii -lt $lencurRI ]
				do
					to_debug hist: rii $rii
					to_debug hist: rii curRI[rii] $rii ${curRI[$rii]}
					to_debug hist: rii curRO[rii] $rii ${curRO[$rii]}
					RIAVG=`echo "scale=$Scale; $RIAVG + ${curRI[$rii]} " |bc`
					ROAVG=`echo "scale=$Scale; $ROAVG + ${curRO[$rii]} " |bc`
					let rii++
					to_debug RIAVG $RIAVG
					to_debug ROAVG $ROAVG
				done
				to_debug RIAVG $RIAVG
				to_debug ROAVG $ROAVG
				RIAVG=`echo "scale=$Scale; $RIAVG / $curNum " |bc`
				ROAVG=`echo "scale=$Scale; $ROAVG / $curNum " |bc`
				to_debug RIAVG $RIAVG
				to_debug ROAVG $ROAVG
			
				rii=0
				while [ $rii -lt `expr $lencurRI - 1` ]
				do
					curRI[$rii]=${curRI[`expr $rii + 1`]}
					curRO[$rii]=${curRO[`expr $rii + 1`]}
					to_debug new: rii curRI[rii] $rii ${curRI[`expr $rii + 1 `]}
					to_debug new: rii curRO[rii] $rii ${curRO[`expr $rii + 1 `]}
					let rii++
				done
				curRI[$rii]=$bpsIn
				curRO[$rii]=$bpsOut
				echo $curC >$curSHD
				echo ${curRI[@]} >>$curSHD
				echo ${curRO[@]} >>$curSHD
				to_debug new: all  ${curRI[@]} 
				to_debug new: all ${curRO[@]} 
				DiffRIAVG=`echo "scale=$Scale; $bpsIn - $RIAVG" |bc`	
				DiffROAVG=`echo "scale=$Scale; $bpsOut - $ROAVG" |bc`	
				to_debug DiffRIAVG $DiffRIAVG
				to_debug DiffROAVG $DiffROAVG
		
				DiffRIAVG=`echo $DiffRIAVG | sed 's/-//'`
				DiffROAVG=`echo $DiffROAVG | sed 's/-//'`
				to_debug DiffRIAVG $DiffRIAVG
				to_debug DiffROAVG $DiffROAVG
	
		
				DiffRIAVG=`echo "scale=$Scale; $DiffRIAVG / $RIAVG * 100 " |bc`	
				DiffROAVG=`echo "scale=$Scale; $DiffROAVG / $ROAVG  * 100" |bc`	
				DiffAVGTotal=`echo "scale=$Scale; $DiffRIAVG  + $DiffROAVG" |bc`
				to_debug DiffRIAVG $DiffRIAVG
				to_debug DiffROAVG $DiffROAVG
				to_debug DiffAVGTotal $DiffAVGTotal
				
			fi
			ctDiffRIAVG=`echo "scale=$Scale; $ctDiffRIAVG + $DiffRIAVG" |bc`
			ctDiffROAVG=`echo "scale=$Scale; $ctDiffROAVG + $DiffROAVG" |bc`
			to_debug ctDiffRIAVG $ctDiffRIAVG
			to_debug ctDiffROAVG $ctDiffROAVG
		else	
		
			#aggreating data
			ctbpsIn=`echo $ctbpsIn + $bpsIn|bc`
			ctbpsOut=`echo $ctbpsOut + $bpsOut|bc`
		fi

	done

	if [ "$isNotEnough" = "True" ]; then
		$Echo "OK - There was only `echo $curC -1 |bc` hist data before this check. We need the $curNum hist data to use for calculating. Please wait."
		exit 0
	fi
	
	if [ "$IsFirst" = "True" ]; then
		Severity="0"
		Msg="OK"
		OutPut="It is the first time of this plugins to run, or some data file lost. We will get the data from the next time."
		$Echo "$Msg" "-" $OutPut
		exit $Severity
	fi


	DiffRIAVG=`echo "scale=$Scale; $ctDiffRIAVG / $IntCnt" |bc`
	DiffROAVG=`echo "scale=$Scale; $ctDiffROAVG / $IntCnt" |bc`
	DiffAVGTotal=`echo "scale=$Scale; $DiffRIAVG  + $DiffROAVG" |bc`
	to_debug DRIA $DiffRIAVG DROA $DiffROAVG DAVGT $DiffAVGTotal
	
#End of SM or SS
fi
	

#to K
uIn=`echo "$ctbpsIn / 1000" | bc`
uOut=`echo "$ctbpsOut / 1000" | bc`


#to M
if [ "$isM" = "True" ]; then
	uIn=`echo "scale=$Scale; $uIn / 1000" | bc`
	uOut=`echo "scale=$Scale; $uOut / 1000" | bc`
fi

#to B
if [ "$isB" = "True" ]; then
	uIn=`echo "scale=$Scale; $uIn / 8 * (1000 / 1024)" | bc`
	uOut=`echo "scale=$Scale; $uOut / 8 * (1000 / 1024)" | bc`
	if [ "$isM" = "True" ]; then
		uIn=`echo "scale=$Scale; $uIn / 8 * (1000 / 1024 ) " | bc`
		uOut=`echo "scale=$Scale; $uOut / 8 * (1000 / 1024)" | bc`
	fi

fi

to_debug Unit_1 is $Unit_1, Unit_2 is $Unit_2
to_debug Interval is $Interval, DiffIn is $DiffIn, DiffOut is $DiffOut, uIn is $uIn, uOut is $uOut
	


if [ $UseRange = "True" ] ;then

	check_w1b=`echo "$uIn > $W1b" | bc`
	check_w1e=`echo "$uIn < $W1e" | bc`

	check_w2b=`echo "$uOut > $W2b" | bc`
	check_w2e=`echo "$uOut < $W2e" | bc`
	to_debug check_w1 is $check_w1b $check_w1e , check_w2 is $check_w2b $check_w2e
	
	check_c1b=`echo "$uIn > $C1b" | bc`
	check_c1e=`echo "$uIn < $C1e" | bc`

	check_c2b=`echo "$uOut > $C2b" | bc`
	check_c2e=`echo "$uOut < $C2e" | bc`
	to_debug check_c1 is $check_c1b $check_c1e, check_c2 is $check_c2b $check_c2e
	
	
	if [ $check_w1b -eq 1 -a $check_w1e -eq 1 -a $check_w2b -eq 1  -a $check_w2e -eq 1  ] ; then
		Severity="0";
		Msg="OK";
		to_debug Severity is $Severity , Msg is $Msg 
	elif [ $check_c1b -eq 1 -a $check_c1e -eq 1 -a $check_c2b -eq 1  -a $check_c2e -eq 1  ] ; then
		Severity="1";
		Msg="Warning";
		to_debug Severity is $Severity , Msg is $Msg 
	else
		Severity="2";
		Msg="Critical";
		to_debug Severity is $Severity , Msg is $Msg 
	fi
	
elif [ $TrafficJitter"AA" = "TrueAA" ] ; then
	check_w1=`echo "$DiffRIAVG < $W1" | bc`
	check_w2=`echo "$DiffROAVG < $W2" | bc`
	to_debug check_w1 is $check_w1 , check_w2 is $check_w2 
	
	check_c1=`echo "$DiffRIAVG < $C1" | bc`
	check_c2=`echo "$DiffROAVG < $C2" | bc`
	to_debug check_c1 is $check_c1 , check_c2 is $check_c2
	
	
	if [ $check_w1 -eq 1 -a $check_w2 -eq 1 ] ; then
		Severity="0";
		Msg="OK";
		to_debug Severity is $Severity , Msg is $Msg 
	elif [ $check_c1 -eq 1 -a $check_c2 -eq 1 ] ; then
		Severity="1";
		Msg="Warning";
		to_debug Severity is $Severity , Msg is $Msg 
	else
		Severity="2";
		Msg="Critical";
		to_debug Severity is $Severity , Msg is $Msg 
	fi
else
	check_w1=`echo "$uIn < $W1" | bc`
	check_w2=`echo "$uOut < $W2" | bc`
	to_debug check_w1 is $check_w1 , check_w2 is $check_w2 
	
	check_c1=`echo "$uIn < $C1" | bc`
	check_c2=`echo "$uOut < $C2" | bc`
	to_debug check_c1 is $check_c1 , check_c2 is $check_c2
	
	
	if [ $check_w1 -eq 1 -a $check_w2 -eq 1 ] ; then
		Severity="0";
		Msg="OK";
		to_debug Severity is $Severity , Msg is $Msg 
	elif [ $check_c1 -eq 1 -a $check_c2 -eq 1 ] ; then
		Severity="1";
		Msg="Warning";
		to_debug Severity is $Severity , Msg is $Msg 
	else
		Severity="2";
		Msg="Critical";
		to_debug Severity is $Severity , Msg is $Msg 
	fi


fi

uTotal=`echo "$uIn + $uOut" | bc`
if [ `echo "$uIn < 1" | bc` -eq 1 ]; then
	uIn="0"${uIn}
	if [ "$uIn" = "00" ]; then
		uIn=0.0
	fi
fi

if [ `echo "$uOut < 1" | bc` -eq 1 ]; then
	uOut="0"${uOut}
	if [ "$uOut" = "00" ]; then
		uOut=0.0
	fi
fi

if [ `echo "$uTotal < 1" | bc` -eq 1 ]; then
	uTotal="0"${uTotal}
	if [ "$uTotal" = "00" ]; then
		uTotal=0.0
	fi
fi

to_debug Interval is $Interval, DiffIn is $DiffIn, DiffOut is $DiffOut, uIn is $uIn, uOut is $uOut, uTotal is $uTotal


	
	
if [ $UseRange = "True" ] ;then

	if [ $Format"AA" = "SAA" ]; then
		$Echo "$Msg" "-" In/Out "$uIn"${Unit_1}${Unit_2}/"$uOut"${Unit_1}${Unit_2}\|In\=${uIn}${Unit_1}${Unit_2}\;\;\;0\;0 Out\=${uOut}${Unit_1}${Unit_2}\;\;\;0\;0
	elif [ $Format"AA" = "sAA" ]; then
		$Echo "$Msg" "-" In/Out/Total/Interval "$uIn"${Unit_1}${Unit_2}/"$uOut"${Unit_1}${Unit_2}/"$uTotal"${Unit_1}${Unit_2}/"$Interval"s \|In\=${uIn}${Unit_1}${Unit_2}\;\;\;0\;0 Out\=${uOut}${Unit_1}${Unit_2}\;\;\;0\;0 Total\=${uTotal}${Unit_1}${Unit_2}\;\;\;0\;0 Interval\=${Interval}s\;1200\;1800\;0\;0 
	else
#Units explanations
		$Echo "$Msg" "-" The Traffic In is "$uIn"${Unit_1}${Unit_2}, Out is "$uOut"${Unit_1}${Unit_2}, Total is "$uTotal"${Unit_1}${Unit_2}, Unit is KB=KBps, Kb=Kbps, MB=MBps, Mb=Mbps. The Check Interval is "$Interval"s \|In\=${uIn}${Unit_1}${Unit_2}\;\;\;0\;0 Out\=${uOut}${Unit_1}${Unit_2}\;\;\;0\;0 Total\=${uTotal}${Unit_1}${Unit_2}\;\;\;0\;0 Interval\=${Interval}s\;1200\;1800\;0\;0 
	fi
	exit $Severity

elif [ $TrafficJitter"AA" = "TrueAA" ]; then

	if [ $Format"AA" = "SAA" ]; then
		$Echo "$Msg" "-" Traffic Jitter In/Out "$DiffRIAVG""%"/"$DiffROAVG""%"\|In\=$DiffRIAVG\;${W1}\;${C1}\;0\;0 Out\=$DiffROAVG\;${W2}\;${C2}\;0\;0
	elif [ $Format"AA" = "sAA" ]; then
		$Echo "$Msg" "-" Traffic Jitter In/Out/Total/Interval "$DiffRIAVG""%"/"$DiffROAVG""%"/"$DiffAVGTotal""%"/"$Interval"s \|In\=$DiffRIAVG\;${W1}\;${C1}\;0\;0 Out\=$DiffROAVG\;${W2}\;${C2}\;0\;0 Total\=$DiffAVGTotal\;${Wt}\;${Ct}\;0\;0 Interval\=${Interval}s\;1200\;1800\;0\;0 
	else
		$Echo "$Msg" "-" The Traffic Jitter In is "$DiffRIAVG""%", Out is "$DiffROAVG""%", Total is "$DiffAVGTotal""%". The Check Interval is "$Interval"s \|In\=$DiffRIAVG\;${W1}\;${C1}\;0\;0 Out\=$DiffROAVG\;${W2}\;${C2}\;0\;0 Total\=$DiffAVGTotal\;${Wt}\;${Ct}\;0\;0 Interval\=${Interval}s\;1200\;1800\;0\;0 
	fi
	exit $Severity

else

	if [ $Format"AA" = "SAA" ]; then
		$Echo "$Msg" "-" In/Out "$uIn"${Unit_1}${Unit_2}/"$uOut"${Unit_1}${Unit_2}\|In\=${uIn}${Unit_1}${Unit_2}\;${W1}\;${C1}\;0\;0 Out\=${uOut}${Unit_1}${Unit_2}\;${W2}\;${C2}\;0\;0
	elif [ $Format"AA" = "sAA" ]; then
		$Echo "$Msg" "-" In/Out/Total/Interval "$uIn"${Unit_1}${Unit_2}/"$uOut"${Unit_1}${Unit_2}/"$uTotal"${Unit_1}${Unit_2}/"$Interval"s \|In\=${uIn}${Unit_1}${Unit_2}\;${W1}\;${C1}\;0\;0 Out\=${uOut}${Unit_1}${Unit_2}\;${W2}\;${C2}\;0\;0 Total\=${uTotal}${Unit_1}${Unit_2}\;${Wt}\;${Ct}\;0\;0 Interval\=${Interval}s\;1200\;1800\;0\;0 
	else
#Units explanations
		$Echo "$Msg" "-" The Traffic In is "$uIn"${Unit_1}${Unit_2}, Out is "$uOut"${Unit_1}${Unit_2}, Total is "$uTotal"${Unit_1}${Unit_2}, Unit is KB=KBps, Kb=Kbps, MB=MBps, Mb=Mbps. The Check Interval is "$Interval"s \|In\=${uIn}${Unit_1}${Unit_2}\;${W1}\;${C1}\;0\;0 Out\=${uOut}${Unit_1}${Unit_2}\;${W2}\;${C2}\;0\;0 Total\=${uTotal}${Unit_1}${Unit_2}\;${Wt}\;${Ct}\;0\;0 Interval\=${Interval}s\;1200\;1800\;0\;0 
	fi
	exit $Severity
fi

# End of check_traffic.sh
