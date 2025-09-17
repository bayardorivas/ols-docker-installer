#!/bin/zsh

# Color codes for terminal output
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[34m'
BOLD='\e[1m'
RESET='\e[0m'

WORKING_DIR=~/my-devenv
NEW_SITE=$1
GIT_REPO_URL=git@github.com:litespeedtech/ols-docker-env.git

INPUT_FILE=docker-compose.yml
OUTPUT_FILE=docker-compose-"$NEW_SITE".yml
IN_LITESPEED="false"

clear
echo -e "\n\n${BOLD}${BLUE}Local Development Environment Setup Script${RESET}\n"
#Validate user input
if [[ -z "$1" ]]; then
    echo -e "\n${RED}Error${RESET}"
    echo -e "Missing web site name"
    echo -e "\n Usage: "$0" new-site-name \n"
    exit 1
fi 

mkdir -p "$WORKING_DIR"/
cd "$WORKING_DIR"/

# Clone the project
git clone "$GIT_REPO_URL" "$NEW_SITE"

if [[ $? != 0 ]]; then
    echo -e "\n${RED}ERROR${RESET}"
    echo -e "\n Problem cloning the project\n"
else
    echo "Cloning the project ..."
    cd "$WORKING_DIR"/"$NEW_SITE"
    echo -e "\nProject cloned in ""$WORKING_DIR"/"$NEW_SITE"" \n" 
fi

cd "$WORKING_DIR"/"$NEW_SITE"

# Add containner name to services and add user volume in litespeed servie of docker-compose.yml
echo -e "\n ${GREEN}Customizing docker-compose.yml ...${RESET}\n"

while IFS= read -r line; do
    TRIMEDLINE=$(echo "$line" | sed 's/^[[:space:]]*//') 

    if [[ "$TRIMEDLINE" == "litespeed:"* ]]; then
        echo "$line" >> $OUTPUT_FILE
        echo "    container_name: ${NEW_SITE}_litespeed" >> $OUTPUT_FILE
        IN_LITESPEED=true
    elif [[ "$TRIMEDLINE" =~ ^container_name: ]] && [[ "$IN_LITESPEED" == "true" ]]; then
        continue
    elif [[ "$TRIMEDLINE" == *"volumes:"* ]] && [[ "$IN_LITESPEED" == "true" ]]; then
        echo "$line" >> "$OUTPUT_FILE"
        echo "      - /Users/"$USER"/repo/"$NEW_SITE":/var/www/vhosts/localhost/html/" >> "$OUTPUT_FILE"
        IN_LITESPEED="false"
    elif [[ "$TRIMEDLINE" == "mysql:"* ]]; then
        echo "$line" >> "$OUTPUT_FILE"
        echo "    container_name: "${NEW_SITE}"_mysql" >> "$OUTPUT_FILE"
    elif [[ "$TRIMEDLINE" == "phpmyadmin:"* ]]; then
        echo "$line" >> "$OUTPUT_FILE"
        echo "    container_name: "${NEW_SITE}"_phpmyadmin" >> "$OUTPUT_FILE"
    elif [[ "$TRIMEDLINE" == "redis:"* ]]; then
        echo "$line" >> "$OUTPUT_FILE"
        echo "    container_name: "${NEW_SITE}"_redis" >> "$OUTPUT_FILE"
    else 
        echo "$line" >> "$OUTPUT_FILE"
    fi
done < "$INPUT_FILE"
echo -e "\n ${GREEN}Done.${RESET}\n"
mkdir -p /Users/"$USER"/repo/"$NEW_SITE"/


mv "$INPUT_FILE" docker-compose-bk.yml 
mv "$OUTPUT_FILE" docker-compose.yml

# Verify if Docker is running
if ! pgrep -f Docker > /dev/null; then
    echo " Docker Desktop is not running."
    echo -e "\n ${BOLD}${GREEN}Starting Docker Desktop in the background...${RESET}"
    open --hide --background -a Docker
else
    echo -e "\n ${BOLD}${BLUE} Docker Desktop is already running.${RESET}"
fi

echo "Waiting for Docker to be ready..."
while ! docker info > /dev/null 2>&1; do
    sleep 1
done

echo "Docker is ready!"

echo -e "\n Starting the containers ...\n"
echo -e " This process will stop any others running containers\n"

if [[ $(docker ps -q) != "" ]]; then
    docker stop $(docker ps -q)
    sleep 5
fi
docker compose up -d

if [[ $? != 0 ]]; then
    echo -e "\n${RED} ERROR${RESET}"
    echo -e "\n  Problem starting the containers\n"
else
    echo -e "\n ${GREEN}Done.${RESET}\n"
    echo -e "\n Setting WebAdmin LiteSpeed password ...\n"
    bash bin/webadmin.sh password

    echo -e "\n Installing Wordpress\n"
    bash bin/demosite.sh 

    echo -e "\n ${GREEN}Your local development environment is ready!${RESET}\n"
    echo -e "\n ${GREEN}IMPORTANT: ${RESET}\n"
    echo -e "           1. Access your site at: ${BOLD}${BLUE}http://localhost${RESET}" 
    echo -e "           2. Access your LiteSpeed WebAdmin at: ${BOLD}${BLUE}http://localhost:7080${RESET}"
    echo -e "           ${GREEN}   *****   Note: Your LiteSpeed password is 'password'.   *****${RESET}\n"
    echo -e "           3. Access phpMyAdmin at: ${BOLD}${BLUE}http://localhost:8080${RESET}\n"
    echo -e "           4. Mount your local repository here: ${BLUE}/Users/"$USER"/repo/"$NEW_SITE"/${RESET}\n"
    echo -e "           5. Customize the volume mapping in litespeed service according to your site theme path: "
    echo -e "           ${BLUE}   Edit "$WORKING_DIR"/"$NEW_SITE"/docker-compose.yml file,"
    echo -e "              then restart the containers using your Docker Desktop dashboard.${RESET}\n"
fi

echo -e " To stop the containers, run 'docker compose stop' inside ${BOLD}${BLUE}"$WORKING_DIR"/"$NEW_SITE"${RESET} or use Docker Desktop\n"