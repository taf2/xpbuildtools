#!/bin/bash

cmd="$1"

if [ ! -x 'xulrunner/simo-bin.exe' -o ! -x application.ini ]
then echo "Must CD to a SimoHealth application dir!"
		 cmd=""  # force usage msg
fi

case $cmd in 
'in')	xulrunner/simo-bin.exe application.ini -chrome \
				'chrome://simo/content/restore/backup.xul?file=c:\b.sbx'
			;;

'indeb')
				echo "warning - this doesn't work yet"
				XPCOM_DEBUG_BREAK=warn MOZ_NO_REMOTE=1 shellexec.exe inBackup-debug.sln
				#xulrunner/simo-bin.exe application.ini -chrome \
				#'chrome://simo/content/restore/backup.xul?file=b.sbx'
			;;

'un')	xulrunner/simo-bin.exe application.ini -chrome \
				'chrome://simo/content/restore/backup.xul?savebackup=true'
			;;

'indeb')
				echo "warning - this doesn't work yet"
			;;

*)		echo "Usage:"
			echo "  % simulateInstallerBackup.sh in"
			echo "      Call xulrunner & backup.sbx the way the installer does."
			echo "      Output will be ./b.sbx"
			echo
			echo "  % simulateInstallerBackup.sh un"
			echo "      Call xulrunner & backup.sbx the way the UNinstaller does."
			echo "      Output is chosen by dialog"
			echo
			echo "  % simulateInstallerBackup.sh indeb"
			echo "  % simulateInstallerBackup.sh undeb"
			echo "      Same thing but under msvc debugger"
			echo
			echo "In all cases, first CD to the 'bin' directory of the app to test."
			;;
esac


