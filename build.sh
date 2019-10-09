#!/bin/sh

[ $# -ne 2 ] && {
    echo "Usage: $0 TARGET_REFERENCES OUT_DIR_PATH"
    exit 1
}

UNCLEAN_TARGET_REFS=$1
OUT_DIR_PATH=$2

cleaned_target_refs=

for refname in $UNCLEAN_TARGET_REFS; do
    echo "${refname}" | grep -F . \
        && refname="tags/${refname}" \
        || refname="origin/${refname}"
    cleaned_target_refs="${cleaned_target_refs} ${refname}"
done

BASE_CWD=$PWD
HERE=$(realpath $(dirname $0))

GRAPHQL_SRC_PATH=saleor/graphql/schema.graphql
GRAPHQL_OUT_PATH="$(mktemp).graphql"

export PATH=${PATH}:${HERE}/node_modules/.bin/

failed() {
    echo "Failed to $@" &2>1
    exit 1
}

if [ ! -d saleor ]; then
    echo 'Cloning Saleor...'
    git clone https://github.com/mirumee/saleor.git saleor \
        || failed clone saleor
fi

cd saleor \
    || failed change dir to saleor

echo 'Fetching remote...'
git fetch origin;
cd ..

echo 'Generating docs...'
for refname in ${cleaned_target_refs}; do
    echo -e "\t- ${refname}..."

    cd saleor \
        || failed change dir to saleor

    git checkout ${refname} -b $(cat /proc/sys/kernel/random/uuid) > /dev/null \
        || failed checkout to "${refname}"

    pip install -r requirements.txt > /dev/null \
        || failed install saleor

    pip uninstall -y graphql-core \
        || failed uninstall GraphQL
    cd ${GQL_PKG_PATH} \
        && python3 ./setup.py develop > /dev/null \
        && cd $BASE_CWD \
        || failed install GraphQL fork

    cd saleor || failed cd back to saleor

    SECRET_KEY=blah python manage.py get_graphql_schema > ${GRAPHQL_OUT_PATH} \
        || failed generate GraphQL schema

    out_dir="${OUT_DIR_PATH}/${refname}"

    cd $BASE_CWD \
        && graphdoc \
            -t ./template/slds \
            -s ${GRAPHQL_OUT_PATH} \
            -o "${out_dir}" \
            --force > /dev/null

    cp ${GRAPHQL_OUT_PATH} "${out_dir}/schema.txt"
    [ $? -ne 0 ] && exit 1
done

echo 'Generating index.html...'
cd $BASE_CWD
cat > ${OUT_DIR_PATH}/index.html <<EOF
<!doctype html>
  <html>
    <head>
      <title>Saleor GraphQL documentations</title>
      <link rel="stylesheet"
            href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"
            integrity="sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO"
            crossorigin="anonymous">
    </head>
    <body class='container'>
       <h2 class='mt-4 mb-4'>Saleor GraphQL documentations</h2>
       <ul class='list-group'>
          $(cd saleor; for refname in ${cleaned_target_refs}; do
            rev=$(git rev-parse --short ${refname})
            date=$(git log -1 --format="%at" ${refname} | xargs -I{} date -d @{} +%Y/%m/%d\ %H:%M:%S\ %Z)
            echo "<li class='list-group-item list-group-item-action \
                             flex-column align-items-start'> \
                    <a class='d-block text-dark' href='${refname}/index.html'> \
                      <h4 class='mb-1'>$(echo ${refname} | sed 's/^[a-z]*\///g') version</h4> \
                      <blockquote class='mb-1 ml-4 pl-2' style='border-left: 4px solid #CCC'> \
                        $(git log --format=%B -n 1 ${refname} | sed 's/$/<br>/') \
                      </blockquote> \
                    </a> \
                    <small>$date on<a \
                      href='https://github.com/mirumee/saleor/commit/$rev'>
                      $rev
                    </a></small> \
                  </li>";
            done)
       </ul>
    </body>
</html>

EOF

