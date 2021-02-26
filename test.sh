#!/bin/bash

set -e

export ANSI_YELLOW_BOLD="\e[1;33m"
export ANSI_GREEN="\e[32m"
export ANSI_YELLOW_BACKGROUND="\e[1;7;33m"
export ANSI_GREEN_BACKGROUND="\e[1;7;32m"
export ANSI_CYAN_BACKGROUND="\e[1;7;36m"
export ANSI_CYAN="\e[36m"
export ANSI_RESET="\e[0m"
export DOCKERFILE_TOP="**************************************** DOCKERFILE ******************************************"
export DOCKERFILE_BOTTOM="**********************************************************************************************"
export TEST_SUITE_START="**************************************** SMOKE TESTS *****************************************"
export TEST_SUITE_END="************************************** TEST SUCCESSFUL ***************************************"

# Pass in path to folder where Dockerfile lives
print_dockerfile () {
        echo -e "$ANSI_CYAN$DOCKERFILE_TOP\n$(<$1/Dockerfile)\n$ANSI_CYAN$DOCKERFILE_BOTTOM $ANSI_RESET\n"
}

# Pass in test case message
print_test_case () {
        echo -e "\n$ANSI_YELLOW_BOLD$1 $ANSI_RESET"
}

print_info () {
        echo -e "\n$ANSI_CYAN$1 $ANSI_RESET \n"
}

print_success () {
        echo -e "\n$ANSI_GREEN$1 $ANSI_RESET \n"

}

wait_until_ready () {
        export SECONDS=$1
        export SLEEP_INTERVAL=$(echo $SECONDS 50 | awk '{ print $1/$2 }')

        echo -e "\n${ANSI_CYAN}Waiting ${SECONDS} seconds until ready: ${ANSI_RESET}"

        for second in {1..50}
        do
                echo -ne "${ANSI_CYAN_BACKGROUND} ${ANSI_RESET}"
                sleep ${SLEEP_INTERVAL}
        done

        echo -e "${ANSI_CYAN} READY${ANSI_RESET}"
}


# Pass in path to folder where Dockerfile lives
build () {
        print_dockerfile $1
        docker build -t $1 $1
}

cleanup () {
        docker rmi $1
}

suite_start () {
        echo -e "\n$ANSI_YELLOW_BACKGROUND$TEST_SUITE_START$ANSI_RESET \n"
}

suite_end () {
        echo -e "\n$ANSI_GREEN_BACKGROUND$TEST_SUITE_END$ANSI_RESET \n"
}


suite_start
        print_test_case "It starts successfully:"
                print_info "Starting Quay's Redis key value store..."
                docker run --name quay-redis -d quay.io/ibm/redis:6.0

                print_info "Starting Quay's PostgreSQL database..."
                docker run --name quay-postgres -e POSTGRES_PASSWORD=password -d quay.io/ibm/postgres:13
                print_info "Waiting for Quay's PostgreSQL database to be ready..."
                wait_until_ready 10
                print_info "Creating pg_trgm; extension in Quay's PostgreSQL database"
                docker exec --user postgres quay-postgres psql -d postgres -c "create extension pg_trgm;"

                print_info "Create Quay image with config file..."
                build "configured-quay"

                print_info "Start quay..."
                docker run --name configured-quay --link quay-redis --link quay-postgres -p 8443:8443 -p 8080:8080 -d "configured-quay"
                print_info "Waiting for Quay to be ready..."
                wait_until_ready 60

                print_info "Checking that Quay is up and healthy..."
                docker exec configured-quay curl --fail -X GET -I http://localhost:8080

                print_success "Success! Quay is up and running."

                docker rm -f quay-postgres
                docker rm -f quay-redis
                docker rm -f configured-quay
                cleanup "configured-quay"
suite_end
