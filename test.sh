#!/usr/bin/env bash
function assert_pii_found {
    local result=$1
    if [ ! $result -eq 1 ]; then
        echo -e "\e[31mFail\e[m\n"
        exit 1
    else
        echo -e "\e[32mPass\e[m\n"
    fi
}

function assert_pii_not_found {
    local result=$1
    if [ ! $result -eq 0 ]; then
        echo -e "\e[31mFail\e[m"
        exit 1
    else
        echo -e "\e[32mPass\e[m"
    fi
}

function test_case {
    desc=$1
    echo -e "\e[33mTesting: $desc\e[m"
}

### Basic functionality testing
test_case "the simplest case that should be detected"
./piifind.sh <<EOF
(log address)
(def foo)
EOF
assert_pii_found $?

test_case "no pii is logged"
./piifind.sh <<EOF
(log "debug %s"
      something-important)
(defn pii-func []
  (log "foobar"))
EOF
assert_pii_not_found $?

test_case "search from multiple lines"
./piifind.sh <<EOF
(log "debug %s"
      address)
EOF
assert_pii_found $?

test_case "mix of pii and non-pii"
./piifind.sh <<EOF
(def pii-func [pii]
   (log "debug %s"
         address)
   (do-with-my-pii))
EOF
assert_pii_found $?

test_case "search commong logging functions: infof"
./piifind.sh <<EOF
(infof address)
EOF
assert_pii_found $?

test_case "search commong logging functions: log/errorf"
./piifind.sh <<EOF
(log/errorf address)
EOF
assert_pii_found $?

test_case "complex pattern"
./piifind.sh <<EOF
(log/infof "some unrelated debug")
(defn my-func [foo]
  (-> foo
      (:email))
EOF
assert_pii_not_found $?

test_case "case insensitive matches"
./piifind.sh <<EOF
(infof Address)
EOF
assert_pii_found $?

#### Testing extra pattern
test_case "specify optional pattern from option"
./piifind.sh -p foobar <<EOF
(infof foobar)
EOF
assert_pii_found $?

### Testing from STDIN
test_dir="test_data"
mkdir -p $test_dir

test_case "from file"
test_file="pii_found.clj"
cat <<EOF > $test_dir/$test_file
(log address)
EOF
./piifind.sh $test_dir/$test_file
assert_pii_found $?

test_case "from file: pii not found"
test_file="pii_not_found.clj"
cat <<EOF > $test_dir/$test_file
(def log []
   (do-something address))
EOF
./piifind.sh $test_dir/$test_file
assert_pii_not_found $?

test_case "from file: only search in Clojure/Script files"
test_file="only_clj_s.txt"
cat <<EOF > $test_dir/$test_file
(log address)
EOF
./piifind.sh $test_dir/$test_file
assert_pii_not_found $?

test_case "from file: searching recursively"
mkdir -p $test_dir/sub
test_file="search_recursive.clj"
cat <<EOF > $test_dir/sub/$test_file
(log address)
EOF
./piifind.sh $test_dir/sub/$test_file
assert_pii_found $?

test_case "from file: file not found"
./piifind.sh noexist
assert_pii_found $?





echo -e "\e[32mAll tests passed!\e[m"
