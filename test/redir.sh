#!/bin/bash

sub1 () {
  file=${1:-logfile.txt}
  :> "$file"
  exec 3>&1  # create special stdout
  exec 4>&2  # create special stderr
  exec 3>"$file" 4>&3
}

sub2 () {
  file=${1:-logfile.txt}
  :> "$file"
  exec &> >(tee -i "$file")

}

sub3 () {
  file=${1:-logfile.txt}
  :> "$file"
  exec 2> >(tee -i "$file" >&2) > >(tee -ai "$file")
}

sub4 () {
  file=${1:-logfile.txt}
  :> "$file"
  exec &> >(tee -i "$file")

}


sub3
echo "foo"
echo "bar" >&2

exit

sub1  =============================================================
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh ; (echo '--'; cat logfile.txt ; echo '--')
	foo
	bar
	--
	--
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh 1>/dev/null; (echo '--'; cat logfile.txt ; echo '--')
	bar
	--
	--
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh 2>/dev/null; (echo '--'; cat logfile.txt ; echo '--')
	foo
	--
	--
sub2  =============================================================
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh ; (echo '--'; cat logfile.txt ; echo '--')
	--
	foo
	bar
	foo
	bar
	--
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh 1>/dev/null; (echo '--'; cat logfile.txt ; echo '--')
	--
	foo
	bar
	--
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh 2>/dev/null; (echo '--'; cat logfile.txt ; echo '--')
	--
	foo
	bar
	foo
	bar
	--
sub3  =============================================================
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh ; (echo '--'; cat logfile.txt ; echo '--')
	--
	foo
	bar
	foo
	bar
	--
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh 1>/dev/null; (echo '--'; cat logfile.txt ; echo '--')
	--
	bar
	foo
	bar
	--
	bobb@s4 ~/.bin/test (master %)
	$ ./redir.sh 2>/dev/null; (echo '--'; cat logfile.txt ; echo '--')
	--
	foo
	bar
	foo
	--
