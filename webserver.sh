#!/bin/bash

# --------------------------------------------------------------------------------

# App	Project management tool
# Version: 0.2
# Date:	2010-06-08
# File:	webserver-projects.sh
# Author: Runge, Timo
# Copyright: 2010 innomedia AG
# Optimized: Ornella  / 28.09.2021

# --------------------------------------------------------------------------------

APP_TITLE='innomedia AG - Project management tool'

# --------------------------------------------------------------------------------

# --- CONFIGURE: MySQL
MYSQL_HOST='localhost'
MYSQL_PASS='e784fB5r!97T842$f92'
MYSQL_PORT='3306'
MYSQL_USER='root'

# --- CONFIGURE: GITHUB
source config.sh

# --- CONFIGURE: Domain (will be used be vHost ServerName generation)
DOMAIN_MASTER='tietge.com'

# --------------------------------------------------------------------------------

# --- CHECK: Check for dialog app
if [ -f /usr/bin/dialog ] ; then
	echo 'Starting application ...'
else
	echo 'Need dialog ... try to install it ...'
	aptitude -y install dialog
fi

# --------------------------------------------------------------------------------

# --- SETTER: Set tmp-file
_TEMP="/tmp/innomedia.project-management.$$"

# --------------------------------------------------------------------------------

# --- HELPER: Clear the screen and exit all
clear_and_exit () {
	clear
	exit
}

# --- CREATE: php7.4-fpm.sock starter for project
create_project_fpm_php7.4_starter () {
	echo 'Create fpm php7 starter ... '
	cat > /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/php/php7.4-fpm.sock<< EOF
#!/bin/sh
export PHPRC=/var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf
export TMPDIR=/var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/tmp
exec /usr/bin/php7-cgi
EOF
	echo 'Set rights for  fpm php7 starter ...'
	chown ${VIRTUAL_USER_NAME}:${VIRTUAL_USER_GROUP} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/php/php7.4-fpm.sock
	chmod 750 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/php/php7.4-fpm.sock
	chattr +i -V /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/php/php7.4-fpm.sock
}

# --- CREATE: php.ini for project
create_project_php_ini () {
	echo 'Create php.ini ... '
	cat > /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/php.ini << EOF
open_basedir = /dev/urandom:/var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs:/var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/tmp
session.save_path = /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/tmp
soap.wsdl_cache_dir = /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/tmp
upload_tmp_dir = /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/tmp
EOF
	echo 'Set rights for php.ini ...'
	chown ${VIRTUAL_USER_NAME}:${VIRTUAL_USER_GROUP} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/php.ini
	chmod 440 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/php.ini
	chattr +i -V /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/php.ini
}

# --- CREATE: Project structure
create_project_structure () {
	echo 'Create directories ... '
	mkdir -p /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/{conf,htdocs,logs,stats,tmp}
	chown root:${VIRTUAL_USER_NAME} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}
	echo 'Set rights in directories ... '
	chmod 750 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}
	chown ${VIRTUAL_USER_NAME}:${VIRTUAL_USER_GROUP} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/*
	chmod 750 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/*
	chmod 550 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf
}

# --- CREATE: vhost.conf for project
create_project_vhost () {
	echo 'Create virtual host ... '
	cat > /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/vhost.conf << EOF
<VirtualHost *:80>
	ServerName ${DOMAIN}
	DocumentRoot "/var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs"
	DirectoryIndex index.htm index.html index.php
	#SuexecUserGroup ${VIRTUAL_USER_NAME} ${VIRTUAL_USER_GROUP}
	<Directory />
		Options FollowSymLinks
		AllowOverride None
	</Directory>
	<Directory "/var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs">
		Options Indexes FollowSymLinks MultiViews
		AllowOverride All
		Order allow,deny
		allow from all
	</Directory>
	CustomLog "|/usr/bin/rotatelogs -l /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/logs/access_%Y-%m-%d.log 86400" combined
	ErrorLog "|/usr/bin/rotatelogs -l /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/logs/error_%Y-%m-%d.log 86400"
</VirtualHost>
EOF
	echo 'Set rights for virtual host ... '
	chown ${VIRTUAL_USER_NAME}:${VIRTUAL_USER_GROUP} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/vhost.conf
	chmod 440 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/vhost.conf
	ln -s /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/conf/vhost.conf /var/www/${ENVIRONMENT_TYPE}/vhosts/${PROJECT_NAME}.conf
}

# --- CREATE: MySQL database and user
create_mysql_database_user () {
	MYSQL_DB=${PROJECT_NAME}_${ENVIRONMENT_TYPE}
	STRING=${VIRTUAL_USER_NAME}${ENVIRONMENT_TYPE}${PROJECT_NAME}${VIRTUAL_USER_GROUP}
	MYSQL_PASSWORD=`echo ${STRING} | md5sum | awk -F ' ' '{ print $1 }' | cut -b 5-25`
	SQL_QUERY_1="CREATE DATABASE IF NOT EXISTS ${MYSQL_DB} CHARACTER SET utf8;"
	SQL_QUERY_2="GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${VIRTUAL_USER_NAME}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';"
	SQL_QUERY_3="FLUSH PRIVILEGES;"
	SQL_QUERY_FULL="${SQL_QUERY_1}${SQL_QUERY_2}${SQL_QUERY_3}"
	mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASS} -e "${SQL_QUERY_FULL}"
}

# --- CREATE: New user
create_user () {
	echo 'Create user ... '
	STRING=${VIRTUAL_USER_NAME}${DOMAIN}${VIRTUAL_USER_GROUP}
	USER_PASSWORD=`echo ${STRING} | md5sum | md5sum | awk -F ' ' '{ print $1 }' | cut -b 5-25`
	useradd -u ${VIRTUAL_UID_NEW} -p ${USER_PASSWORD} -d /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME} -s /usr/sbin/nologin ${VIRTUAL_USER_NAME}
	echo 'Add user to www-data group and add www-data to user group ... '
	usermod -aG www-data ${VIRTUAL_USER_NAME}
	usermod -aG ${VIRTUAL_USER_NAME} www-data
}

# --- SETTER: New user id, name and group
create_virtual_userdata () {
	VIRTUAL_UID_NEW=0
	VIRTUAL_UID_PRE='S007V'
	let VIRTUAL_UID_START=1000
	let VIRTUAL_UID_STOP=50000
	let VIRTUAL_UID_LAST=`awk -F: '($3>=1000) && ($3<50000) && ($3>maxuid) { maxuid=$3; } END { print maxuid; }' /etc/passwd`
	if [ ${VIRTUAL_UID_START} -gt ${VIRTUAL_UID_LAST} ]; then
		let VIRTUAL_UID_NEW=${VIRTUAL_UID_START}
	else
		let VIRTUAL_UID_NEW=${VIRTUAL_UID_LAST}+1
	fi
	VIRTUAL_USER_NAME=${VIRTUAL_UID_PRE}${VIRTUAL_UID_NEW}
	VIRTUAL_USER_GROUP=${VIRTUAL_USER_NAME}
}

# --- CREATE: FTP login permission
create_ftp_login_permission () {
	echo ${VIRTUAL_USER_NAME} >> /etc/vsftpd.user_list
}

# --- GUI: Enter domain for new project
gui_choose_domain () {
	case ${ENVIRONMENT} in
		0) DOMAIN_ENVIRONMENT_TYPE='test';;
		1) DOMAIN_ENVIRONMENT_TYPE='live';;
	esac
	DOMAIN_PROJECT=`echo ${PROJECT_NAME} | awk -F'_' '{ print $2 }'`
	DOMAIN=${DOMAIN_PROJECT}'.'${DOMAIN_ENVIRONMENT_TYPE}'.'${DOMAIN_MASTER}
	dialog	--backtitle "${APP_TITLE}" \
					--title "Checkout project / ${ENVIRONMENT_TYPE} / ${PROJECT_NAME} / Domain" \
					--cancel-label 'Quit' \
					--inputbox "Enter domain for project ${PROJECT_NAME} / ${ENVIRONMENT_TYPE}:" ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} ${DOMAIN} 2> ${_TEMP}
	if [ ${?} -eq 0 ]; then
		DOMAIN=`cat ${_TEMP}`
		rm -f ${_TEMP}
		if [ ${DOMAIN} != '' ]; then
			dialog	--backtitle "${APP_TITLE}" \
							--title "${ENVIRONMENT_TYPE} / ${PROJECT_NAME} / $DOMAIN / Check settings:" \
							--yesno "Environment: ${ENVIRONMENT_TYPE}\nProject:     ${PROJECT_NAME}\nDomain:      $DOMAIN\n\nAre these settings correct?\nClick yes to create the project structure or no to cancel." ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
		else
			app_menu_action_chooser
		fi
	else
		app_menu_action_chooser
	fi
}

# --- GUI: Choose environment
gui_choose_environment () {
	dialog	--backtitle "${APP_TITLE}" \
					--title 'Environment' \
					--cancel-label 'Back' \
					--menu 'Choose the environment:' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} 2 \
					0 'testing' \
					1 'production' 2> ${_TEMP}
	if [ ${?} -eq 0 ] ; then
		ENVIRONMENT=`cat ${_TEMP}`
		rm -f ${_TEMP}
		case ${ENVIRONMENT} in
			0) ENVIRONMENT_TYPE='testing';;
			1) ENVIRONMENT_TYPE='production';;
		esac
	else
		gui_choose_main_action
	fi
}

# --- GUI: Choose the first action
gui_choose_main_action () {
	dialog	--backtitle "${APP_TITLE}" \
					--title 'Start' \
					--cancel-label 'Quit' \
					--menu 'Choose your action:' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} 2 \
					0 'Checkout project' \
					1 'Project actions' 2> ${_TEMP}
	case ${?} in
		0) 
			MAIN_ACTION=`cat ${_TEMP}`
			rm -f ${_TEMP}
			case ${MAIN_ACTION} in
				0) gui_project_checkout;;
				1) gui_project_manage;;
			esac
			;;
		1) clear_and_exit;;
	esac
}

# --- GUI: Choose action for an existing project
gui_choose_project_actions () {
	dialog	--backtitle "${APP_TITLE}" \
					--title "Project actions / ${ENVIRONMENT_TYPE} / ${PROJECT_NAME}" \
					--cancel-label 'Back' \
					--menu 'Choose action:'  ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} 4 \
					0 'Show GIT status' \
					1 'Show information of project' \
					2 'Show last 100 error log entries' \
					3 'Update project' 2> ${_TEMP}
	if [ ${?} -eq 0 ]; then
		ACTION=`cat ${_TEMP}`
		rm -f ${_TEMP}
		case ${ACTION} in
			0) gui_show_project_status;;
			1) gui_show_project_info;;
			2) gui_show_project_error_log;;
			3) gui_update_project;;
		esac
	else
		gui_choose_main_action
	fi
}

# --- GUI: Choose project from filesystem
gui_choose_project_from_filesystem () {
	FILESYSTEM_PROJECT_PATH=/var/www/${ENVIRONMENT_TYPE}/
	IFS_BAK=${IFS}
	IFS=$'\n' #kill blanks
	PROJECTS=''
	PROJECTS_ARRAY=( $(ls ${FILESYSTEM_PROJECT_PATH}) )
	let N=0
	for PROJECT in ${PROJECTS_ARRAY[@]}
	do
		if [ ${PROJECT} != 'vhosts' ] ; then
			PROJECTS="${PROJECTS} ${N} ${PROJECT}"
			let N+=1
		fi
	done
	IFS=${IFS_BAK}
	if [ ${N} -eq 0 ] ; then
		dialog	--backtitle "${APP_TITLE}" \
						--title "Project actions / ${ENVIRONMENT_TYPE} / Error" \
						--ok-label 'Back' \
						--msgbox "No projects in ${ENVIRONMENT_TYPE} environment." ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
		gui_choose_main_action
	else
		dialog	--backtitle "${APP_TITLE}" \
						--title "Project actions / ${ENVIRONMENT_TYPE} / Projects" \
						--cancel-label 'Back' \
						--menu 'Select project:' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} 10 \
						${PROJECTS} 2> ${_TEMP}
		if [ ${?} -eq 0 ] ; then
			PROJECT_ID=`cat ${_TEMP}`
			rm -f ${_TEMP}
			PROJECT_NAME=${PROJECTS_ARRAY[${PROJECT_ID}]}
			PROJECT_NAME=`echo ${PROJECT_NAME} | awk -F'/' '{ print $1 }'`
		else
			gui_choose_main_action
		fi
	fi
}


# --- GUI: Choose project from GIT
gui_choose_project_from_svn () {
	SVN_REPO=${SVN_REPO_PROTOCOL}'://'${SVN_REPO_URL}':'${SVN_REPO_PORT}${SVN_REPO_PATH}
	curl -i -H "Authorization: token ${GIT_TOKEN}" -s https://api.github.com/user/repos |
	grep -zoP '"git_url":\s*\K[^\s,]*(?=\s*,)' | 
	tr '\"' '\n' |
	sed -n -e '/git/{p;n;}' |
	sed "s/.*\///" | 
	cut -f 1 -d '.' > 'repositories.list'
	IFS=$'\n' read -d '' -r -a PROJECTS_ARRAY < repositories.list
	let N=0
	for PROJECT in ${PROJECTS_ARRAY[@]}
	do
		PROJECT=`echo ${PROJECT} | awk -F'/' '{ print $1 }'`
		PROJECTS="${PROJECTS} ${N} ${PROJECT}"
		let N+=1
	done
	if [ ${N} -eq 0 ] ; then
		dialog	--backtitle "${APP_TITLE}" \
						--title "Checkout project / ${ENVIRONMENT_TYPE} / Error" \
						--ok-label 'Back' \
						--msgbox "Can't connect to GIT REPO or no projects found." ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
		gui_choose_main_action
	else
		dialog	--backtitle "${APP_TITLE}" \
						--title "Checkout project / ${ENVIRONMENT_TYPE} / Project list" \
						--cancel-label 'Back' \
						--menu 'Select project:' ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO} 10 \
						${PROJECTS} 2> ${_TEMP}
		if [ ${?} -eq 0 ] ; then
			PROJECT_ID=`cat ${_TEMP}`
			PROJECT_NAME=${PROJECTS_ARRAY[${PROJECT_ID}]}
			PROJECT_NAME=`echo ${PROJECT_NAME} | awk -F'/' '{ print $1 }'`
		else
			gui_choose_main_action
		fi
	fi
}



# --- GUI: Checkout new project
gui_project_checkout () {
	gui_choose_environment
	gui_choose_project_from_svn
	if [ -d /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME} ] ; then
		dialog	--backtitle "${APP_TITLE}" \
						--title 'Error' \
						--ok-label 'Back' \
						--msgbox "Project ${PROJECT_NAME} already exists in ${ENVIRONMENT_TYPE} environment." ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
		gui_choose_main_action
	else
		gui_choose_domain
		if [ ${?} -eq 0 ] ; then
			clear
			create_virtual_userdata
			create_user
			create_mysql_database_users
			create_project_structure
			create_ftp_login_permission
			create_project_php_ini
			create_project_vhost
			helper_project_checkout
			dialog	--backtitle "${APP_TITLE}" \
							--title "${ENVIRONMENT_TYPE} / ${PROJECT_NAME} / ${DOMAIN} / Yeah!" \
							--ok-label 'Ok' \
							--msgbox "Project ${PROJECT_NAME} successfull created in ${ENVIRONMENT_TYPE} environment." ${SCREEN_HEIGHT_LO} ${SCREEN_WIDTH_LO}
			gui_choose_main_action
		else
			gui_choose_main_action
		fi
	fi
}

# --- GUI: Choose environment and do something with one project
gui_project_manage () {
	gui_choose_environment
	gui_choose_project_from_filesystem
	gui_choose_project_actions
}

# --- GUI: Show error log of a project
gui_show_project_error_log () {
	tail -100 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/logs/error.log >> ${_TEMP}
	dialog	--backtitle "$APP_TITLE" \
					--title "${ENVIRONMENT_TYPE} / ${PROJECT_NAME} / Error log" \
					--cancel-label 'Back' \
					--textbox ${_TEMP} ${SCREEN_HEIGHT_HI} ${SCREEN_WIDTH_HI}
	rm -f ${_TEMP}
	gui_choose_project_actions
}

# --- GUI: Show information of the project
gui_show_project_info () {
	VIRTUAL_USER_NAME=`stat -c %U /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs`
	VIRTUAL_USER_GROUP=`stat -c %G /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs`
	PROJECT_FILESYSTEM_SIZE=`du -h --max-depth=0 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME} | awk -F' ' '{ print $1 }'`
	STRING=${VIRTUAL_USER_NAME}${ENVIRONMENT_TYPE}${PROJECT_NAME}${VIRTUAL_USER_GROUP}
	MYSQL_PASSWORD=`echo ${STRING} | md5sum | awk -F ' ' '{ print $1 }' | cut -b 5-25`
	USER_PASSWORD=`echo ${STRING} | md5sum | md5sum | awk -F ' ' '{ print $1 }' | cut -b 5-25`
	dialog	--backtitle "$APP_TITLE" \
					--title "${ENVIRONMENT_TYPE} / ${PROJECT_NAME} / Info" \
					--ok-label 'Back' \
					--msgbox "Filesystem\n--------------------\nFolder:   /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}\nUser:     ${VIRTUAL_USER_NAME}\nPassword: ${USER_PASSWORD}\nGroup:    ${VIRTUAL_USER_GROUP}\nSize:     ${PROJECT_FILESYSTEM_SIZE}\n\n\nDatabase\n--------------------\nHost:     localhost\nUser:     ${VIRTUAL_USER_NAME}\nPassword: ${MYSQL_PASSWORD}\nDatabase: ${PROJECT_NAME}_${ENVIRONMENT_TYPE}" ${SCREEN_HEIGHT_HI} ${SCREEN_WIDTH_HI}
	gui_choose_project_actions
}

# --- GUI: Show status from a project
gui_show_project_status () {
	svn status -u --username ${SVN_REPO_USER} --password ${SVN_REPO_PASS} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs >> ${_TEMP}
	dialog	--backtitle "$APP_TITLE" \
					--title "${ENVIRONMENT_TYPE} / ${PROJECT_NAME} / SVN status" \
					--cancel-label 'Back' \
					--textbox ${_TEMP} ${SCREEN_HEIGHT_HI} ${SCREEN_WIDTH_HI}
	rm -f ${_TEMP}
	gui_choose_project_actions
}

# --- GUI: Update a project
gui_update_project () {
#	VIRTUAL_USER_NAME=`stat -c %U /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs`
#	VIRTUAL_USER_GROUP=`stat -c %G /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs`
#	svn update --username ${SVN_REPO_USER} --password ${SVN_REPO_PASS} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs >> ${_TEMP}
#	chown -R ${VIRTUAL_USER_NAME}:${VIRTUAL_USER_GROUP} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs
#	chmod -R 660 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs/*
#	find /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs/ -type d -exec chmod u+rwx {} \;
#	find /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs/ -type d -exec chmod g+rwx {} \;
#	dialog	--backtitle "$APP_TITLE" \
#					--title "${ENVIRONMENT_TYPE} / ${PROJECT_NAME} / SVN Update" \
#					--cancel-label 'Back' \
#					--textbox ${_TEMP} ${SCREEN_HEIGHT_HI} ${SCREEN_WIDTH_HI}
#	rm -f ${_TEMP}
	gui_choose_project_actions
}

# --- HELPER: Checkout a project
helper_project_checkout () {
	SVN_REPO=${SVN_REPO_PROTOCOL}'://'${SVN_REPO_URL}':'${SVN_REPO_PORT}${SVN_REPO_PATH}
	echo 'Checkout project to htdocs ... '
        git clone https://${GIT_TOKEN}@github.com/${GIT_USERNAME}/${PROJECT_NAME}.git /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs
	echo 'Set rights for project ... '
	chown -R ${VIRTUAL_USER_NAME}:${VIRTUAL_USER_GROUP} /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs
	chmod -R 660 /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs/*
	find /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs/ -type d -exec chmod u+rwx {} \;
	find /var/www/${ENVIRONMENT_TYPE}/${PROJECT_NAME}/htdocs/ -type d -exec chmod g+rwx {} \;
}

# --- HELPER: Set the height and the width of each screen
set_screen_height_width () {
	let "SCREEN_HEIGHT_HI=$(tput lines)-5"
	SCREEN_HEIGHT_LO=14
	if [ ${SCREEN_HEIGHT_HI} -lt ${SCREEN_HEIGHT_LO} ] ; then
		SCREEN_HEIGHT_HI=${SCREEN_HEIGHT_LO}
	fi
	let "SCREEN_WIDTH_HI=$(tput cols)"
	SCREEN_WIDTH_LO=90
	if [ ${SCREEN_WIDTH_HI} -lt ${SCREEN_WIDTH_LO} ] ; then
		SCREEN_WIDTH_HI=${SCREEN_WIDTH_LO}
	fi
}

# --------------------------------------------------------------------------------

main_menu () {
	set_screen_height_width
	gui_choose_main_action
}

# --------------------------------------------------------------------------------

while true; do
	main_menu
done

