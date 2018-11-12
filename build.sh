#!/bin/sh

[ $# -ne 2 ] && {
    echo "Usage: $0 TARGET_REFERENCES OUT_DIR_PATH"
    exit 1
}

TARGET_REFS=$1
OUT_DIR_PATH=$2

BASE_CWD=$PWD
HERE=$(realpath $(dirname $0))

GRAPHQL_SRC_PATH=saleor/graphql/schema.graphql
GRAPHQL_OUT_PATH="$(mktemp).graphql"

export PATH=${PATH}:${HERE}/node_modules/.bin/

if [ ! -d saleor ]; then
    echo 'Cloning Saleor...'
    git clone https://github.com/mirumee/saleor.git saleor \
        || { echo 'Failed to clone saleor' &2>1; exit 1; }
fi

cd saleor \
    || { echo 'Failed to change dir to saleor' &2>1; exit 1; }

echo 'Fetching remote...'
git fetch origin;

echo 'Generating docs...'
for refname in $TARGET_REFS; do
    echo -e "\t- ${refname}..."
    (git show origin/${refname}:${GRAPHQL_SRC_PATH} > $GRAPHQL_OUT_PATH \
        || { echo "Failed to generate $refname" &2>1; exit 1; }
     cd $BASE_CWD \
        && graphdoc \
                -s $GRAPHQL_OUT_PATH \
                -o "${OUT_DIR_PATH}/${refname}" \
                --force > /dev/null)
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
          $(cd saleor; for refname in $TARGET_REFS; do
            rev=$(git rev-parse --short origin/${refname})
            echo "<li class='list-group-item list-group-item-action \
                             flex-column align-items-start'> \
                    <a class='d-block text-dark' href='${refname}/index.html'> \
                      <h4 class='mb-1'>${refname} branch</h4> \
                      <blockquote class='mb-1 ml-4 pl-2' style='border-left: 4px solid #CCC'> \
                        $(git log --format=%B -n 1 origin/${refname} | sed 's/$/<br>/') \
                      </blockquote> \
                    </a> \
                    <small><a \
                      href='https://github.com/mirumee/saleor/commit/$rev'>
                      $rev \
                    </a></small> \
                  </li>";
            done)
       </ul>
    </body>
</html>

EOF

