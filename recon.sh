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

run_tool() {
	local tool_name=$1
	local description=$2
	local command

	echo -e "\n${GREEN}[+] $tool_name ${NORMAL}"
	echo -e "${NORMAL}${CYAN}$description${NORMAL}\n"
	command=$(</dev/stdin)
	eval "$command"
}

setup() {
        local domain=$1

        figlet recon
        echo -e "${BOLD}${YELLOW}Fast & Optimized Recon Script - znadir\n${NORMAL}"

        if [ $# -eq "0" ]
        then
                echo -e "${RED}[!] No Domain Passed \nExample: ./recon.sh example.com${NORMAL}"
                exit 1
        fi

        if [[ ! $domain =~ ^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
                echo -e "${RED}[!] Invalid domain format: $DOMAIN \nExample: ./recon.sh example.com${NORMAL}"
                exit 1
        fi

        local url=$(curl -Ls -o /dev/null -w "%{url_effective}\n" $1)
        local url="${url%/}"

	echo "Target $domain | $url"

	mkdir -p ~/bug-bounty/$domain
	cd ~/bug-bounty/$domain

	export DOMAIN=$domain
	export URL=$url
}

setup "$1"

####################### Run tools

run_tool "Wafw00f" "Identifying WAF..." <<EOF
wafw00f $DOMAIN
EOF


run_tool "theHarvester" "OSINT gathering..." <<EOF
theHarvester -d $DOMAIN
EOF

run_tool "Robots.txt" "Gathering Robots.txt disallowed links..." <<EOF
curl -s $URL/robots.txt | grep -i "Disallow" | sort -u
EOF

run_tool "Subfinder" "Finding subdomains..." <<EOF
subfinder -d $DOMAIN -all -active | tee subdomains.txt
EOF

if [[ ! -s subdomains.txt ]]; then
	echo -e "${RED}[!] No Subdomain found. Using Domain provided for other tools. ${NORMAL}"
	echo "$DOMAIN" >> subdomains.txt
fi

run_tool "Httpx" "Checking subdomains..." <<EOF
cat subdomains.txt | httpx -title -sc -td -location
EOF

run_tool "Subzy" "Scanning for subdomain takeover..." <<EOF
subzy run --targets subdomains.txt
EOF

run_tool "Httpx" "Filtering subdomains..." <<EOF
cat subdomains.txt | httpx -random-agent -fc 500,501 -mr "</html>" -fr | awk '{print $1}' | awk -F / '{print $3}' | tee subdomains.txt
EOF

if [[ ! -s subdomains.txt ]]; then
        echo -e "${RED}[!] No Active Subdomain. ${NORMAL}"
        exit 1
fi

run_tool "Naabu" "Scanning subs top 100 ports..." <<EOF
cat subdomains.txt | naabu -top-ports 100 -exclude-ports 80,443 -exclude-cdn -nmap-cli 'nmap -A -sV'
EOF

run_tool "Katana" "Crawling subdomains for URLs..." <<EOF
cat subdomains.txt | katana -c 10 -ct 30 | tee raw-urls.txt
EOF

run_tool "Get All Urls" "Getting URLs from external sources..." <<EOF
cat subdomains.txt | gau --threads 5 | tee -a raw-urls.txt
EOF

# clean urls
uro -i raw-urls.txt -o urls.txt
rm raw-urls.txt

run_tool "Secret Finder" "Scanning javascript files for secrets..." <<EOF
cat urls.txt | grep "\.js$" | (cd ~/tools/secretfinder && while read jsurl; do .venv/bin/python SecretFinder.py -i \$jsurl -o cli; done)
EOF

run_tool "Checking Urls" "Overview for urls..." <<EOF
cat urls.txt | httpx -title -sc -td -location
EOF

run_tool "Nuclei" "Quick Scan..." <<EOF
nuclei -target $DOMAIN
EOF

run_tool "Nikto" "Scanning for more vulnerabilities..." <<EOF
nikto -h $DOMAIN
EOF

run_tool "x8" "Searching for hidden headers..." <<EOF
x8 -u $URL --headers -w /usr/share/seclists/Discovery/Web-Content/BurpSuite-ParamMiner/lowercase-headers
EOF

run_tool "Arjun" "Searching for hidden get params..." <<EOF
arjun -u $URL
EOF

run_tool "Feroxbuster" "Bruteforcing Directories..." <<EOF
cat subdomains.txt | feroxbuster --stdin -t 10 -C 403,404,429 --random-agent
EOF
