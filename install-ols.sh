#!/bin/zsh

# Color codes for terminal output
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[34m'
BOLD='\e[1m'
RESET='\e[0m'

# Variables
WORKING_DIR=~/my-devenv
NEW_SITE=$1
GIT_REPO_URL=git@github.com:litespeedtech/ols-docker-env.git
INPUT_FILE=docker-compose.yml
OUTPUT_FILE=docker-compose-"$NEW_SITE".yml
IN_LITESPEED="false"    # Flag to track if we are in litespeed service section of docker-compose.yml

clear
echo -e "\n\n${BOLD}${BLUE}Local Development Environment Setup Script${RESET}\n"

#Validate user input to get the new site name
if [[ -z "$1" ]]; then
    echo -e "\n${RED}Error${RESET}"
    echo -e "Missing web site name"
    echo -e "\n Usage: "$0" new-site-name \n"
    exit 1
fi 

# Create working directory if it doesn't exist
mkdir -p "$WORKING_DIR"/
cd "$WORKING_DIR"/

# Clone the project from GitHub repository
echo -e "\n ${GREEN}Cloning the project from GitHub ...${RESET}\n"
git clone "$GIT_REPO_URL" "$NEW_SITE"

# Check if the git clone command was successful
if [[ $? != 0 ]]; then
    echo -e "\n${RED}ERROR${RESET}"
    echo -e "\n Problem cloning the project\n"
else
    echo "Cloning the project ..."
    cd "$WORKING_DIR"/"$NEW_SITE"
    echo -e "\nProject cloned in ""$WORKING_DIR"/"$NEW_SITE"" \n" 
fi
# Navigate to the new site directory, where docker-compose.yml is located
cd "$WORKING_DIR"/"$NEW_SITE"

# Add containner name to each service and add user volume in litespeed service of docker-compose.yml
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
echo -e " ${GREEN}Done.${RESET}\n"

# Create local repository directory for the new site
echo -e "\n ${GREEN}Creating local repository directory ...${RESET}\n"
mkdir -p /Users/"$USER"/repo/"$NEW_SITE"/

# Backup the original docker-compose.yml and replace it with the customized one
echo -e "\n ${GREEN}Backing up the original docker-compose.yml and replacing it with the customized one ...${RESET}\n"
mv "$INPUT_FILE" docker-compose-bk.yml 
mv "$OUTPUT_FILE" docker-compose.yml

# Verify if Docker is running
if ! pgrep -f Docker > /dev/null; then
    echo "Docker Desktop is not running."
    echo -e "${BOLD}${GREEN}Starting Docker Desktop in the background...${RESET}"
    open --hide --background -a Docker
else
    echo -e "${BOLD}Docker Desktop is already running.${RESET}"
fi

# Wait until Docker is fully started
echo "Checking if Docker Engine is running fine..."
while ! docker info > /dev/null 2>&1; do
    sleep 1
done

# Stop any other running containers to avoid port conflicts
echo -e "Starting the containers ...\n"
echo -e "This process will stop any others running containers\n"
if [[ $(docker ps -q) != "" ]]; then
    docker stop $(docker ps -q)
    sleep 5
fi

# Start the containers in detached mode
docker compose up -d

if [[ $? != 0 ]]; then
    echo -e "\n${RED} ERROR${RESET}"
    echo -e "\n Problem starting the containers\n"
else
    echo -e "\n${GREEN}Done.${RESET}\n"
    # Set WebAdmin password to 'password' you can change it later running 'bin/webadmin.sh password'
    echo -e "\nSetting WebAdmin LiteSpeed password ...\n"   
    bash bin/webadmin.sh password

    echo -e "\nInstalling Wordpress\n"
    # Install Wordpress demo site
    bash bin/demosite.sh 

    # Final message for the user
    echo -e "\n ${BOLD}${GREEN}Your local development environment is ready!${RESET}\n"
    echo -e "\n ${GREEN}IMPORTANT: ${RESET}\n"
    echo -e "           1. Access your site at: ${BOLD}${BLUE}http://localhost${RESET}\n" 
    echo -e "           2. Access your LiteSpeed WebAdmin at: ${BOLD}${BLUE}http://localhost:7080${RESET}"
    echo -e "           ${GREEN}   *****   Note: Your LiteSpeed password is 'password'.   *****${RESET}\n"
    echo -e "           3. Access phpMyAdmin at: ${BOLD}${BLUE}http://localhost:8080${RESET}\n"
    echo -e "           4. Mount your local repository here: ${BLUE}/Users/"$USER"/repo/"$NEW_SITE"/${RESET}\n"
    echo -e "           5. Customize the volume mapping in litespeed service according to your site theme path: "
    echo -e "           ${BLUE}   Edit "$WORKING_DIR"/"$NEW_SITE"/docker-compose.yml file,"
    echo -e "              then restart the containers using your Docker Desktop dashboard.${RESET}\n"
fi

echo -e " To stop the containers, run 'docker compose stop' inside ${BOLD}${BLUE}"$WORKING_DIR"/"$NEW_SITE"${RESET} or use Docker Desktop\n"