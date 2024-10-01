
dev: 
    npm run dev

populate-env: 
    coffee  src/scripts/populate_env.coffee -n

run file: 
    coffee {{file}} -n

build: 
    npm run build
