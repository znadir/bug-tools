#!/bin/bash

RED="\e[31m"
GREEN="\033[1;32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[95m"
CYAN="\e[36m"
DEFAULT="\e[39m"
BOLD="\e[1m"
NORMAL="\e[0m"


figlet recon

echo -e "${BOLD}${YELLOW}Fast Recon Script - znadir\n${NORMAL}"

if [ $# -eq "0" ]
then
	echo -e "${RED}[!] No Domain Passed \nExample: ./recon.sh example.com${NORMAL}"
	exit 1
fi

DOMAIN=$1

if [[ ! $DOMAIN =~ ^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}[!] Invalid domain format: $DOMAIN \nExample: ./recon.sh example.com${NORMAL}"
    exit 1
fi

URL=$(curl -Ls -o /dev/null -w "%{url_effective}\n" $1)
echo "Target $DOMAIN | $URL"

mkdir -p ~/bug-bounty/$DOMAIN
cd ~/bug-bounty/$DOMAIN

echo -e "\n${GREEN}[+] Wafw00f ${NORMAL}"
echo -e "${NORMAL}${CYAN}Identifying WAF...${NORMAL}\n"
wafw00f $DOMAIN

echo -e "\n${GREEN}[+] theHarvester ${NORMAL}"
echo -e "${NORMAL}${CYAN}OSINT gathering...${NORMAL}\n"
theHarvester -d $DOMAIN

echo -e "\n${GREEN}[+] Subfinder ${NORMAL}"
echo -e "${NORMAL}${CYAN}Finding subdomains...${NORMAL}\n"
subfinder -d $DOMAIN -all -active | tee subdomains.txt

echo -e "\n${GREEN}[+] Httpx ${NORMAL}"
echo -e "${NORMAL}${CYAN}Checking subdomains...${NORMAL}\n"
cat subdomains.txt | httpx -title -sc -td -location

echo -e "\n${GREEN}[+] Subzy ${NORMAL}"
echo -e "${NORMAL}${CYAN}Scanning for subdomain takeover...${NORMAL}\n"
subzy run --targets subdomains.txt

echo -e "\n${GREEN}[+] Httpx ${NORMAL}"
echo -e "${NORMAL}${CYAN}Filtering subdomains...${NORMAL}\n"
cat subdomains.txt | httpx -fc 301,404,403 | tee subdomains.txt

echo -e "\n${GREEN}[+] Katana Url Crawling ${NORMAL}"
echo -e "${NORMAL}${CYAN}Crawling subdomains for URLs...${NORMAL}\n"
cat subdomains.txt | katana -c 10 -ct 60 | tee urls.txt

echo -e "\n${GREEN}[+] Get All Urls ${NORMAL}"
echo -e "${NORMAL}${CYAN}Getting URLs from external sources...${NORMAL}\n"
cat subdomains.txt | gau --threads 5 | tee -a urls.txt

# deduplicate urls
awk -i inplace '!seen[$0]++' urls.txt

echo -e "\n${GREEN}[+] Secret Finder ${NORMAL}"
echo -e "${NORMAL}${CYAN}Scanning javascript files for secrets...${NORMAL}\n"
cat urls.txt | grep "\.js$" | (cd ~/tools/secretfinder && while read url; do .venv/bin/python SecretFinder.py -i $url -o cli; done)

echo -e "\n${GREEN}[+] Checking Urls ${NORMAL}"
echo -e "${NORMAL}${CYAN}Overview for urls...${NORMAL}\n"
cat urls.txt | httpx -title -sc -td -location

echo -e "\n${GREEN}[+] Nuclei ${NORMAL}"
echo -e "${NORMAL}${CYAN}Quick Scan...${NORMAL}\n"
nuclei -target $DOMAIN

echo -e "\n${GREEN}[+] Nikto ${NORMAL}"
echo -e "${NORMAL}${CYAN}Scanning for more vulnerabilities...${NORMAL}\n"
nikto -h $DOMAIN

# this might quickly lead to rate limit
echo -e "\n${GREEN}[+] Feroxbuster ${NORMAL}"
echo -e "${NORMAL}${CYAN}Bruteforcing Directories...${NORMAL}\n"
cat subdomains.txt | feroxbuster --stdin -t 10 -C 403,404,429 --random-agent
