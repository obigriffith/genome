#!/usr/bin/env bats

load test_helper
export BATS_TEST_DIRNAME

function setup {
    init_workspace
    export GE_NO_REDIRECT=1
    cd $WORKSPACE/genome
}

function teardown {
    rm_workspace
}

@test "basic test: genome-env-next" {
    $BATS_TEST_DIRNAME/../bin/genome-env-next "$BATS_TEST_DIRNAME/testexec/default.sh"
}

@test "basic test: genome-env-next -D" {
    $BATS_TEST_DIRNAME/../bin/genome-env-next -D "$BATS_TEST_DIRNAME/testexec/D.sh"
}

@test "basic test: genome-env-next -U" {
    export PERL5LIB="$WORKSPACE/ur/lib:$PERL5LIB"
    $BATS_TEST_DIRNAME/../bin/genome-env-next -D -U "$BATS_TEST_DIRNAME/testexec/U.sh"
}

@test "basic test: genome-env-next -u" {
    $BATS_TEST_DIRNAME/../bin/genome-env-next -D -u $WORKSPACE/ur "$BATS_TEST_DIRNAME/testexec/U.sh"
}

@test "basic test: genome-env-next -W" {
    export PERL5LIB="$WORKSPACE/workflow/lib:$PERL5LIB"
    $BATS_TEST_DIRNAME/../bin/genome-env-next -D -W "$BATS_TEST_DIRNAME/testexec/W.sh"
}

@test "basic test: genome-env-next -w" {
    $BATS_TEST_DIRNAME/../bin/genome-env-next -D -w $WORKSPACE/workflow "$BATS_TEST_DIRNAME/testexec/W.sh"
}

@test "basic test: genome-env-next -M" {
    $BATS_TEST_DIRNAME/../bin/genome-env-next -D -M "$BATS_TEST_DIRNAME/testexec/M.sh"
}

@test "basic test: genome-env-next -m" {
    $BATS_TEST_DIRNAME/../bin/genome-env-next -m $WORKSPACE/genome-sqitch "$BATS_TEST_DIRNAME/testexec/migration.sh"
}