#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
EXECUTION_ONLY=0
num_failed=0
num_passed=0


execution_test() {
	test_file=$1
	perl $test_file > pl_out.txt
	python3.5 -u tmp.py > py_out.txt
	diff_=$(diff py_out.txt pl_out.txt)
	if [ "$diff_" != "" ]; then
		echo -e "${RED} \xE2\x9C\x98 $test_file${NC}"
			echo -e " There are differences between your and the sample output, and your code did not pass fallback execution tests."
			echo " ==> The CODE diff (<yours, >theirs):"
			diff tmp.py ${test_file[@]%.pl}.py # | colordiff
			echo " ==> The EXECUTION output (<yours, >theirs):"
			diff py_out.txt pl_out.txt # | colordiff
			tests_failed[$num_failed]=$test_file
			num_failed=$((num_failed + 1))
	else
		if [ $EXECUTION_ONLY -ne 1 ]; then
			## CAVEAT: this is super basic and does not work for programs needing input or args.
			echo "Your code did not match any sample code but the execution output was the same,"
			echo "assuming this program does not require input."
			echo " ==> The CODE diff (<yours, >theirs):"
			diff tmp.py ${test_file[@]%.pl}.py # | colordiff
		fi
			echo -e "${GREEN} \xE2\x9C\x94 $test_file${NC}"
	fi

	rm p*_out.txt
}

test_against() {
	cd $1

	echo -e "Running: ${PURPLE}Set $1${NC}"
	echo -e "${CYAN}===================${NC}"
	for test_file in `ls -f *.pl`; do
		#perl ../../plpy.pl $test_file > tmp.py
		perl plpy.pl $test_file > tmp.py
		diff_=$(diff tmp.py ${test_file[@]%.pl}.py)
		if [ "$diff_" != "" ]; then # || [ ! -f ${test_file[@]%.pl} ]
			execution_test $test_file
		else
			echo -e "${GREEN} \xE2\x9C\x94 $test_file${NC}"
			num_passed=$((num_passed + 1))
		fi
		rm tmp.py
	done

	if [ $num_failed -ne 0 ]; then
		NUM_TESTS=$((num_failed + num_passed))
		echo -e "\n${RED}$num_failed out of $NUM_TESTS${NC} tests failed."
		echo -e "Failed tests: ${tests_failed[*]}\n"
	else
		echo -e "\n${GREEN}OK. $num_passed${NC} passed.\n"
	fi

	cd ..
}


# TODO: allow all arg
for f in "$@"; do
	case "$f" in
		-h|--help)
			echo "Usage: $0 [-e] dir1 [dir2 ...]"
			echo -e "  -e | --execution\n  Don't run code diffs, only diff execution output"
			;;
		-e|--execute)
			EXECUTION_ONLY=1
			echo -e "${PURPLE}ONLY testing execution output${NC}"
			;;
		*)
			test_against $f
			;;
	esac
done
