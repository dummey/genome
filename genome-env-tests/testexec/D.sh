#!/bin/bash

type -p genome-env-next

if test -z "$WORKSPACE"
then
    echo "WORKSPACE is not set" >&2
    exit 1
fi

for M in sqitch/genome ur workflow ; do
    submodule_is_clean $M
done

submodule_is_not_initialized sqitch/genome

if test "$WORKSPACE/genome/ur/lib/UR.pm" != "$(perl -MUR -e 'print $INC{q(UR.pm)}, qq(\n)')"
then
    echo "$WORKSPACE/genome/ur/lib/UR.pm" >&2
    perl -MUR -e 'print $INC{q(UR.pm)}, qq(\n)' >&2
    echo "UR should be loaded from submodule" >&2
    exit 1
fi

if test "$WORKSPACE/genome/workflow/lib/Workflow.pm" != "$(perl -MWorkflow -e 'print $INC{q(Workflow.pm)}, qq(\n)')"
then
    echo "Workflow should be loaded from submodule" >&2
    exit 1
fi

apipe_test_db_is_not_used
